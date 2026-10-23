/** Правка, приём, отмена, «Мои поездки» сверх замороженных T6/T7/T9: чужие поездки, счётчики, брони при отмене. */
import type { INestApplication } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { call, createTestApp } from '../../../../test/helpers/app';
import { atLocal } from '../../../../test/helpers/dates';
import { closeDb, createBooking, createCar, createCity, createTrip, createUser, db } from '../../../../test/helpers/db';
import { bookings } from '../../bookings/internal/schema';
import { trips } from './schema';

let app: INestApplication;
let cityA: number;
let cityB: number;
let cityC: number;

beforeAll(async () => {
  app = await createTestApp();
  cityA = await createCity('УпрА', 57.6, 39.8);
  cityB = await createCity('УпрБ', 58.0, 38.8);
  cityC = await createCity('УпрВ', 57.8, 39.3);
});

afterAll(async () => {
  await app.close();
  await closeDb();
});

async function driver(): Promise<{ token: string; id: string; carId: string }> {
  const u = await createUser({ mode: 'driver' });
  return { ...u, carId: await createCar(u.id) };
}

describe('PATCH /trips/{id}', () => {
  it('новый маршрут без цен — validation; чужая поездка — 403; нет такой — 404', async () => {
    const d = await driver();
    const trip = await createTrip({ driverId: d.id, carId: d.carId, cityIds: [cityA, cityB], departsAt: atLocal(1, 10) });
    const stops = [cityA, cityC, cityB].map((cityId) => ({ cityId, address: 'Остановка' }));
    const noPrices = await call(app, d.token).patch(`/trips/${trip}`).send({ stops });
    expect(noPrices.status).toBe(400);
    expect(noPrices.body.code).toBe('validation');

    const stranger = await createUser({ mode: 'driver' });
    const denied = await call(app, stranger.token).patch(`/trips/${trip}`).send({ priceFull: 1500 });
    expect(denied.status).toBe(403);
    expect(denied.body.code).toBe('forbidden');
  });

  it('правка не нарушает правил: время не кратно 30 минутам — invalid_time_step, поездка не изменилась', async () => {
    const d = await driver();
    const trip = await createTrip({ driverId: d.id, carId: d.carId, cityIds: [cityA, cityB], departsAt: atLocal(1, 10), priceFull: 900 });
    const res = await call(app, d.token).patch(`/trips/${trip}`).send({ departsAt: atLocal(1, 10, 15).toISOString(), priceFull: 1200 });
    expect(res.body.code).toBe('invalid_time_step');
    const [row] = await db.select().from(trips).where(eq(trips.id, trip));
    expect(row.priceFull).toBe(900);
  });

  it('при запросе брони (requested) правка ещё открыта', async () => {
    const d = await driver();
    const trip = await createTrip({ driverId: d.id, carId: d.carId, cityIds: [cityA, cityB], departsAt: atLocal(1, 10) });
    await createBooking({ tripId: trip, passengerId: (await createUser()).id, status: 'requested', toIdx: 1 });
    const res = await call(app, d.token).patch(`/trips/${trip}`).send({ priceFull: 1300 });
    expect(res.status).toBe(200);
    expect(res.body.price).toBe(1300);
  });
});

describe('места и приём', () => {
  it('мест больше, чем в авто, — validation; чужая поездка — 403', async () => {
    const d = await driver();
    const trip = await createTrip({ driverId: d.id, carId: d.carId, cityIds: [cityA, cityB], departsAt: atLocal(1, 10) });
    const res = await call(app, d.token).post(`/trips/${trip}/seats`).send({ seatsTotal: 5 });
    expect(res.body.code).toBe('validation');
    const stranger = await createUser({ mode: 'driver' });
    expect((await call(app, stranger.token).post(`/trips/${trip}/seats`).send({ seatsTotal: 2 })).status).toBe(403);
  });

  it('close-intake: поездка остаётся в «Мои поездки · активные», в ленте её нет; повтор не падает', async () => {
    const d = await driver();
    const trip = await createTrip({ driverId: d.id, carId: d.carId, cityIds: [cityA, cityB], departsAt: atLocal(1, 10) });
    const http = call(app, d.token);
    const closed = await http.post(`/trips/${trip}/close-intake`);
    expect(closed.status).toBe(200);
    expect(closed.body).toMatchObject({ effectiveStatus: 'intake_closed', registrationOpen: false, bookable: false });
    const [row] = await db.select().from(trips).where(eq(trips.id, trip));
    expect(row.status).toBe('intake_closed');
    expect((await http.post(`/trips/${trip}/close-intake`)).status).toBe(200);

    const mine = await http.get('/trips/mine').query({ status: 'active' });
    expect((mine.body as { id: string }[]).map((t) => t.id)).toContain(trip);
    const feed = await call(app, (await createUser()).token).get('/trips').query({ fromCityId: cityA, toCityId: cityB });
    expect((feed.body as { id: string }[]).map((t) => t.id)).not.toContain(trip);
  });
});

