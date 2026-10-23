/**
 * Проверки правил поездок (T1–T11). Пишутся до кода правил и меняются только отдельным коммитом.
 */
import type { INestApplication } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { blocks } from '../../src/modules/users/internal/schema';
import { call, createTestApp } from '../helpers/app';
import {
  addReview,
  closeDb,
  createBooking,
  createCar,
  createCity,
  createTrip,
  createUser,
  db,
} from '../helpers/db';
import { DAY, HOUR, atLocal, dateLocal, isoLocal } from '../helpers/dates';

let app: INestApplication;
let cityA: number;
let cityB: number;
let cityC: number;
let cityD: number;
let cityE: number;

beforeAll(async () => {
  app = await createTestApp();
  cityA = await createCity('Старт', 57.6261, 39.8845);
  cityB = await createCity('Финиш', 58.0485, 38.8584);
  cityC = await createCity('Промежуток1', 57.8853, 39.5381);
  cityD = await createCity('Промежуток2', 57.95, 39.3);
  cityE = await createCity('Промежуток3', 58.0, 39.1);
});

afterAll(async () => {
  await app.close();
  await closeDb();
});

/** Тело `POST /trips`, проходящее все правила; поля — переопределить. */
function tripBody(carId: string, overrides: Record<string, unknown> = {}): Record<string, unknown> {
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
    ...overrides,
  };
}

async function driverWithCar(): Promise<{ token: string; id: string; carId: string }> {
  const driver = await createUser({ mode: 'driver' });
  return { ...driver, carId: await createCar(driver.id) };
}

