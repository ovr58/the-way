/**
 * Проверки правил аккаунта (C1–C6): счёт отмен,
 * возврат, жалобы, личные данные, выход. Проверки пишутся до правки кода и меняются только
 * отдельным коммитом.
 */
import type { INestApplication } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { complaints } from '../../src/modules/reviews/internal/schema';
import { blocks, cancellations, users } from '../../src/modules/users/internal/schema';
import { call, createTestApp } from '../helpers/app';
import { closeDb, createBooking, createCar, createCity, createTrip, createUser, db } from '../helpers/db';
import { DAY, HOUR, atLocal, isoLocal } from '../helpers/dates';

let app: INestApplication;
let cityA: number;
let cityB: number;

beforeAll(async () => {
  app = await createTestApp();
  cityA = await createCity('Старт', 57.6261, 39.8845);
  cityB = await createCity('Финиш', 58.0485, 38.8584);
});

afterAll(async () => {
  await app.close();
  await closeDb();
});

/** Тело брони места на весь маршрут. */
function seatBody(): Record<string, unknown> {
  return { fromIdx: 0, toIdx: 1, seats: 1, parcelSize: 'none', parcelOnly: false, extras: [] };
}

/** Тело `POST /trips`, проходящее все правила публикации. */
function tripBody(carId: string): Record<string, unknown> {
  const departsAt = atLocal(1, 10);
  return {
    kind: 'ride',
    vehicleKind: 'car',
    stops: [
      { cityId: cityA, address: 'Автовокзал' },
      { cityId: cityB, address: 'Вокзал' },
    ],
    departsAt: isoLocal(departsAt),
    arrivesAt: isoLocal(new Date(departsAt.getTime() + 2 * HOUR)),
    seatsTotal: 3,
    priceFull: 1000,
    prices: [],
    priceBoardingMin: 100,
    carId,
    extras: [],
    parcelOnlyAllowed: false,
    parcelSeatsTotal: 0,
    bookingMode: 'standard',
  };
}

/** Часы отправления — разные у поездок файла, чтобы не складывались в группы дублей. */
let hourSlot = 0;
function nextDeparture(): Date {
  hourSlot += 1;
  return new Date(atLocal(2, 6).getTime() + hourSlot * HOUR);
}

async function trip(overrides: Partial<Parameters<typeof createTrip>[0]> = {}): Promise<string> {
  const driver = await createUser({ mode: 'driver' });
  return createTrip({ driverId: driver.id, cityIds: [cityA, cityB], departsAt: nextDeparture(), ...overrides });
}

