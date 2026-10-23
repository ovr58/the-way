/**
 * I.4, PN-2: короткий адрес остановки («<улица>, <дом>») — для карточки поездки; полный — для
 * деталей. Короткий приходит из подсказки (`GeoSuggestion.shortLabel`, собирает сервер), без него —
 * тот же текст, что полный (seed, свободная строка).
 */
import type { INestApplication } from '@nestjs/common';
import { call, createTestApp } from '../../../../test/helpers/app';
import { atLocal, HOUR, isoLocal } from '../../../../test/helpers/dates';
import { closeDb, createCar, createCity, createUser } from '../../../../test/helpers/db';

const FULL = 'Россия, Ярославская область, Ярославль, Фрунзенский, 150001, Портовая набережная 10';
const SHORT = 'Портовая набережная, 10';

let app: INestApplication;
let cityA: number;

beforeAll(async () => {
  app = await createTestApp();
  cityA = await createCity('КорА', 57.6, 39.8);
});

afterAll(async () => {
  await app.close();
  await closeDb();
});

function stops(name: string): Record<string, unknown>[] {
  return [
    { place: { name, region: 'Тестовая область' }, address: FULL, shortAddress: SHORT, lat: 52.1, lng: 21.2 },
    { cityId: cityA, address: 'Вокзал' },
  ];
}

function body(carId: string, name: string): Record<string, unknown> {
  const departsAt = atLocal(1, 10);
  return {
    kind: 'ride',
    vehicleKind: 'car',
    stops: stops(name),
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

describe('короткий адрес остановки (PN-2)', () => {
  it('карточка: короткий из подсказки; без него — тот же текст; детали — полный', async () => {
    const u = await createUser({ mode: 'driver' });
    const carId = await createCar(u.id);
    const created = await call(app, u.token).post('/trips').send(body(carId, `Корот${Date.now()}`));
    expect(created.status).toBe(201);
    expect(created.body.from).toMatchObject({ address: FULL, shortAddress: SHORT });
    expect(created.body.to).toMatchObject({ address: 'Вокзал', shortAddress: 'Вокзал' });

    const details = await call(app, u.token).get(`/trips/${created.body.id}`);
    expect(details.body.stops[0]).toMatchObject({ address: FULL, shortAddress: SHORT });

    const reverse = await call(app, u.token)
      .post(`/trips/${created.body.id}/reverse`)
      .send({ departsAt: isoLocal(atLocal(2, 10)), arrivesAt: isoLocal(atLocal(2, 12)) });
    expect(reverse.status).toBe(201);
    expect(reverse.body.stops.at(-1)).toMatchObject({ address: FULL, shortAddress: SHORT });
  });

  it('шаблон маршрута хранит короткий адрес', async () => {
    const u = await createUser({ mode: 'driver' });
    const created = await call(app, u.token).post('/route-templates').send({ stops: stops(`Шабл${Date.now()}`) });
    expect(created.status).toBe(201);
    expect(created.body.stops).toMatchObject([
      { address: FULL, shortAddress: SHORT },
      { address: 'Вокзал', shortAddress: 'Вокзал' },
    ]);
  });
});