describe('отмена поездки', () => {
  it('cancel-preview: без пассажиров не блокирует; со второй отменой с пассажиром — willBlock', async () => {
    const d = await driver();
    const empty = await createTrip({ driverId: d.id, carId: d.carId, cityIds: [cityA, cityB], departsAt: atLocal(2, 9) });
    const preview = await call(app, d.token).get(`/trips/${empty}/cancel-preview`);
    expect(preview.body).toMatchObject({ cancellationsLast30: 0, willBlock: false });

    const first = await createTrip({ driverId: d.id, cityIds: [cityA, cityB], departsAt: atLocal(2, 12) });
    await createBooking({ tripId: first, passengerId: (await createUser()).id, status: 'paid', toIdx: 1 });
    expect((await call(app, d.token).get(`/trips/${first}/cancel-preview`)).body.willBlock).toBe(false);
    expect((await call(app, d.token).post(`/trips/${first}/cancel`)).status).toBe(200);

    const second = await createTrip({ driverId: d.id, cityIds: [cityA, cityB], departsAt: atLocal(2, 15) });
    await createBooking({ tripId: second, passengerId: (await createUser()).id, status: 'awaiting_payment', toIdx: 1 });
    expect((await call(app, d.token).get(`/trips/${second}/cancel-preview`)).body).toMatchObject({
      cancellationsLast30: 1,
      willBlock: true,
    });
  });

  it('cancel: брони поездки становятся cancelled, водитель не видит их событием; повторная отмена — invalid_transition', async () => {
    const d = await driver();
    const trip = await createTrip({ driverId: d.id, carId: d.carId, cityIds: [cityA, cityB], departsAt: atLocal(2, 9) });
    const requested = await createBooking({ tripId: trip, passengerId: (await createUser()).id, status: 'requested', toIdx: 1 });
    const paid = await createBooking({ tripId: trip, passengerId: (await createUser()).id, status: 'paid', toIdx: 1 });

    const res = await call(app, d.token).post(`/trips/${trip}/cancel`);
    expect(res.status).toBe(200);
    const rows = await db.select().from(bookings).where(eq(bookings.tripId, trip));
    expect(rows.map((b) => b.id).sort()).toEqual([requested, paid].sort());
    for (const b of rows) {
      expect(b.status).toBe('cancelled');
      expect(b.driverSeenStatus).toBe('cancelled');
      expect(b.cancelledAt).not.toBeNull();
    }
    const [row] = await db.select().from(trips).where(eq(trips.id, trip));
    expect(row.status).toBe('cancelled');

    const again = await call(app, d.token).post(`/trips/${trip}/cancel`);
    expect(again.body.code).toBe('invalid_transition');
    const stranger = await createUser({ mode: 'driver' });
    expect((await call(app, stranger.token).post(`/trips/${trip}/cancel`)).status).toBe(403);
  });
});

describe('GET /trips/mine', () => {
  it('счётчики броней, посылки, отклики (до двух по времени); завершённые и отменённые — во вкладке completed', async () => {
    const d = await driver();
    const trip = await createTrip({ driverId: d.id, carId: d.carId, cityIds: [cityA, cityB], departsAt: atLocal(1, 10) });
    const p1 = await createUser();
    const p2 = await createUser();
    const p3 = await createUser();
    const p4 = await createUser();
    await createBooking({ tripId: trip, passengerId: p1.id, status: 'requested', toIdx: 1 });
    await createBooking({ tripId: trip, passengerId: p2.id, status: 'awaiting_payment', toIdx: 1, parcelSize: 'S' });
    await createBooking({ tripId: trip, passengerId: p3.id, status: 'paid', toIdx: 1 });
    await createBooking({ tripId: trip, passengerId: p4.id, status: 'rejected', toIdx: 1 });
    const cancelled = await createTrip({ driverId: d.id, carId: d.carId, cityIds: [cityA, cityB], departsAt: atLocal(2, 10), status: 'cancelled' });

    const active = await call(app, d.token).get('/trips/mine').query({ status: 'active' });
    expect(active.status).toBe(200);
    const card = (active.body as { id: string }[]).find((t) => t.id === trip);
    expect(card).toMatchObject({ requested: 1, awaitingPayment: 1, paid: 1, parcels: 1 });
    expect((card as unknown as { responders: { id: string }[] }).responders.map((r) => r.id)).toEqual([p1.id, p2.id]);
    expect((active.body as { id: string }[]).map((t) => t.id)).not.toContain(cancelled);

    const done = await call(app, d.token).get('/trips/mine').query({ status: 'completed' });
    expect((done.body as { id: string }[]).map((t) => t.id)).toEqual([cancelled]);
  });

  it('чужие поездки в «Мои поездки» не попадают', async () => {
    const d = await driver();
    const other = await driver();
    const theirs = await createTrip({ driverId: other.id, carId: other.carId, cityIds: [cityA, cityB], departsAt: atLocal(1, 10) });
    const mine = await call(app, d.token).get('/trips/mine').query({ status: 'active' });
    expect((mine.body as { id: string }[]).map((t) => t.id)).not.toContain(theirs);
  });
});
