/** Детали поездки (`GET /trips/{id}`): поля сверх карточки — остановки, цены, услуги, авто, флаги зрителя. */
import type { INestApplication } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { atLocal } from '../../../../test/helpers/dates';
import { call, createTestApp } from '../../../../test/helpers/app';
import { closeDb, createBooking, createCar, createCity, createTrip, createUser } from '../../../../test/helpers/db';

let app: INestApplication;
let cityA: number;
let cityB: number;
let cityC: number;

beforeAll(async () => {
  app = await createTestApp();
  cityA = await createCity('ДетА', 57.6, 39.8);
  cityB = await createCity('ДетБ', 58.0, 38.8);
  cityC = await createCity('ДетВ', 57.8, 39.3);
});

afterAll(async () => {
  await app.close();
  await closeDb();
});

describe('Детали поездки', () => {
  it('чужой зритель: остановки, цены, услуги, авто; без paidTotal, не заблокировано, без своей брони', async () => {
    const driver = await createUser({ mode: 'driver' });
    const carId = await createCar(driver.id);
    const trip = await createTrip({
      driverId: driver.id,
      carId,
      cityIds: [cityA, cityC, cityB],
      departsAt: atLocal(1, 10),
      prices: [
        { fromIdx: 0, toIdx: 1, price: 400 },
        { fromIdx: 1, toIdx: 2, price: 700 },
      ],
      extras: [
        { kind: 'luggage', price: 150 },
        { kind: 'parcel_s', price: 150 },
      ],
      parcelSeatsTotal: 3,
    });
    const viewer = await createUser();
    const res = await call(app, viewer.token).get(`/trips/${trip}`);
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      id: trip,
      isMine: false,
      editLocked: false,
      myBooking: null,
      paidTotal: null,
      stopsCount: 1,
      priceBoardingMin: 100,
      bookingMode: 'standard',
      parcelSizes: ['S'],
      car: { id: carId, plate: 'А000АА76', documents: [] },
    });
    expect((res.body.stops as { idx: number; cityId: number }[]).map((s) => s.cityId)).toEqual([cityA, cityC, cityB]);
    expect(res.body.prices).toEqual([
      { fromIdx: 0, toIdx: 1, price: 400 },
      { fromIdx: 1, toIdx: 2, price: 700 },
    ]);
    expect(res.body.extrasPriced).toEqual(expect.arrayContaining([{ kind: 'luggage', price: 150 }, { kind: 'parcel_s', price: 150 }]));
  });

  it('водитель: paidTotal — сумма оплаченных броней, editLocked при присоединившемся', async () => {
    const driver = await createUser({ mode: 'driver' });
    const trip = await createTrip({ driverId: driver.id, cityIds: [cityA, cityB], departsAt: atLocal(1, 11) });
    await createBooking({ tripId: trip, passengerId: (await createUser()).id, status: 'paid', toIdx: 1, priceTotal: 1000 });
    await createBooking({ tripId: trip, passengerId: (await createUser()).id, status: 'paid', toIdx: 1, priceTotal: 500 });
    await createBooking({ tripId: trip, passengerId: (await createUser()).id, status: 'requested', toIdx: 1, priceTotal: 300 });
    const res = await call(app, driver.token).get(`/trips/${trip}`);
    expect(res.body).toMatchObject({ isMine: true, paidTotal: 1500, editLocked: true });
  });

  it('пассажир с бронью: myBooking — его активная бронь', async () => {
    const driver = await createUser({ mode: 'driver' });
    const trip = await createTrip({ driverId: driver.id, cityIds: [cityA, cityB], departsAt: atLocal(1, 12) });
    const passenger = await createUser();
    const bookingId = await createBooking({ tripId: trip, passengerId: passenger.id, status: 'requested', toIdx: 1 });
    const res = await call(app, passenger.token).get(`/trips/${trip}`);
    expect(res.body.myBooking).toMatchObject({ id: bookingId, status: 'requested' });
    expect(res.body.bookable).toBe(false);
    expect(res.body.paidTotal).toBeNull();
  });

  it('нет такой поездки — 404 not_found', async () => {
    const res = await call(app, (await createUser()).token).get(`/trips/${randomUUID()}`);
    expect(res.status).toBe(404);
    expect(res.body.code).toBe('not_found');
  });
});
