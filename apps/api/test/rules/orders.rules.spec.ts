/**
 * Проверки правил заказа пассажира (O1–O9). Меняются только отдельным коммитом.
 */
import type { INestApplication } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { trips } from '../../src/modules/trips/internal/schema';
import { blocks, cancellations } from '../../src/modules/users/internal/schema';
import { call, createTestApp } from '../helpers/app';
import {
  addCancellation,
  closeDb,
  createBooking,
  createCar,
  createCity,
  createOrder,
  createTrip,
  createUser,
  db,
} from '../helpers/db';
import { DAY, atLocal, isoLocal } from '../helpers/dates';

let app: INestApplication;

beforeAll(async () => {
  app = await createTestApp();
});

afterAll(async () => {
  await app.close();
  await closeDb();
});

/** Пара городов на проверку: заказы и поездки одного правила не попадают в выдачу другого. */
let pairSeq = 0;
async function cityPair(): Promise<[number, number]> {
  pairSeq += 1;
  const from = await createCity(`Заказ-откуда-${pairSeq}`, 57.6261 + pairSeq * 0.01, 39.8845);
  const to = await createCity(`Заказ-куда-${pairSeq}`, 58.0485 + pairSeq * 0.01, 38.8584);
  return [from, to];
}

/** Тело заказа: завтра 10:00–12:00, поездка на 1 место с детским креслом; поля — переопределить. */
function orderBody(from: number, to: number, overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    kind: 'ride',
    stops: [
      { cityId: from, address: 'Улица Солнечная, дом 1' },
      { cityId: to, address: 'Улица Лунная, дом 2' },
    ],
    departsAt: isoLocal(atLocal(1, 10)),
    arrivesAt: isoLocal(atLocal(1, 12)),
    seats: 1,
    parcelSize: 'none',
    extras: ['child_seat'],
    ...overrides,
  };
}

/** Тело поездки водителя на авто `carId`: завтра 09:00–11:00, два города, цена 900. */
function tripBody(carId: string, from: number, to: number, overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    kind: 'ride',
    vehicleKind: 'car',
    stops: [
      { cityId: from, address: 'Остановка 0' },
      { cityId: to, address: 'Остановка 1' },
    ],
    departsAt: isoLocal(atLocal(1, 9)),
    arrivesAt: isoLocal(atLocal(1, 11)),
    seatsTotal: 3,
    priceFull: 900,
    prices: [],
    priceBoardingMin: 100,
    carId,
    extras: [],
    parcelOnlyAllowed: false,
    parcelSeatsTotal: 0,
    bookingMode: 'standard',
    ...overrides,
  };
}

const CHILD_SEAT_150 = [{ kind: 'child_seat' as const, price: 150 }];