describe('Аккаунт', () => {
  it('C1: отмена заявки, которую водитель ещё не принял, не идёт в счёт отмен и не блокирует', async () => {
    const passenger = await createUser();
    const http = call(app, passenger.token);
    const first = await createBooking({ tripId: await trip(), passengerId: passenger.id, status: 'requested', toIdx: 1 });
    const second = await createBooking({ tripId: await trip(), passengerId: passenger.id, status: 'requested', toIdx: 1 });

    for (const booking of [first, second]) {
      const preview = await http.get(`/bookings/${booking}/cancel-preview`);
      expect(preview.status).toBe(200);
      expect(preview.body.cancellationsLast30).toBe(0);
      expect(preview.body.willBlock).toBe(false);
      expect(preview.body.refundAmount ?? null).toBeNull();

      const res = await http.post(`/bookings/${booking}/cancel`);
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('cancelled');
      expect(res.body.cancellationsLast30).toBe(0);
      expect(res.body.blockedUntil ?? null).toBeNull();
    }

    expect(await db.$count(blocks, eq(blocks.userId, passenger.id))).toBe(0);
    const third = await http.post(`/trips/${await trip()}/bookings`).send(seatBody());
    expect(third.status).toBe(201);
  });

  it('C2: вторая отмена принятой брони за 30 дней — окно заранее говорит «заблокирует», затем блокировка на 30 дней', async () => {
    const passenger = await createUser();
    await db.insert(cancellations).values({ userId: passenger.id, role: 'passenger', createdAt: new Date(Date.now() - 10 * DAY) });
    const booking = await createBooking({ tripId: await trip(), passengerId: passenger.id, status: 'awaiting_payment', toIdx: 1 });
    const http = call(app, passenger.token);

    const preview = await http.get(`/bookings/${booking}/cancel-preview`);
    expect(preview.status).toBe(200);
    expect(preview.body.cancellationsLast30).toBe(1);
    expect(preview.body.willBlock).toBe(true);
    expect(preview.body.refundAmount ?? null).toBeNull();

    const res = await http.post(`/bookings/${booking}/cancel`);
    expect(res.status).toBe(200);
    expect(res.body.cancellationsLast30).toBe(2);
    expect(res.body.blockedUntil).toBeTruthy();
    expect(res.body.refund ?? null).toBeNull();
    const until = new Date(res.body.blockedUntil).getTime();
    expect(Math.round((until - Date.now()) / DAY)).toBe(30);

    const book = await http.post(`/trips/${await trip()}/bookings`).send(seatBody());
    expect(book.status).toBe(403);
    expect(book.body.code).toBe('blocked');

    const carId = await createCar(passenger.id);
    const publish = await http.post('/trips').send(tripBody(carId));
    expect(publish.status).toBe(403);
    expect(publish.body.code).toBe('blocked');
  });

  it('C3: отмена оплаченной брони — возврат суммы брони за 3 дня, свободных мест больше на места брони', async () => {
    const passenger = await createUser();
    const tripId = await trip({ seatsTotal: 3, seatsTaken: 2 });
    const booking = await createBooking({ tripId, passengerId: passenger.id, status: 'paid', toIdx: 1, seats: 2, priceTotal: 2400 });
    const http = call(app, passenger.token);

    const before = await http.get(`/trips/${tripId}`);
    expect(before.status).toBe(200);
    expect(before.body.seatsFree).toBe(1);

    const preview = await http.get(`/bookings/${booking}/cancel-preview`);
    expect(preview.status).toBe(200);
    expect(preview.body.refundAmount).toBe(2400);

    const res = await http.post(`/bookings/${booking}/cancel`);
    expect(res.status).toBe(200);
    expect(res.body.refund).toEqual({ amount: 2400, days: 3 });

    const after = await http.get(`/trips/${tripId}`);
    expect(after.body.seatsFree).toBe(3);
  });

  it('C4: «Жалобы» — полученные пользователем, новые сверху; поданные им самим не показываются', async () => {
    const user = await createUser({ mode: 'driver' });
    const other = await createUser();
    const now = Date.now();
    await db.insert(complaints).values([
      { authorId: other.id, targetId: user.id, reason: 'Старая полученная', createdAt: new Date(now - 2 * DAY) },
      { authorId: other.id, targetId: user.id, reason: 'Свежая полученная', createdAt: new Date(now - DAY) },
      { authorId: user.id, targetId: other.id, reason: 'Поданная', createdAt: new Date(now - HOUR) },
    ]);

    const res = await call(app, user.token).get('/me/complaints');
    expect(res.status).toBe(200);
    expect(res.body.map((c: { reason: string }) => c.reason)).toEqual(['Свежая полученная', 'Старая полученная']);
    expect(res.body[0].status).toBe('open');
  });

  it('C5: «Личные данные» — новое имя сохраняется; номер телефона правке не подлежит', async () => {
    const user = await createUser({ name: 'Старое имя' });
    const http = call(app, user.token);

    const renamed = await http.patch('/me').send({ name: 'Новое имя' });
    expect(renamed.status).toBe(200);
    expect(renamed.body.name).toBe('Новое имя');
    const me = await http.get('/me');
    expect(me.body.name).toBe('Новое имя');

    const phone = await http.patch('/me').send({ phone: '+79991112233' });
    expect(phone.status).toBe(400);
    expect(phone.body.code).toBe('validation');
    const [row] = await db.select({ phone: users.phone }).from(users).where(eq(users.id, user.id));
    expect(row.phone).toBe(user.phone);
  });

  it('C6: после «Выйти» тем же входом ничего не открыть — 401 на GET /me', async () => {
    const user = await createUser();
    const http = call(app, user.token);
    expect((await http.get('/me')).status).toBe(200);

    const logout = await http.post('/auth/logout');
    expect(logout.status).toBe(204);
    expect((await http.get('/me')).status).toBe(401);
  });
});
