/** Публикация, обратная, лимиты и шаблоны сверх замороженных T4/T5/T8/T11: границы правил цены и точек. */
import type { INestApplication } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { randomUUID } from 'node:crypto';
import { call, createTestApp } from '../../../../test/helpers/app';
import { atLocal, dateLocal, HOUR, isoLocal } from '../../../../test/helpers/dates';
import { closeDb, createCar, createCity, createTrip, createUser, db } from '../../../../test/helpers/db';
import { cities } from '../../cities/internal/schema';

let app: INestApplication;
let cityA: number;
let cityB: number;
let cityC: number;

beforeAll(async () => {
  app = await createTestApp();
  cityA = await createCity('СозА', 57.6, 39.8);
  cityB = await createCity('СозБ', 58.0, 38.8);
  cityC = await createCity('СозВ', 57.8, 39.3);
});

afterAll(async () => {
  await app.close();
  await closeDb();
});

function body(carId: string, overrides: Record<string, unknown> = {}): Record<string, unknown> {
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

async function driver(): Promise<{ token: string; id: string; carId: string }> {
  const u = await createUser({ mode: 'driver' });
  return { ...u, carId: await createCar(u.id) };
}

describe('POST /trips: границы правил', () => {
  it('точка из подсказки Mapbox: город добавляется в справочник и становится остановкой', async () => {
    const d = await driver();
    const name = `Село${Date.now()}`;
    const res = await call(app, d.token)
      .post('/trips')
      .send(
        body(d.carId, {
          stops: [
            { cityId: cityA, address: 'Автовокзал' },
            { place: { name, region: 'Тестовая область' }, address: 'Центр', lat: 52.1, lng: 21.2 },
          ],
        }),
      );
    expect(res.status).toBe(201);
    const [row] = await db.select().from(cities).where(eq(cities.name, name));
    expect(row).toMatchObject({ source: 'mapbox', lat: 52.1, lng: 21.2 });
    expect(res.body.to).toMatchObject({ cityId: row.id, cityName: name, lat: 52.1 });
  });

  it('чужое авто — car_invalid', async () => {
    const d = await driver();
    const other = await driver();
    const res = await call(app, d.token).post('/trips').send(body(other.carId));
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('car_invalid');
  });

  it('мест больше, чем в авто — validation', async () => {
    const d = await driver();
    const res = await call(app, d.token).post('/trips').send(body(d.carId, { seatsTotal: 5 }));
    expect(res.body.code).toBe('validation');
  });

  it('цена отрезка ниже стоимости посадки — validation', async () => {
    const d = await driver();
    const res = await call(app, d.token)
      .post('/trips')
      .send(
        body(d.carId, {
          stops: [cityA, cityC, cityB].map((cityId) => ({ cityId, address: 'Остановка' })),
          prices: [
            { fromIdx: 0, toIdx: 1, price: 50 },
            { fromIdx: 1, toIdx: 2, price: 700 },
          ],
        }),
      );
    expect(res.body.code).toBe('validation');
  });

  it('участок не между соседними точками вместо соседнего — validation', async () => {
    const d = await driver();
    const res = await call(app, d.token)
      .post('/trips')
      .send(
        body(d.carId, {
          stops: [cityA, cityC, cityB].map((cityId) => ({ cityId, address: 'Остановка' })),
          prices: [
            { fromIdx: 0, toIdx: 2, price: 500 },
            { fromIdx: 1, toIdx: 2, price: 700 },
          ],
        }),
      );
    expect(res.body.code).toBe('validation');
  });

  it('прибытие на следующий день — можно, в пути не больше 24 часов', async () => {
    const departsAt = atLocal(1, 8);
    const at = (hours: number) => ({ departsAt: isoLocal(departsAt), arrivesAt: isoLocal(new Date(departsAt.getTime() + hours * HOUR)) });
    const ok = await driver();
    expect((await call(app, ok.token).post('/trips').send(body(ok.carId, at(24)))).status).toBe(201);
    const late = await driver();
    const res = await call(app, late.token).post('/trips').send(body(late.carId, at(24.5)));
    expect(res.body.code).toBe('validation');
    expect(res.body.message).toBe('В пути — не больше 24 часов');
  });

  it('числа в текстах ошибок цен — с пробелами-разрядами', async () => {
    const d = await driver();
    const res = await call(app, d.token).post('/trips').send(body(d.carId, { priceFull: 100_001 }));
    expect(res.body.message).toBe('Цена не может быть больше 100 000 ₽');
  });

  it('посылка: без мест пассажиров, с размером и местами для посылок; без размера — validation', async () => {
    const d = await driver();
    const ok = await call(app, d.token)
      .post('/trips')
      .send(body(d.carId, { kind: 'parcel', seatsTotal: 0, extras: [{ kind: 'parcel_s', price: 150 }], parcelSeatsTotal: 2 }));
    expect(ok.status).toBe(201);
    expect(ok.body).toMatchObject({ kind: 'parcel', parcelSizes: ['S'], parcelSeatsTotal: 2, parcelSeatsFree: 2 });

    const noSize = await driver();
    const bad = await call(app, noSize.token).post('/trips').send(body(noSize.carId, { kind: 'parcel', seatsTotal: 0 }));
    expect(bad.body.code).toBe('validation');
  });

  it('отправление в прошлом — validation', async () => {
    const d = await driver();
    const past = atLocal(0, 0);
    const res = await call(app, d.token)
      .post('/trips')
      .send(body(d.carId, { departsAt: isoLocal(past), arrivesAt: isoLocal(new Date(past.getTime() + HOUR)) }));
    expect(res.body.code).toBe('validation');
  });
});

describe('GET /trips/limits, обратная, шаблоны', () => {
  it('limits: считает «туда» и «обратно» на авто за сутки, отменённые не считает', async () => {
    const d = await driver();
    const forward = await createTrip({ driverId: d.id, carId: d.carId, cityIds: [cityA, cityB], departsAt: atLocal(1, 8) });
    await createTrip({ driverId: d.id, carId: d.carId, cityIds: [cityB, cityA], departsAt: atLocal(1, 14), reverseOf: forward });
    await createTrip({ driverId: d.id, carId: d.carId, cityIds: [cityA, cityB], departsAt: atLocal(1, 18), status: 'cancelled' });
    const res = await call(app, d.token).get('/trips/limits').query({ carId: d.carId, date: dateLocal(atLocal(1, 12)) });
    expect(res.status).toBe(200);
    // Неделя: обе поездки этих суток — в счёт недели.
    expect(res.body).toEqual({ forwardUsed: 1, reverseUsed: 1, weekUsed: 2, weekLimit: 10, maxDaysAhead: 3 });
    const empty = await call(app, d.token).get('/trips/limits').query({ carId: d.carId, date: dateLocal(atLocal(2, 12)) });
    // Другие сутки: суточный счёт пуст; неделя может быть та же или следующая — её здесь не сверяем.
    expect(empty.body).toMatchObject({ forwardUsed: 0, reverseUsed: 0, weekLimit: 10, maxDaysAhead: 3 });
  });

  it('обратная: цены переиндексированы (i, j) → (n−1−j, n−1−i); чужую поездку — 403', async () => {
    const d = await driver();
    const forward = await createTrip({
      driverId: d.id,
      carId: d.carId,
      cityIds: [cityA, cityC, cityB],
      departsAt: atLocal(1, 9),
      priceFull: 1000,
      prices: [
        { fromIdx: 0, toIdx: 1, price: 400 },
        { fromIdx: 1, toIdx: 2, price: 700 },
      ],
    });
    const at = atLocal(1, 17);
    const payload = { departsAt: isoLocal(at), arrivesAt: isoLocal(new Date(at.getTime() + 2 * HOUR)) };
    const res = await call(app, d.token).post(`/trips/${forward}/reverse`).send(payload);
    expect(res.status).toBe(201);
    expect(res.body.prices).toEqual([
      { fromIdx: 0, toIdx: 1, price: 700 },
      { fromIdx: 1, toIdx: 2, price: 400 },
    ]);
    expect(res.body.price).toBe(1000);

    const stranger = await createUser({ mode: 'driver' });
    const denied = await call(app, stranger.token).post(`/trips/${forward}/reverse`).send(payload);
    expect(denied.status).toBe(403);
    expect(denied.body.code).toBe('forbidden');
    const missing = await call(app, d.token).post(`/trips/${randomUUID()}/reverse`).send(payload);
    expect(missing.body.code).toBe('not_found');
  });

  it('шаблоны: создать (город и подсказка), список только свой, удалить; чужой — 404', async () => {
    const owner = await createUser({ mode: 'driver' });
    const name = `Деревня${Date.now()}`;
    const created = await call(app, owner.token)
      .post('/route-templates')
      .send({
        stops: [
          { cityId: cityA, address: 'Автовокзал' },
          { place: { name, region: 'Тестовая область' }, address: 'Центр', lat: 50.5, lng: 20.5 },
        ],
      });
    expect(created.status).toBe(201);
    expect(created.body.stops).toMatchObject([
      { idx: 0, cityId: cityA, address: 'Автовокзал' },
      { idx: 1, cityName: name, lat: 50.5, lng: 20.5 },
    ]);

    const list = await call(app, owner.token).get('/route-templates');
    expect((list.body as { id: string }[]).map((t) => t.id)).toEqual([created.body.id]);
    const other = await createUser();
    expect((await call(app, other.token).get('/route-templates')).body).toEqual([]);

    const foreign = await call(app, other.token).delete(`/route-templates/${created.body.id}`);
    expect(foreign.status).toBe(404);
    const removed = await call(app, owner.token).delete(`/route-templates/${created.body.id}`);
    expect(removed.status).toBe(204);
    expect((await call(app, owner.token).get('/route-templates')).body).toEqual([]);
  });

  it('шаблон: оба — и cityId, и place — validation', async () => {
    const owner = await createUser({ mode: 'driver' });
    const res = await call(app, owner.token)
      .post('/route-templates')
      .send({
        stops: [
          { cityId: cityA, place: { name: 'Х', region: 'Y' }, address: 'a', lat: 1, lng: 1 },
          { cityId: cityB, address: 'b' },
        ],
      });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('validation');
  });
});
