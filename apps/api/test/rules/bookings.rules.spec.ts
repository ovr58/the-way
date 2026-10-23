/**
 * Проверки правил броней (B1–B11). Пишутся до кода правил и меняются только отдельным коммитом.
 */
import type { INestApplication } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { blocks } from '../../src/modules/users/internal/schema';
import { call, createTestApp } from '../helpers/app';
import {
  addCancellation,
  closeDb,
  createBooking,
  createCity,
  createTrip,
  createUser,
  db,
} from '../helpers/db';
import { HOUR, atLocal } from '../helpers/dates';

let app: INestApplication;
let cityA: number;
let cityB: number;
let cityC: number;
let cityD: number;

beforeAll(async () => {
  app = await createTestApp();
  cityA = await createCity('Старт', 57.6261, 39.8845);
  cityB = await createCity('Финиш', 58.0485, 38.8584);
  cityC = await createCity('Промежуток1', 57.8853, 39.5381);
  cityD = await createCity('Промежуток2', 57.95, 39.3);
});

afterAll(async () => {
  await app.close();
  await closeDb();
});

/** Тело брони места на весь маршрут; поля — переопределить. */
function seatBody(toIdx: number, overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return { fromIdx: 0, toIdx, seats: 1, parcelSize: 'none', parcelOnly: false, extras: [], ...overrides };
}

/** Часы отправления — разные у поездок одного файла, чтобы не складывались в группы дублей. */
let hourSlot = 0;
function nextDeparture(): Date {
  hourSlot += 1;
  return new Date(atLocal(1, 6).getTime() + hourSlot * HOUR);
}

async function trip(overrides: Partial<Parameters<typeof createTrip>[0]> = {}): Promise<{ id: string; driver: Awaited<ReturnType<typeof createUser>> }> {
  const driver = await createUser({ mode: 'driver' });
  const id = await createTrip({ driverId: driver.id, cityIds: [cityA, cityB], departsAt: nextDeparture(), ...overrides });
  return { id, driver };
}