describe('Заказы пассажира', () => {
  it('O1: пассажир публикует заказ — открыт, с номером; время не кратно 30 — invalid_time_step; дальше 3 дней — too_far_ahead; посылка без размера, поездка без мест или на 9 мест — validation', async () => {
    const [from, to] = await cityPair();
    const passenger = await createUser();
    const http = call(app, passenger.token);

    const res = await http.post('/orders').send(orderBody(from, to));
    expect(res.status).toBe(201);
    expect(res.body.status).toBe('open');
    expect(Number.isInteger(res.body.number)).toBe(true);
    expect(res.body.isMine).toBe(true);
    expect(res.body.stops).toHaveLength(2);
    expect(res.body.from.cityId).toBe(from);
    expect(res.body.to.cityId).toBe(to);
    expect(res.body.seats).toBe(1);
    expect(res.body.extras).toEqual(['child_seat']);
    expect(res.body.passenger.id).toBe(passenger.id);

    const oddTime = await http.post('/orders').send(orderBody(from, to, { departsAt: isoLocal(atLocal(1, 10, 15)) }));
    expect(oddTime.status).toBe(400);
    expect(oddTime.body.code).toBe('invalid_time_step');

    const far = await http.post('/orders').send(orderBody(from, to, { departsAt: isoLocal(atLocal(4, 10)), arrivesAt: isoLocal(atLocal(4, 12)) }));
    expect(far.status).toBe(400);
    expect(far.body.code).toBe('too_far_ahead');

    const parcelNoSize = await http.post('/orders').send(orderBody(from, to, { kind: 'parcel', seats: 0, parcelSize: 'none', extras: [] }));
    expect(parcelNoSize.status).toBe(400);
    expect(parcelNoSize.body.code).toBe('validation');

    const noSeats = await http.post('/orders').send(orderBody(from, to, { seats: 0 }));
    expect(noSeats.status).toBe(400);
    expect(noSeats.body.code).toBe('validation');

    const nineSeats = await http.post('/orders').send(orderBody(from, to, { seats: 9 }));
    expect(nineSeats.status).toBe(400);
    expect(nineSeats.body.code).toBe('validation');
  });

  it('O2: лента водителя — чужие открытые заказы, раньше выезд — выше; свой, отменённый и с выездом в прошлом не видны; фильтр «откуда/куда»', async () => {
    const [from, to] = await cityPair();
    const [otherFrom, otherTo] = await cityPair();
    const driver = await createUser({ mode: 'driver' });
    const passenger = await createUser();

    const late = await createOrder({ passengerId: passenger.id, cityIds: [from, to], departsAt: atLocal(1, 11) });
    const early = await createOrder({ passengerId: passenger.id, cityIds: [from, to], departsAt: atLocal(1, 9) });
    await createOrder({ passengerId: driver.id, cityIds: [from, to], departsAt: atLocal(1, 10) });
    await createOrder({ passengerId: passenger.id, cityIds: [from, to], departsAt: atLocal(1, 10), status: 'cancelled' });
    await createOrder({ passengerId: passenger.id, cityIds: [from, to], departsAt: new Date(Date.now() - DAY) });
    const elsewhere = await createOrder({ passengerId: passenger.id, cityIds: [otherFrom, otherTo], departsAt: atLocal(1, 10) });

    const res = await call(app, driver.token).get(`/orders?fromCityId=${from}&toCityId=${to}`);
    expect(res.status).toBe(200);
    expect(res.body.map((o: { id: string }) => o.id)).toEqual([early.id, late.id]);
    expect(res.body[0].status).toBe('open');
    expect(res.body[0].passenger.id).toBe(passenger.id);

    const other = await call(app, driver.token).get(`/orders?fromCityId=${otherFrom}&toCityId=${otherTo}`);
    expect(other.body.map((o: { id: string }) => o.id)).toEqual([elsewhere.id]);
  });

  it('O3: «Мои заказы» — свои со статусом; отмена открытого — «отменён», счёт отмен не растёт; взятый — invalid_transition; чужой — 404', async () => {
    const [from, to] = await cityPair();
    const passenger = await createUser();
    const stranger = await createUser();
    const open = await createOrder({ passengerId: passenger.id, cityIds: [from, to], departsAt: atLocal(1, 10) });
    const matched = await createOrder({ passengerId: passenger.id, cityIds: [from, to], departsAt: atLocal(1, 12), status: 'matched' });
    const foreign = await createOrder({ passengerId: stranger.id, cityIds: [from, to], departsAt: atLocal(1, 10) });
    const http = call(app, passenger.token);

    const mine = await http.get('/orders/mine');
    expect(mine.status).toBe(200);
    const statusOf = new Map(mine.body.map((o: { id: string; status: string }) => [o.id, o.status]));
    expect(statusOf.get(open.id)).toBe('open');
    expect(statusOf.get(matched.id)).toBe('matched');
    expect(statusOf.has(foreign.id)).toBe(false);

    const cancelled = await http.post(`/orders/${open.id}/cancel`);
    expect(cancelled.status).toBe(200);
    expect(cancelled.body.status).toBe('cancelled');
    expect(await db.$count(cancellations, eq(cancellations.userId, passenger.id))).toBe(0);

    const taken = await http.post(`/orders/${matched.id}/cancel`);
    expect(taken.status).toBe(409);
    expect(taken.body.code).toBe('invalid_transition');

    const alien = await http.post(`/orders/${foreign.id}/cancel`);
    expect(alien.status).toBe(404);
  });

  it('O4: водителю в заказе — своя поездка в тот же день через точки заказа с суммой брони; поездка в другой день — нет; взятый чужой заказ — 404', async () => {
    const [from, to] = await cityPair();
    const driver = await createUser({ mode: 'driver' });
    const passenger = await createUser();
    const sameDay = await createTrip({ driverId: driver.id, cityIds: [from, to], departsAt: atLocal(1, 8), priceFull: 1000, extras: CHILD_SEAT_150 });
    await createTrip({ driverId: driver.id, cityIds: [from, to], departsAt: atLocal(2, 8), priceFull: 1000, extras: CHILD_SEAT_150 });
    const order = await createOrder({ passengerId: passenger.id, cityIds: [from, to], departsAt: atLocal(1, 10), seats: 2, extras: ['child_seat'] });

    const res = await call(app, driver.token).get(`/orders/${order.id}`);
    expect(res.status).toBe(200);
    expect(res.body.isMine).toBe(false);
    expect(res.body.matchingTrips).toHaveLength(1);
    expect(res.body.matchingTrips[0].trip.id).toBe(sameDay);
    expect(res.body.matchingTrips[0].fromIdx).toBe(0);
    expect(res.body.matchingTrips[0].toIdx).toBe(1);
    // 1000 ₽ за отрезок × 2 места + детское кресло 150 ₽.
    expect(res.body.matchingTrips[0].priceTotal).toBe(2150);

    const own = await call(app, passenger.token).get(`/orders/${order.id}`);
    expect(own.status).toBe(200);
    expect(own.body.isMine).toBe(true);
    expect(own.body.matchingTrips).toEqual([]);

    const takenByOther = await createOrder({ passengerId: passenger.id, cityIds: [from, to], departsAt: atLocal(1, 10), status: 'matched' });
    const hidden = await call(app, driver.token).get(`/orders/${takenByOther.id}`);
    expect(hidden.status).toBe(404);
  });

  it('O5: отклик своей поездкой — бронь «Ожидает оплаты» с номером заказа, заказ «найден водитель», пассажиру «Водитель принял заявку», водителю новой заявки нет; второй водитель — order_unavailable; поездка в другой день — order_mismatch', async () => {
    const [from, to] = await cityPair();
    const driver = await createUser({ mode: 'driver' });
    const passenger = await createUser();
    const tripId = await createTrip({ driverId: driver.id, cityIds: [from, to], departsAt: atLocal(1, 8), priceFull: 1000, extras: CHILD_SEAT_150 });
    const order = await createOrder({ passengerId: passenger.id, cityIds: [from, to], departsAt: atLocal(1, 10), extras: ['child_seat'] });

    const res = await call(app, driver.token).post(`/orders/${order.id}/respond`).send({ tripId });
    expect(res.status).toBe(201);
    expect(res.body.status).toBe('awaiting_payment');
    expect(res.body.trip.id).toBe(tripId);
    expect(res.body.passenger.id).toBe(passenger.id);
    expect(res.body.orderId).toBe(order.id);
    expect(res.body.orderNumber).toBe(order.number);
    expect(res.body.priceTotal).toBe(1150);

    const seen = await call(app, passenger.token).get(`/orders/${order.id}`);
    expect(seen.body.status).toBe('matched');
    expect(seen.body.bookingId).toBe(res.body.id);

    const passengerUpdates = await call(app, passenger.token).get('/updates');
    expect(passengerUpdates.body).toEqual(
      expect.arrayContaining([expect.objectContaining({ bookingId: res.body.id, kind: 'driver_accepted' })]),
    );
    const driverUpdates = await call(app, driver.token).get('/updates');
    expect(driverUpdates.body.filter((u: { bookingId: string }) => u.bookingId === res.body.id)).toEqual([]);

    const rival = await createUser({ mode: 'driver' });
    const rivalTrip = await createTrip({ driverId: rival.id, cityIds: [from, to], departsAt: atLocal(1, 8), extras: CHILD_SEAT_150 });
    const late = await call(app, rival.token).post(`/orders/${order.id}/respond`).send({ tripId: rivalTrip });
    expect(late.status).toBe(409);
    expect(late.body.code).toBe('order_unavailable');

    const fresh = await createOrder({ passengerId: passenger.id, cityIds: [from, to], departsAt: atLocal(1, 10) });
    const otherDay = await createTrip({ driverId: driver.id, cityIds: [from, to], departsAt: atLocal(2, 8) });
    const mismatch = await call(app, driver.token).post(`/orders/${fresh.id}/respond`).send({ tripId: otherDay });
    expect(mismatch.status).toBe(409);
    expect(mismatch.body.code).toBe('order_mismatch');
  });

  it('O6: отклик новой поездкой — поездка и бронь «Ожидает оплаты» создаются вместе; заказ уже взят — order_unavailable, поездок не прибавилось', async () => {
    const [from, to] = await cityPair();
    const driver = await createUser({ mode: 'driver' });
    const passenger = await createUser();
    const order = await createOrder({ passengerId: passenger.id, cityIds: [from, to], departsAt: atLocal(1, 10) });
    const carId = await createCar(driver.id);

    const res = await call(app, driver.token).post('/trips').send(tripBody(carId, from, to, { orderId: order.id }));
    expect(res.status).toBe(201);
    const bookingsOfTrip = await call(app, driver.token).get(`/trips/${res.body.id}/bookings`);
    expect(bookingsOfTrip.body).toHaveLength(1);
    expect(bookingsOfTrip.body[0].status).toBe('awaiting_payment');
    expect(bookingsOfTrip.body[0].passenger.id).toBe(passenger.id);
    expect(bookingsOfTrip.body[0].orderId).toBe(order.id);

    const rival = await createUser({ mode: 'driver' });
    const rivalCar = await createCar(rival.id);
    const late = await call(app, rival.token).post('/trips').send(tripBody(rivalCar, from, to, { orderId: order.id }));
    expect(late.status).toBe(409);
    expect(late.body.code).toBe('order_unavailable');
    expect(await db.$count(trips, eq(trips.driverId, rival.id))).toBe(0);
  });

  it('O7: отказ от отклика до оплаты — не в счёт (counts = false, willBlock = false), счёт и блокировки не меняются, заказ снова открыт и в ленте', async () => {
    const [from, to] = await cityPair();
    const driver = await createUser({ mode: 'driver' });
    const passenger = await createUser();
    // Одна отмена уже есть: засчитанная отмена была бы второй и заблокировала бы.
    await addCancellation(passenger.id, 'passenger');
    const tripId = await createTrip({ driverId: driver.id, cityIds: [from, to], departsAt: atLocal(1, 8) });
    const order = await createOrder({ passengerId: passenger.id, cityIds: [from, to], departsAt: atLocal(1, 10), status: 'matched' });
    const booking = await createBooking({ tripId, passengerId: passenger.id, status: 'awaiting_payment', toIdx: 1, orderId: order.id });
    const http = call(app, passenger.token);

    const preview = await http.get(`/bookings/${booking}/cancel-preview`);
    expect(preview.status).toBe(200);
    expect(preview.body.counts).toBe(false);
    expect(preview.body.willBlock).toBe(false);
    expect(preview.body.cancellationsLast30).toBe(1);

    const res = await http.post(`/bookings/${booking}/cancel`);
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('cancelled');
    expect(res.body.cancellationsLast30).toBe(1);
    expect(res.body.blockedUntil ?? null).toBeNull();
    expect(await db.$count(blocks, eq(blocks.userId, passenger.id))).toBe(0);

    const reopened = await http.get(`/orders/${order.id}`);
    expect(reopened.body.status).toBe('open');
    const otherDriver = await createUser({ mode: 'driver' });
    const feed = await call(app, otherDriver.token).get(`/orders?fromCityId=${from}&toCityId=${to}`);
    expect(feed.body.map((o: { id: string }) => o.id)).toContain(order.id);
  });

  it('O8: водитель отменил поездку с бронью из заказа — заказ снова открыт', async () => {
    const [from, to] = await cityPair();
    const driver = await createUser({ mode: 'driver' });
    const passenger = await createUser();
    const tripId = await createTrip({ driverId: driver.id, cityIds: [from, to], departsAt: atLocal(1, 8) });
    const order = await createOrder({ passengerId: passenger.id, cityIds: [from, to], departsAt: atLocal(1, 10), status: 'matched' });
    await createBooking({ tripId, passengerId: passenger.id, status: 'awaiting_payment', toIdx: 1, orderId: order.id });

    const res = await call(app, driver.token).post(`/trips/${tripId}/cancel`);
    expect(res.status).toBe(200);
    const reopened = await call(app, passenger.token).get(`/orders/${order.id}`);
    expect(reopened.body.status).toBe('open');
  });

  it('O9: заблокированный пассажир не публикует заказ, заблокированный водитель не откликается — 403 blocked', async () => {
    const [from, to] = await cityPair();
    const until = new Date(Date.now() + 10 * DAY);
    const blockedPassenger = await createUser({ blockedUntil: until });
    const publish = await call(app, blockedPassenger.token).post('/orders').send(orderBody(from, to));
    expect(publish.status).toBe(403);
    expect(publish.body.code).toBe('blocked');

    const passenger = await createUser();
    const order = await createOrder({ passengerId: passenger.id, cityIds: [from, to], departsAt: atLocal(1, 10) });
    const blockedDriver = await createUser({ mode: 'driver', blockedUntil: until });
    const tripId = await createTrip({ driverId: blockedDriver.id, cityIds: [from, to], departsAt: atLocal(1, 8) });
    const respond = await call(app, blockedDriver.token).post(`/orders/${order.id}/respond`).send({ tripId });
    expect(respond.status).toBe(403);
    expect(respond.body.code).toBe('blocked');
  });
});
