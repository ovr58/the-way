/**
 * Сквозной сценарий через HTTP: вход двумя
 * номерами кодом 111111 → водитель добавляет авто и публикует поездку → пассажир находит её в ленте →
 * бронирует → водитель подтверждает → пассажир оплачивает → бронь в активных у пассажира и поездка с
 * `paid = 1` у водителя. Фикстуры — только города справочника.
 */
import type { INestApplication } from '@nestjs/common';
import { call, createTestApp } from '../helpers/app';
import { closeDb, createCity, randomPhone } from '../helpers/db';
import { HOUR, atLocal, isoLocal } from '../helpers/dates';

let app: INestApplication;

beforeAll(async () => {
  app = await createTestApp();
});

afterAll(async () => {
  await app.close();
  await closeDb();
});

async function signIn(): Promise<string> {
  const phone = randomPhone();
  const sent = await call(app).post('/auth/request-code').send({ phone });
  expect(sent.status).toBe(200);
  const res = await call(app).post('/auth/verify').send({ phone, code: '111111' });
  expect(res.status).toBe(200);
  return res.body.token as string;
}

it('водитель публикует → пассажир бронирует → подтверждение → оплачено', async () => {
  const from = await createCity('Ярославль', 57.6261, 39.8845);
  const to = await createCity('Рыбинск', 58.0485, 38.8584);
  const driver = call(app, await signIn());
  const passenger = call(app, await signIn());

  const car = await driver.post('/cars').send({ brand: 'Kia', model: 'Rio', kind: 'car', seats: 4, plate: 'Е333ЕЕ76' });
  expect(car.status).toBe(201);

  const departsAt = atLocal(1, 10);
  const published = await driver.post('/trips').send({
    kind: 'ride',
    vehicleKind: 'car',
    stops: [
      { cityId: from, address: 'Автовокзал' },
      { cityId: to, address: 'Вокзал' },
    ],
    departsAt: isoLocal(departsAt),
    arrivesAt: isoLocal(new Date(departsAt.getTime() + 2 * HOUR)),
    seatsTotal: 3,
    priceFull: 600,
    prices: [],
    priceBoardingMin: 200,
    carId: car.body.id,
    extras: [],
    parcelOnlyAllowed: false,
    parcelSeatsTotal: 0,
    bookingMode: 'standard',
  });
  expect(published.status).toBe(201);
  const tripId = published.body.id as string;

  const feed = await passenger.get('/trips').query({ fromCityId: from, toCityId: to });
  expect(feed.status).toBe(200);
  const card = (feed.body as { id: string; bookable: boolean }[]).find((t) => t.id === tripId);
  expect(card).toMatchObject({ bookable: true });

  const booked = await passenger
    .post(`/trips/${tripId}/bookings`)
    .send({ fromIdx: 0, toIdx: 1, seats: 1, parcelSize: 'none', parcelOnly: false, extras: [] });
  expect(booked.status).toBe(201);
  expect(booked.body.status).toBe('requested');
  const bookingId = booked.body.id as string;

  const confirmed = await driver.post(`/bookings/${bookingId}/confirm`);
  expect(confirmed.status).toBe(200);
  expect(confirmed.body.status).toBe('awaiting_payment');

  const paid = await passenger.post(`/bookings/${bookingId}/pay`);
  expect(paid.status).toBe(200);
  expect(paid.body.status).toBe('paid');

  const mine = await passenger.get('/bookings/mine').query({ status: 'active' });
  expect(mine.status).toBe(200);
  expect(mine.body).toEqual(expect.arrayContaining([expect.objectContaining({ id: bookingId, status: 'paid' })]));

  const driverTrips = await driver.get('/trips/mine').query({ status: 'active' });
  expect(driverTrips.status).toBe(200);
  expect(driverTrips.body).toEqual(expect.arrayContaining([expect.objectContaining({ id: tripId, paid: 1 })]));
});