describe('Поездки', () => {
  it('T1: лента — водители с отзывами по рейтингу ↓, при равенстве время ↑; без отзывов — после них', async () => {
    const low = await createUser({ mode: 'driver' });
    const top = await createUser({ mode: 'driver' });
    const topEarly = await createUser({ mode: 'driver' });
    const lowTrip = await createTrip({ driverId: low.id, cityIds: [cityA, cityE], departsAt: atLocal(1, 9) });
    const topTrip = await createTrip({ driverId: top.id, cityIds: [cityA, cityE], departsAt: atLocal(1, 12) });
    const earlyTrip = await createTrip({ driverId: topEarly.id, cityIds: [cityA, cityE], departsAt: atLocal(1, 10, 30) });
    await addReview(low.id, lowTrip, 3);
    await addReview(top.id, topTrip, 5);
    const passenger = await createUser();

    const res = await call(app, passenger.token).get('/trips').query({ fromCityId: cityA, toCityId: cityE });
    expect(res.status).toBe(200);
    const ids = (res.body as { id: string }[]).map((t) => t.id);
    expect(ids).toEqual([topTrip, lowTrip, earlyTrip]);
  });

  it('T2: две поездки с одинаковыми городами и временем — регистрация и бронь только у первой', async () => {
    const at = atLocal(1, 14);
    const first = await createTrip({
      driverId: (await createUser({ mode: 'driver' })).id,
      cityIds: [cityA, cityD],
      departsAt: at,
      createdAt: new Date(Date.now() - HOUR),
    });
    const second = await createTrip({ driverId: (await createUser({ mode: 'driver' })).id, cityIds: [cityA, cityD], departsAt: at });
    const passenger = await createUser();

    const res = await call(app, passenger.token).get('/trips').query({ fromCityId: cityA, toCityId: cityD });
    expect(res.status).toBe(200);
    const cards = res.body as { id: string; registrationOpen: boolean; duplicates: number; bookable: boolean }[];
    const a = cards.find((c) => c.id === first);
    const b = cards.find((c) => c.id === second);
    expect(a).toMatchObject({ registrationOpen: true, duplicates: 2, bookable: true });
    expect(b).toMatchObject({ registrationOpen: false, duplicates: 2, bookable: false });
  });

  it('T3: «откуда» раньше «куда» по маршруту; «поблизости» — старт в 30 км', async () => {
    const driver = await createUser({ mode: 'driver' });
    const trip = await createTrip({ driverId: driver.id, cityIds: [cityA, cityC, cityB], departsAt: atLocal(1, 15), prices: [
      { fromIdx: 0, toIdx: 1, price: 400 },
      { fromIdx: 1, toIdx: 2, price: 700 },
    ] });
    const passenger = await createUser();
    const http = call(app, passenger.token);

    const forward = await http.get('/trips').query({ fromCityId: cityC, toCityId: cityB });
    expect(forward.status).toBe(200);
    expect((forward.body as { id: string }[]).map((t) => t.id)).toContain(trip);

    const backward = await http.get('/trips').query({ fromCityId: cityB, toCityId: cityA });
    expect(backward.status).toBe(200);
    expect((backward.body as { id: string }[]).map((t) => t.id)).not.toContain(trip);

    const near = await http.get('/trips').query({ near: true, lat: 57.7, lng: 39.9 });
    expect(near.status).toBe(200);
    expect((near.body as { id: string }[]).map((t) => t.id)).toContain(trip);

    const far = await http.get('/trips').query({ near: true, lat: 55.75, lng: 37.62 });
    expect(far.status).toBe(200);
    expect((far.body as { id: string }[]).map((t) => t.id)).not.toContain(trip);
  });

  it('T4: вторая «туда» на ту же дату на то же авто — limit_reached', async () => {
    const driver = await driverWithCar();
    await createTrip({ driverId: driver.id, carId: driver.carId, cityIds: [cityA, cityB], departsAt: atLocal(1, 8) });
    const res = await call(app, driver.token).post('/trips').send(tripBody(driver.carId));
    expect(res.body.code).toBe('limit_reached');
  });

  it('T4: одна обратная в тот же день проходит, вторая — limit_reached', async () => {
    const driver = await driverWithCar();
    const forward = await createTrip({ driverId: driver.id, carId: driver.carId, cityIds: [cityA, cityB], departsAt: atLocal(1, 8) });
    const http = call(app, driver.token);
    const body = { departsAt: isoLocal(atLocal(1, 16)), arrivesAt: isoLocal(atLocal(1, 18)) };
    const first = await http.post(`/trips/${forward}/reverse`).send(body);
    expect(first.status).toBe(201);
    const second = await http.post(`/trips/${forward}/reverse`).send({
      departsAt: isoLocal(atLocal(1, 19)),
      arrivesAt: isoLocal(atLocal(1, 21)),
    });
    expect(second.body.code).toBe('limit_reached');
  });

  it('T4: отменённая поездка в лимит не идёт', async () => {
    const driver = await driverWithCar();
    await createTrip({
      driverId: driver.id,
      carId: driver.carId,
      cityIds: [cityA, cityB],
      departsAt: atLocal(1, 8),
      status: 'cancelled',
    });
    const res = await call(app, driver.token).post('/trips').send(tripBody(driver.carId));
    expect(res.status).toBe(201);
  });

  /** Другие сутки той же календарной недели (пн–вс в `APP_TZ`), что и завтра: смещение от сегодня. */
  function otherDayOfTomorrowsWeek(): number {
    const weekday = new Date(`${dateLocal(atLocal(1, 12))}T12:00:00Z`).getUTCDay();
    const sinceMonday = (weekday + 6) % 7;
    return sinceMonday === 0 ? 2 : 1 - sinceMonday;
  }

  it('T4-неделя: десять неотменённых поездок авто на неделе — одиннадцатая limit_reached с текстом недели', async () => {
    const driver = await driverWithCar();
    const day = otherDayOfTomorrowsWeek();
    for (let k = 0; k < 10; k += 1) {
      await createTrip({ driverId: driver.id, carId: driver.carId, cityIds: [cityA, cityB], departsAt: atLocal(day, 6 + k) });
    }
    const limits = await call(app, driver.token).get('/trips/limits').query({ carId: driver.carId, date: dateLocal(atLocal(1, 12)) });
    expect(limits.body).toMatchObject({ forwardUsed: 0, reverseUsed: 0, weekUsed: 10, weekLimit: 10 });
    const res = await call(app, driver.token).post('/trips').send(tripBody(driver.carId));
    expect(res.body.code).toBe('limit_reached');
    expect(res.body.message).toBe('Достигнут лимит на неделю — следующая публикация с понедельника');
  });

  it('T4-неделя: девять на неделе, отменённые и прошлая неделя — публикация проходит', async () => {
    const driver = await driverWithCar();
    const day = otherDayOfTomorrowsWeek();
    for (let k = 0; k < 9; k += 1) {
      await createTrip({ driverId: driver.id, carId: driver.carId, cityIds: [cityA, cityB], departsAt: atLocal(day, 6 + k) });
    }
    await createTrip({ driverId: driver.id, carId: driver.carId, cityIds: [cityA, cityB], departsAt: atLocal(day, 16), status: 'cancelled' });
    for (let k = 0; k < 10; k += 1) {
      await createTrip({ driverId: driver.id, carId: driver.carId, cityIds: [cityA, cityB], departsAt: atLocal(day - 7, 6 + k) });
    }
    const res = await call(app, driver.token).post('/trips').send(tripBody(driver.carId));
    expect(res.status).toBe(201);
  });

  it('T4-водитель: две машины одного водителя делят суточный лимит', async () => {
    const driver = await driverWithCar();
    const second = await createCar(driver.id);
    await createTrip({ driverId: driver.id, carId: driver.carId, cityIds: [cityA, cityB], departsAt: atLocal(1, 8) });
    const limits = await call(app, driver.token).get('/trips/limits').query({ carId: second, date: dateLocal(atLocal(1, 12)) });
    expect(limits.body).toMatchObject({ forwardUsed: 1, reverseUsed: 0 });
    const res = await call(app, driver.token).post('/trips').send(tripBody(second));
    expect(res.body.code).toBe('limit_reached');
  });

  it('T4-водитель: две машины одного водителя делят недельный лимит', async () => {
    const driver = await driverWithCar();
    const second = await createCar(driver.id);
    const day = otherDayOfTomorrowsWeek();
    for (let k = 0; k < 10; k += 1) {
      await createTrip({ driverId: driver.id, carId: k % 2 ? second : driver.carId, cityIds: [cityA, cityB], departsAt: atLocal(day, 6 + k) });
    }
    const limits = await call(app, driver.token).get('/trips/limits').query({ carId: second, date: dateLocal(atLocal(1, 12)) });
    expect(limits.body).toMatchObject({ weekUsed: 10, weekLimit: 10 });
    const res = await call(app, driver.token).post('/trips').send(tripBody(second));
    expect(res.body.code).toBe('limit_reached');
    expect(res.body.message).toBe('Достигнут лимит на неделю — следующая публикация с понедельника');
  });

  it('T5: поездка дальше чем через 3 дня — too_far_ahead', async () => {
    const driver = await driverWithCar();
    const departsAt = new Date(Date.now() + 3 * DAY + 2 * HOUR);
    departsAt.setUTCMinutes(departsAt.getUTCMinutes() < 30 ? 0 : 30, 0, 0);
    const res = await call(app, driver.token)
      .post('/trips')
      .send(tripBody(driver.carId, { departsAt: isoLocal(departsAt), arrivesAt: isoLocal(new Date(departsAt.getTime() + 2 * HOUR)) }));
    expect(res.body.code).toBe('too_far_ahead');
  });

  it('T5: время не кратно 30 минутам — invalid_time_step', async () => {
    const driver = await driverWithCar();
    const departsAt = atLocal(1, 10, 15);
    const res = await call(app, driver.token)
      .post('/trips')
      .send(tripBody(driver.carId, { departsAt: isoLocal(departsAt), arrivesAt: isoLocal(new Date(departsAt.getTime() + 2 * HOUR)) }));
    expect(res.body.code).toBe('invalid_time_step');
  });

  it('T6: пока никто не присоединился — маршрут, время и цену можно менять', async () => {
    const driver = await driverWithCar();
    const trip = await createTrip({ driverId: driver.id, carId: driver.carId, cityIds: [cityA, cityB], departsAt: atLocal(1, 10) });
    const http = call(app, driver.token);
    const departsAt = atLocal(1, 11);
    const res = await http
      .patch(`/trips/${trip}`)
      .send({ departsAt: isoLocal(departsAt), arrivesAt: isoLocal(new Date(departsAt.getTime() + 2 * HOUR)), priceFull: 1200 });
    expect(res.status).toBe(200);
    expect(res.body.price).toBe(1200);
    expect(new Date(res.body.departsAt as string).getTime()).toBe(departsAt.getTime());
    expect(res.body.editLocked).toBe(false);

    // Маршрут: 2 → 3 остановки с согласованными ценами (старт → промежуточная, промежуточная → финиш).
    const route = await http.patch(`/trips/${trip}`).send({
      stops: [
        { cityId: cityA, address: 'Автовокзал' },
        { cityId: cityC, address: 'Остановка' },
        { cityId: cityB, address: 'Вокзал' },
      ],
      prices: [
        { fromIdx: 0, toIdx: 1, price: 500 },
        { fromIdx: 1, toIdx: 2, price: 800 },
      ],
    });
    expect(route.status).toBe(200);
    expect((route.body.stops as { cityId: number }[]).map((s) => s.cityId)).toEqual([cityA, cityC, cityB]);
    expect(route.body.stopsCount).toBe(1);
  });

  it('T6: после первой подтверждённой брони — edit_locked', async () => {
    const driver = await driverWithCar();
    const trip = await createTrip({ driverId: driver.id, carId: driver.carId, cityIds: [cityA, cityB], departsAt: atLocal(1, 10) });
    const passenger = await createUser();
    await createBooking({ tripId: trip, passengerId: passenger.id, status: 'awaiting_payment', toIdx: 1 });
    const res = await call(app, driver.token).patch(`/trips/${trip}`).send({ priceFull: 1200 });
    expect(res.body.code).toBe('edit_locked');
  });

  it('T7: число мест нельзя сделать меньше занятых', async () => {
    const driver = await driverWithCar();
    const trip = await createTrip({ driverId: driver.id, carId: driver.carId, cityIds: [cityA, cityB], departsAt: atLocal(1, 10), seatsTotal: 3, seatsTaken: 2 });
    await createBooking({ tripId: trip, passengerId: (await createUser()).id, status: 'paid', toIdx: 1, seats: 2 });
    const http = call(app, driver.token);
    const below = await http.post(`/trips/${trip}/seats`).send({ seatsTotal: 1 });
    expect(below.body.code).toBe('seats_below_taken');
    const equal = await http.post(`/trips/${trip}/seats`).send({ seatsTotal: 2 });
    expect(equal.status).toBe(200);
    expect(equal.body.seatsTotal).toBe(2);
    expect(equal.body.seatsFree).toBe(0);
  });

  it('T8: обратная — те же остановки в обратном порядке, новое время, ссылка на исходную', async () => {
    const driver = await driverWithCar();
    const forward = await createTrip({
      driverId: driver.id,
      carId: driver.carId,
      cityIds: [cityA, cityC, cityB],
      departsAt: atLocal(1, 9),
      prices: [
        { fromIdx: 0, toIdx: 1, price: 400 },
        { fromIdx: 1, toIdx: 2, price: 700 },
      ],
    });
    const departsAt = atLocal(1, 17);
    const res = await call(app, driver.token)
      .post(`/trips/${forward}/reverse`)
      .send({ departsAt: isoLocal(departsAt), arrivesAt: isoLocal(new Date(departsAt.getTime() + 2 * HOUR)) });
    expect(res.status).toBe(201);
    expect(res.body.id).not.toBe(forward);
    expect(res.body.reverseOf).toBe(forward);
    expect((res.body.stops as { cityId: number }[]).map((s) => s.cityId)).toEqual([cityB, cityC, cityA]);
    expect(new Date(res.body.departsAt as string).getTime()).toBe(departsAt.getTime());
  });

  it('T9: отмена с присоединившимся — в счёт 2/30, вторая такая отмена блокирует публикацию', async () => {
    const driver = await driverWithCar();
    const http = call(app, driver.token);
    const withPassenger = async (hours: number): Promise<string> => {
      const trip = await createTrip({ driverId: driver.id, cityIds: [cityA, cityB], departsAt: atLocal(2, hours) });
      await createBooking({ tripId: trip, passengerId: (await createUser()).id, status: 'awaiting_payment', toIdx: 1 });
      return trip;
    };

    const first = await http.post(`/trips/${await withPassenger(9)}/cancel`);
    expect(first.status).toBe(200);
    expect(first.body.status).toBe('cancelled');
    expect(first.body.cancellationsLast30).toBe(1);
    expect(first.body.blockedUntil ?? null).toBeNull();

    const second = await http.post(`/trips/${await withPassenger(12)}/cancel`);
    expect(second.status).toBe(200);
    expect(second.body.cancellationsLast30).toBe(2);
    expect(second.body.blockedUntil).toBeTruthy();
    expect(await db.$count(blocks, eq(blocks.userId, driver.id))).toBe(1);

    const publish = await http.post('/trips').send(tripBody(driver.carId));
    expect(publish.status).toBe(403);
    expect(publish.body.code).toBe('blocked');
  });

  it('T9: отмена без пассажиров — без последствий', async () => {
    const driver = await driverWithCar();
    const trip = await createTrip({ driverId: driver.id, cityIds: [cityA, cityB], departsAt: atLocal(2, 9) });
    const res = await call(app, driver.token).post(`/trips/${trip}/cancel`);
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('cancelled');
    expect(res.body.cancellationsLast30).toBe(0);
    expect(res.body.blockedUntil ?? null).toBeNull();
  });

  it('T10: заблокированный водитель не может опубликовать поездку (403 blocked)', async () => {
    const driver = await createUser({ mode: 'driver', blockedUntil: new Date(Date.now() + 10 * DAY) });
    const carId = await createCar(driver.id);
    const res = await call(app, driver.token).post('/trips').send(tripBody(carId));
    expect(res.status).toBe(403);
    expect(res.body.code).toBe('blocked');
    expect(res.body.blockedUntil).toBeTruthy();
  });

  it('T11: цены по участкам — ровно пары соседних точек; весь маршрут от самого дорогого участка до суммы', async () => {
    const stops = [cityA, cityC, cityD, cityE, cityB].map((cityId) => ({ cityId, address: 'Остановка' }));
    // Участки 300 + 400 + 700 + 500 = 1900, самый дорогой — Промежуток2 → Промежуток3 (700).
    const legs = [
      { fromIdx: 0, toIdx: 1, price: 300 },
      { fromIdx: 1, toIdx: 2, price: 400 },
      { fromIdx: 2, toIdx: 3, price: 700 },
      { fromIdx: 3, toIdx: 4, price: 500 },
    ];
    const ok = await driverWithCar();
    const accepted = await call(app, ok.token).post('/trips').send(tripBody(ok.carId, { stops, prices: legs, priceFull: 1500 }));
    expect(accepted.status).toBe(201);
    expect(accepted.body.stopsCount).toBe(3);

    const bad = await driverWithCar();
    const post = (overrides: Record<string, unknown>) => call(app, bad.token).post('/trips').send(tripBody(bad.carId, { stops, prices: legs, priceFull: 1500, ...overrides }));

    // Пара не соседних точек (старый вид «старт → остановка») — лишняя.
    expect((await post({ prices: [...legs, { fromIdx: 0, toIdx: 2, price: 600 }] })).body.code).toBe('validation');
    // Участка не хватает.
    expect((await post({ prices: legs.filter((p) => p.fromIdx !== 2) })).body.code).toBe('validation');

    // Весь маршрут дешевле самого дорогого участка — отказ с понятным текстом.
    const cheap = await post({ priceFull: 600 });
    expect(cheap.body.code).toBe('validation');
    // Имена городов проверок — с суффиксом прогона (`createCity`).
    expect(cheap.body.message).toMatch(/^Весь маршрут не может стоить меньше участка Промежуток2\S* → Промежуток3\S* \(700 ₽\): пассажир всего маршрута тоже едет через эту точку$/);
    // Весь маршрут дороже суммы участков — отказ.
    expect((await post({ priceFull: 1901 })).body.code).toBe('validation');
    // Участок дешевле стоимости посадки — отказ.
    expect((await post({ priceBoardingMin: 350 })).body.code).toBe('validation');
    // Любая цена — не больше 100 000 ₽.
    const twoStops = [stops[0], stops[4]];
    expect((await post({ stops: twoStops, prices: [], priceFull: 100_001 })).body.code).toBe('validation');
    expect((await post({ stops: twoStops, prices: [], priceFull: 100_000, priceBoardingMin: 100_001 })).body.code).toBe('validation');
    const edge = await driverWithCar();
    const atEdge = await call(app, edge.token).post('/trips').send(tripBody(edge.carId, { stops: twoStops, prices: [], priceFull: 100_000 }));
    expect(atEdge.status).toBe(201);
  });

  it('T11: весь маршрут ровно как самый дорогой участок и ровно как сумма участков — можно', async () => {
    const stops = [cityA, cityC, cityB].map((cityId) => ({ cityId, address: 'Остановка' }));
    const legs = [
      { fromIdx: 0, toIdx: 1, price: 400 },
      { fromIdx: 1, toIdx: 2, price: 700 },
    ];
    const atMax = await driverWithCar();
    expect((await call(app, atMax.token).post('/trips').send(tripBody(atMax.carId, { stops, prices: legs, priceFull: 700 }))).status).toBe(201);
    const atSum = await driverWithCar();
    expect((await call(app, atSum.token).post('/trips').send(tripBody(atSum.carId, { stops, prices: legs, priceFull: 1100 }))).status).toBe(201);
  });
});
