/**
 * Проверки правил авто (V1–V3): госномер уникален у владельца («Транспортные средства»), у «Легкового» 1–8 мест; у автобуса 9–60 мест, тип поездки — по
 * авто. Меняются только отдельным коммитом.
 */
import type { INestApplication } from '@nestjs/common';
import { call, createTestApp } from '../helpers/app';
import { closeDb, createCity, createUser } from '../helpers/db';
import { atLocal, isoLocal } from '../helpers/dates';

let app: INestApplication;

beforeAll(async () => {
  app = await createTestApp();
});

afterAll(async () => {
  await app.close();
  await closeDb();
});

function carBody(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return { brand: 'Toyota', model: 'Camry', kind: 'car', seats: 4, plate: 'А123ВС76', ...overrides };
}

describe('Авто', () => {
  it('V1: госномер уникален у владельца без учёта регистра, пробелов, дефисов и кириллицы/латиницы; у другого — можно; после удаления — можно; правка на занятый — отказ', async () => {
    const owner = await createUser({ mode: 'driver' });
    const http = call(app, owner.token);

    const first = await http.post('/cars').send(carBody());
    expect(first.status).toBe(201);

    const spaced = await http.post('/cars').send(carBody({ plate: 'а 123 вс-76' }));
    expect(spaced.status).toBe(409);
    expect(spaced.body.code).toBe('car_plate_taken');

    const latin = await http.post('/cars').send(carBody({ plate: 'A123BC76' }));
    expect(latin.status).toBe(409);
    expect(latin.body.code).toBe('car_plate_taken');

    const neighbour = await createUser({ mode: 'driver' });
    const theirs = await call(app, neighbour.token).post('/cars').send(carBody());
    expect(theirs.status).toBe(201);

    expect((await http.delete(`/cars/${first.body.id}`)).status).toBe(204);
    const again = await http.post('/cars').send(carBody());
    expect(again.status).toBe(201);

    const second = await http.post('/cars').send(carBody({ plate: 'В222ВВ76' }));
    expect(second.status).toBe(201);
    const renamed = await http.patch(`/cars/${second.body.id}`).send({ plate: 'а123вс76' });
    expect(renamed.status).toBe(409);
    expect(renamed.body.code).toBe('car_plate_taken');
  });

  it('V2: легковое на 9 мест — car_seats_out_of_range; на 8 — можно; правка легкового до 9 — отказ; автобус на 20 — можно', async () => {
    const owner = await createUser({ mode: 'driver' });
    const http = call(app, owner.token);

    const nine = await http.post('/cars').send(carBody({ seats: 9, plate: 'Е901ЕЕ76' }));
    expect(nine.status).toBe(400);
    expect(nine.body.code).toBe('car_seats_out_of_range');

    const eight = await http.post('/cars').send(carBody({ seats: 8, plate: 'Е908ЕЕ76' }));
    expect(eight.status).toBe(201);

    const grown = await http.patch(`/cars/${eight.body.id}`).send({ seats: 9 });
    expect(grown.status).toBe(400);
    expect(grown.body.code).toBe('car_seats_out_of_range');

    const bus = await http.post('/cars').send(carBody({ kind: 'bus', seats: 20, plate: 'Е920ЕЕ76' }));
    expect(bus.status).toBe(201);
  });

  it('V3: автобус на 24 места публикует поездку, тип поездки — по авто, она находится поиском с vehicleKind=bus; автобус на 8 или 61 место — car_seats_out_of_range', async () => {
    const driver = await createUser({ mode: 'driver' });
    const http = call(app, driver.token);

    const eight = await http.post('/cars').send(carBody({ kind: 'bus', seats: 8, plate: 'Р808РР76' }));
    expect(eight.status).toBe(400);
    expect(eight.body.code).toBe('car_seats_out_of_range');
    const sixtyOne = await http.post('/cars').send(carBody({ kind: 'bus', seats: 61, plate: 'Р861РР76' }));
    expect(sixtyOne.status).toBe(400);
    expect(sixtyOne.body.code).toBe('car_seats_out_of_range');

    const bus = await http.post('/cars').send(carBody({ kind: 'bus', brand: 'Ford', model: 'Transit', seats: 24, plate: 'Р824РР76' }));
    expect(bus.status).toBe(201);

    const from = await createCity('Авто-откуда', 57.6261, 39.8845);
    const to = await createCity('Авто-куда', 58.0485, 38.8584);
    const res = await http.post('/trips').send({
      kind: 'ride',
      vehicleKind: 'car',
      stops: [
        { cityId: from, address: 'Остановка 0' },
        { cityId: to, address: 'Остановка 1' },
      ],
      departsAt: isoLocal(atLocal(1, 9)),
      arrivesAt: isoLocal(atLocal(1, 11)),
      seatsTotal: 20,
      priceFull: 900,
      prices: [],
      priceBoardingMin: 100,
      carId: bus.body.id,
      extras: [],
      parcelOnlyAllowed: false,
      parcelSeatsTotal: 0,
      bookingMode: 'standard',
    });
    expect(res.status).toBe(201);

    const passenger = await createUser();
    const search = call(app, passenger.token);
    const buses = await search.get(`/trips?vehicleKind=bus&fromCityId=${from}`);
    expect(buses.status).toBe(200);
    expect(buses.body.map((t: { id: string }) => t.id)).toContain(res.body.id);
    const cars = await search.get(`/trips?fromCityId=${from}`);
    expect(cars.body.map((t: { id: string }) => t.id)).not.toContain(res.body.id);
  });
});
