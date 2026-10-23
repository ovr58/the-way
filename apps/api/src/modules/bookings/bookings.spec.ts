/**
 * Строка A2: брони сверх замороженных B1–B11 — гонка за последнее место, списки, доступ, отмена
 * `paid`, события водителя. Приложение и фикстуры — из `test/helpers` (только чтение).
 */
import type { INestApplication } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { call, createTestApp } from '../../../test/helpers/app';
import { addCancellation, closeDb, createBooking, createCity, createTrip, createUser, db } from '../../../test/helpers/db';
import { HOUR, atLocal } from '../../../test/helpers/dates';
import { trips } from '../trips/internal/schema';
import { bookings } from './internal/schema';

let app: INestApplication;
let cityA: number;
let cityB: number;

beforeAll(async () => {
  app = await createTestApp();
  cityA = await createCity('Бр-старт', 57.6, 39.8);
  cityB = await createCity('Бр-финиш', 58.0, 38.8);
});

afterAll(async () => {
  await app.close();
  await closeDb();
});

let slot = 0;
async function trip(overrides: Partial<Parameters<typeof createTrip>[0]> = {}) {
  slot += 1;
  const driver = await createUser({ mode: 'driver' });
  const departsAt = new Date(atLocal(2, 6).getTime() + slot * HOUR);
  const id = await createTrip({ driverId: driver.id, cityIds: [cityA, cityB], departsAt, ...overrides });
  return { id, driver };
}

const seatBody = { fromIdx: 0, toIdx: 1, seats: 1, parcelSize: 'none', parcelOnly: false, extras: [] };