describe('Брони', () => {
  it('B1: стандартное бронирование — заявка requested; быстрое — сразу awaiting_payment', async () => {
    const standard = await trip({ bookingMode: 'standard' });
    const passenger = await createUser();
    const res = await call(app, passenger.token).post(`/trips/${standard.id}/bookings`).send(seatBody(1));
    expect(res.status).toBe(201);
    expect(res.body.status).toBe('requested');

    const instant = await trip({ bookingMode: 'instant' });
    const fast = await call(app, passenger.token).post(`/trips/${instant.id}/bookings`).send(seatBody(1));
    expect(fast.status).toBe(201);
    expect(fast.body.status).toBe('awaiting_payment');
  });

  it('B2: водитель подтверждает → awaiting_payment, отклоняет → rejected; пассажир — 403, посторонний — 404', async () => {
    const t = await trip();
    const passenger = await createUser();
    const accepted = await createBooking({ tripId: t.id, passengerId: passenger.id, status: 'requested', toIdx: 1 });
    const other = await createUser();
    const declined = await createBooking({ tripId: t.id, passengerId: other.id, status: 'requested', toIdx: 1 });
    const driverHttp = call(app, t.driver.token);

    const confirm = await driverHttp.post(`/bookings/${accepted}/confirm`);
    expect(confirm.status).toBe(200);
    expect(confirm.body.status).toBe('awaiting_payment');

    const reject = await driverHttp.post(`/bookings/${declined}/reject`);
    expect(reject.status).toBe(200);
    expect(reject.body.status).toBe('rejected');

    const third = await createUser();
    const pending = await createBooking({ tripId: t.id, passengerId: third.id, status: 'requested', toIdx: 1 });
    const byPassenger = await call(app, third.token).post(`/bookings/${pending}/confirm`);
    expect(byPassenger.status).toBe(403);
    expect(byPassenger.body.code).toBe('forbidden');

    const stranger = await createUser();
    const byStranger = await call(app, stranger.token).post(`/bookings/${pending}/confirm`);
    expect(byStranger.status).toBe(404);
    expect(byStranger.body.code).toBe('not_found');
  });

  it('B3: «Оплатить» → paid, свободных мест меньше на число мест брони', async () => {
    const t = await trip({ seatsTotal: 3 });
    const passenger = await createUser();
    const booking = await createBooking({ tripId: t.id, passengerId: passenger.id, status: 'awaiting_payment', toIdx: 1, seats: 2 });
    const res = await call(app, passenger.token).post(`/bookings/${booking}/pay`);
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('paid');
    expect(res.body.trip.seatsFree).toBe(1);
  });

  it('B4: последнее место — оплативший первым получает его, второй — no_seats', async () => {
    const t = await trip({ seatsTotal: 1 });
    const first = await createUser();
    const second = await createUser();
    const b1 = await createBooking({ tripId: t.id, passengerId: first.id, status: 'awaiting_payment', toIdx: 1 });
    const b2 = await createBooking({ tripId: t.id, passengerId: second.id, status: 'awaiting_payment', toIdx: 1 });
    const paid = await call(app, first.token).post(`/bookings/${b1}/pay`);
    expect(paid.status).toBe(200);
    expect(paid.body.status).toBe('paid');
    const late = await call(app, second.token).post(`/bookings/${b2}/pay`);
    expect(late.body.code).toBe('no_seats');
  });

  it('B5: сумма = цена отрезка × мест + услуги + посылка; та же сумма из quote', async () => {
    const t = await trip({
      cityIds: [cityA, cityC, cityB],
      priceFull: 1000,
      prices: [
        { fromIdx: 0, toIdx: 1, price: 400 },
        { fromIdx: 1, toIdx: 2, price: 700 },
      ],
      extras: [
        { kind: 'child_seat', price: 150 },
        { kind: 'luggage', price: 100 },
        { kind: 'parcel_m', price: 250 },
      ],
      parcelSeatsTotal: 2,
    });
    const passenger = await createUser();
    const http = call(app, passenger.token);
    const quote = await http
      .get(`/trips/${t.id}/quote`)
      .query({ fromIdx: 0, toIdx: 1, seats: 2, parcelSize: 'M', extras: 'child_seat,luggage' });
    expect(quote.status).toBe(200);
    expect(quote.body).toEqual({ segmentPrice: 400, priceTotal: 400 * 2 + 150 + 100 + 250 });

    const res = await http
      .post(`/trips/${t.id}/bookings`)
      .send(seatBody(1, { seats: 2, parcelSize: 'M', extras: ['child_seat', 'luggage'], parcelComment: 'Коробка' }));
    expect(res.status).toBe(201);
    expect(res.body.priceTotal).toBe(1300);
    expect(res.body.segmentPrice).toBe(400);
  });

  it('B6: посылка без проезда не занимает мест и разрешена, только если водитель разрешил; цена — цена размера', async () => {
    const allowed = await trip({ parcelOnlyAllowed: true, parcelSeatsTotal: 2, extras: [{ kind: 'parcel_s', price: 170 }] });
    const passenger = await createUser();
    const http = call(app, passenger.token);
    const ok = await http.post(`/trips/${allowed.id}/bookings`).send(seatBody(1, { seats: 0, parcelOnly: true, parcelSize: 'S' }));
    expect(ok.status).toBe(201);
    expect(ok.body.priceTotal).toBe(170);
    expect(ok.body.trip.seatsFree).toBe(3);

    const forbidden = await trip({ parcelOnlyAllowed: false, parcelSeatsTotal: 2, extras: [{ kind: 'parcel_s', price: 170 }] });
    const refused = await http.post(`/trips/${forbidden.id}/bookings`).send(seatBody(1, { seats: 0, parcelOnly: true, parcelSize: 'S' }));
    expect(refused.body.code).toBe('validation');
  });

  it('B6: размер, который водитель не возит, — отказ', async () => {
    const t = await trip({ parcelSeatsTotal: 2, extras: [{ kind: 'parcel_s', price: 170 }] });
    const passenger = await createUser();
    const res = await call(app, passenger.token).post(`/trips/${t.id}/bookings`).send(seatBody(1, { parcelSize: 'L' }));
    expect(res.body.code).toBe('validation');
  });

  it('B6: оплаченная посылка занимает место для посылок; мест для посылок нет — no_seats', async () => {
    const t = await trip({ parcelSeatsTotal: 2, extras: [{ kind: 'parcel_s', price: 170 }] });
    const passenger = await createUser();
    const booking = await createBooking({ tripId: t.id, passengerId: passenger.id, status: 'awaiting_payment', toIdx: 1, parcelSize: 'S', priceTotal: 1170 });
    const paid = await call(app, passenger.token).post(`/bookings/${booking}/pay`);
    expect(paid.status).toBe(200);
    expect(paid.body.trip.parcelSeatsFree).toBe(1);

    const full = await trip({ parcelSeatsTotal: 1, parcelSeatsTaken: 1, extras: [{ kind: 'parcel_s', price: 170 }] });
    const res = await call(app, (await createUser()).token).post(`/trips/${full.id}/bookings`).send(seatBody(1, { parcelSize: 'S' }));
    expect(res.body.code).toBe('no_seats');
  });

  it('B11: цена между любыми точками — сумма участков на пути; весь маршрут — цена всего маршрута', async () => {
    const t = await trip({
      cityIds: [cityA, cityC, cityD, cityB],
      priceFull: 1000,
      prices: [
        { fromIdx: 0, toIdx: 1, price: 300 },
        { fromIdx: 1, toIdx: 2, price: 400 },
        { fromIdx: 2, toIdx: 3, price: 500 },
      ],
    });
    const passenger = await createUser();
    const http = call(app, passenger.token);
    const quote = async (fromIdx: number, toIdx: number): Promise<unknown> =>
      (await http.get(`/trips/${t.id}/quote`).query({ fromIdx, toIdx, seats: 1 })).body;
    expect(await quote(1, 2)).toEqual({ segmentPrice: 400, priceTotal: 400 });
    expect(await quote(1, 3)).toEqual({ segmentPrice: 900, priceTotal: 900 });
    expect(await quote(0, 2)).toEqual({ segmentPrice: 700, priceTotal: 700 });
    expect(await quote(0, 3)).toEqual({ segmentPrice: 1000, priceTotal: 1000 });

    const res = await http.post(`/trips/${t.id}/bookings`).send(seatBody(2, { fromIdx: 1, seats: 2 }));
    expect(res.status).toBe(201);
    expect(res.body.segmentPrice).toBe(400);
    expect(res.body.priceTotal).toBe(800);
  });

  it('B7: первая отмена принятой брони — только предупреждение', async () => {
    const t = await trip();
    const passenger = await createUser();
    const booking = await createBooking({ tripId: t.id, passengerId: passenger.id, status: 'awaiting_payment', toIdx: 1 });
    const res = await call(app, passenger.token).post(`/bookings/${booking}/cancel`);
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('cancelled');
    expect(res.body.cancellationsLast30).toBe(1);
    expect(res.body.blockedUntil ?? null).toBeNull();
    expect(await db.$count(blocks, eq(blocks.userId, passenger.id))).toBe(0);
  });

  it('B7: вторая отмена принятой брони за 30 дней блокирует бронирование на 30 дней', async () => {
    const passenger = await createUser();
    // Первая отмена — бронь, уже принятая водителем (`paid`), отменена раньше.
    const earlier = await trip();
    await createBooking({ tripId: earlier.id, passengerId: passenger.id, status: 'cancelled', toIdx: 1 });
    await addCancellation(passenger.id, 'passenger');

    const t = await trip();
    const booking = await createBooking({ tripId: t.id, passengerId: passenger.id, status: 'paid', toIdx: 1 });
    const http = call(app, passenger.token);
    const res = await http.post(`/bookings/${booking}/cancel`);
    expect(res.status).toBe(200);
    expect(res.body.cancellationsLast30).toBe(2);
    expect(res.body.blockedUntil).toBeTruthy();
    const rows = await db.select().from(blocks).where(eq(blocks.userId, passenger.id));
    expect(rows).toHaveLength(1);
    expect(Math.round((rows[0].endsAt.getTime() - rows[0].startsAt.getTime()) / (24 * HOUR))).toBe(30);

    const next = await trip();
    const blocked = await http.post(`/trips/${next.id}/bookings`).send(seatBody(1));
    expect(blocked.status).toBe(403);
    expect(blocked.body.code).toBe('blocked');
  });

  it('B8: «Водитель принял заявку» приходит пассажиру один раз; после seen его нет', async () => {
    const t = await trip();
    const passenger = await createUser();
    const booking = await createBooking({ tripId: t.id, passengerId: passenger.id, status: 'requested', toIdx: 1 });
    const confirm = await call(app, t.driver.token).post(`/bookings/${booking}/confirm`);
    expect(confirm.status).toBe(200);

    const http = call(app, passenger.token);
    const updates = await http.get('/updates');
    expect(updates.status).toBe(200);
    const mine = (updates.body as { bookingId: string; kind: string }[]).filter((u) => u.bookingId === booking);
    expect(mine).toEqual([expect.objectContaining({ bookingId: booking, tripId: t.id, kind: 'driver_accepted' })]);

    const seen = await http.post(`/updates/${booking}/seen`);
    expect(seen.status).toBe(204);
    const after = await http.get('/updates');
    expect((after.body as { bookingId: string }[]).filter((u) => u.bookingId === booking)).toEqual([]);
  });

  it('B8: при быстром бронировании события «принял» нет — бронь сразу awaiting_payment', async () => {
    const t = await trip({ bookingMode: 'instant' });
    const passenger = await createUser();
    const http = call(app, passenger.token);
    const created = await http.post(`/trips/${t.id}/bookings`).send(seatBody(1));
    expect(created.status).toBe(201);
    expect(created.body.status).toBe('awaiting_payment');
    const updates = await http.get('/updates');
    expect(updates.status).toBe(200);
    expect((updates.body as { bookingId: string; kind: string }[]).filter((u) => u.bookingId === created.body.id)).toEqual([]);
  });

  it('B9: чужую бронь открыть нельзя — 404', async () => {
    const t = await trip();
    const passenger = await createUser();
    const booking = await createBooking({ tripId: t.id, passengerId: passenger.id, status: 'requested', toIdx: 1 });
    const stranger = await createUser();
    const res = await call(app, stranger.token).get(`/bookings/${booking}`);
    expect(res.status).toBe(404);
    expect(res.body.code).toBe('not_found');
  });

  it('B10: бронь дубля без «Идёт регистрация» — trip_unavailable; повторная бронь — booking_exists', async () => {
    const at = nextDeparture();
    const firstDriver = await createUser({ mode: 'driver' });
    const secondDriver = await createUser({ mode: 'driver' });
    const first = await createTrip({ driverId: firstDriver.id, cityIds: [cityA, cityB], departsAt: at, createdAt: new Date(Date.now() - HOUR) });
    const second = await createTrip({ driverId: secondDriver.id, cityIds: [cityA, cityB], departsAt: at });
    const passenger = await createUser();
    const http = call(app, passenger.token);

    const duplicate = await http.post(`/trips/${second}/bookings`).send(seatBody(1));
    expect(duplicate.body.code).toBe('trip_unavailable');

    const ok = await http.post(`/trips/${first}/bookings`).send(seatBody(1));
    expect(ok.status).toBe(201);
    const again = await http.post(`/trips/${first}/bookings`).send(seatBody(1));
    expect(again.body.code).toBe('booking_exists');
  });
});