describe('Брони — строка A2', () => {
  it('две параллельные оплаты последнего места: одна paid, другая no_seats', async () => {
    const t = await trip({ seatsTotal: 1 });
    const [p1, p2] = [await createUser(), await createUser()];
    const b1 = await createBooking({ tripId: t.id, passengerId: p1.id, status: 'awaiting_payment', toIdx: 1 });
    const b2 = await createBooking({ tripId: t.id, passengerId: p2.id, status: 'awaiting_payment', toIdx: 1 });
    const results = await Promise.all([
      call(app, p1.token).post(`/bookings/${b1}/pay`),
      call(app, p2.token).post(`/bookings/${b2}/pay`),
    ]);
    expect(results.map((r) => r.status).sort()).toEqual([200, 409]);
    expect(results.find((r) => r.status === 409)?.body.code).toBe('no_seats');
    const [row] = await db.select({ taken: trips.seatsTaken }).from(trips).where(eq(trips.id, t.id));
    expect(row.taken).toBe(1);
  });

  it('подтверждение при нехватке мест — no_seats; повторное подтверждение — invalid_transition; оплата водителем — 403', async () => {
    const t = await trip({ seatsTotal: 2, seatsTaken: 1 });
    const p = await createUser();
    const big = await createBooking({ tripId: t.id, passengerId: p.id, status: 'requested', toIdx: 1, seats: 2 });
    const driver = call(app, t.driver.token);
    expect((await driver.post(`/bookings/${big}/confirm`)).body.code).toBe('no_seats');

    const q = await createUser();
    const small = await createBooking({ tripId: t.id, passengerId: q.id, status: 'requested', toIdx: 1 });
    expect((await driver.post(`/bookings/${small}/confirm`)).status).toBe(200);
    expect((await driver.post(`/bookings/${small}/confirm`)).body.code).toBe('invalid_transition');
    expect((await driver.post(`/bookings/${small}/pay`)).status).toBe(403);
  });

  it('водитель видит заявки поездки без rejected и cancelled, телефон — после принятия; посторонний — 404', async () => {
    const t = await trip();
    const ids: Record<string, string> = {};
    for (const status of ['requested', 'awaiting_payment', 'paid', 'rejected', 'cancelled'] as const) {
      ids[status] = await createBooking({ tripId: t.id, passengerId: (await createUser()).id, status, toIdx: 1 });
    }
    const res = await call(app, t.driver.token).get(`/trips/${t.id}/bookings`);
    expect(res.status).toBe(200);
    const list = res.body as { id: string; status: string; passenger: { phone?: string | null } }[];
    expect(list.map((b) => b.id).sort()).toEqual([ids.requested, ids.awaiting_payment, ids.paid].sort());
    expect(list.find((b) => b.status === 'requested')?.passenger.phone ?? null).toBeNull();
    expect(list.find((b) => b.status === 'paid')?.passenger.phone).toBeTruthy();

    const stranger = await createUser();
    expect((await call(app, stranger.token).get(`/trips/${t.id}/bookings`)).status).toBe(404);
    const one = await call(app, t.driver.token).get(`/bookings/${ids.paid}`);
    expect(one.status).toBe(200);
    expect(one.body.id).toBe(ids.paid);
  });

  it('мои брони: без фильтра — все новые сверху; active и completed по «Флагам поездки»', async () => {
    const p = await createUser();
    const live = await trip();
    const past = await trip({ departsAt: new Date(Date.now() - HOUR) });
    const other = await trip();
    const active = await createBooking({ tripId: live.id, passengerId: p.id, status: 'paid', toIdx: 1 });
    const done = await createBooking({ tripId: past.id, passengerId: p.id, status: 'paid', toIdx: 1 });
    const rejected = await createBooking({ tripId: other.id, passengerId: p.id, status: 'rejected', toIdx: 1 });
    const http = call(app, p.token);
    expect((await http.get('/bookings/mine')).body.map((b: { id: string }) => b.id)).toEqual([rejected, done, active]);
    expect((await http.get('/bookings/mine?status=active')).body.map((b: { id: string }) => b.id)).toEqual([active]);
    expect((await http.get('/bookings/mine?status=completed')).body.map((b: { id: string }) => b.id)).toEqual([rejected, done]);
  });

  it('отмена paid возвращает места и место для посылки, refund = priceTotal на 3 дня; preview — willBlock', async () => {
    const t = await trip({ seatsTotal: 3, seatsTaken: 2, parcelSeatsTotal: 1, parcelSeatsTaken: 1, extras: [{ kind: 'parcel_s', price: 170 }] });
    const p = await createUser();
    const b = await createBooking({ tripId: t.id, passengerId: p.id, status: 'paid', toIdx: 1, seats: 2, parcelSize: 'S', priceTotal: 2170 });
    const http = call(app, p.token);
    const preview = await http.get(`/bookings/${b}/cancel-preview`);
    // `counts` — поле контракта: отмена оплаченной брони идёт в счёт.
    expect(preview.body).toEqual({ cancellationsLast30: 0, willBlock: false, refundAmount: 2170, counts: true });
    const res = await http.post(`/bookings/${b}/cancel`);
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ status: 'cancelled', cancellationsLast30: 1, refund: { amount: 2170, days: 3 } });
    const [row] = await db.select().from(trips).where(eq(trips.id, t.id));
    expect([row.seatsTaken, row.parcelSeatsTaken]).toEqual([0, 0]);
    expect((await http.get(`/bookings/${b}/cancel-preview`)).body.code).toBe('invalid_transition');
    expect((await call(app, t.driver.token).post(`/bookings/${b}/cancel`)).status).toBe(403);
  });

  it('отмена заявки requested при одной отмене за 30 дней: preview — willBlock false, блокировки нет', async () => {
    const t = await trip();
    const p = await createUser();
    await addCancellation(p.id, 'passenger');
    const b = await createBooking({ tripId: t.id, passengerId: p.id, status: 'requested', toIdx: 1 });
    const http = call(app, p.token);
    const preview = await http.get(`/bookings/${b}/cancel-preview`);
    expect(preview.body).toEqual({ cancellationsLast30: 1, willBlock: false, refundAmount: null, counts: false });
    const res = await http.post(`/bookings/${b}/cancel`);
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ status: 'cancelled', cancellationsLast30: 1, blockedUntil: null, refund: null });
  });

  it('события водителя: заявка — new_request, оплата — passenger_paid; seen гасит', async () => {
    const t = await trip();
    const p = await createUser();
    const created = await call(app, p.token).post(`/trips/${t.id}/bookings`).send(seatBody);
    expect(created.status).toBe(201);
    const id = created.body.id as string;
    const driver = call(app, t.driver.token);
    const kinds = async () => ((await driver.get('/updates')).body as { bookingId: string; kind: string }[]).filter((u) => u.bookingId === id).map((u) => u.kind);
    expect(await kinds()).toEqual(['new_request']);
    expect((await driver.post(`/updates/${id}/seen`)).status).toBe(204);
    expect(await kinds()).toEqual([]);

    await driver.post(`/bookings/${id}/confirm`);
    expect(await kinds()).toEqual([]);
    expect((await call(app, p.token).post(`/bookings/${id}/pay`)).status).toBe(200);
    expect(await kinds()).toEqual(['passenger_paid']);
    const [row] = await db.select().from(bookings).where(eq(bookings.id, id));
    expect(row.passengerSeenStatus).toBe('paid');
    expect((await call(app, (await createUser()).token).post(`/updates/${id}/seen`)).status).toBe(404);
  });
});
