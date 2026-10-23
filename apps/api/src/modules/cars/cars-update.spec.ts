/** Кадры «Транспортные средства»: `PATCH /cars/{id}` — правка авто водителя (интеграционный, `DATABASE_URL`). */
import type { INestApplication } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { createTestApp, call } from '../../../test/helpers/app';
import { closeDb, createCar, createUser, db } from '../../../test/helpers/db';
import { files } from '../files/internal/schema';
import { cars } from './internal/schema';

let app: INestApplication;

beforeAll(async () => {
  app = await createTestApp();
});

afterAll(async () => {
  await app.close();
  await closeDb();
});

async function fileOf(ownerId: string): Promise<string> {
  const [row] = await db.insert(files).values({ ownerId, mime: 'image/png', path: 'x/y.png', size: 1 }).returning({ id: files.id });
  return row.id;
}

describe('PATCH /cars/{id}', () => {
  it('полное тело → 200, Car с новыми полями и статусом verified; в базе то же', async () => {
    const owner = await createUser({ mode: 'driver' });
    const carId = await createCar(owner.id);
    await db.update(cars).set({ status: 'pending' }).where(eq(cars.id, carId));
    const photo = await fileOf(owner.id);
    const next = { brand: 'Kia', model: 'Rio', kind: 'car', seats: 3, plate: 'А111АА76', photoFileId: photo };
    const res = await call(app, owner.token).patch(`/cars/${carId}`).send(next);
    expect(res.status).toBe(200);
    const { photoFileId: _photo, ...fields } = next;
    expect(res.body).toMatchObject({ id: carId, ...fields, status: 'verified', photoUrl: `/files/${photo}` });
    const [row] = await db.select().from(cars).where(eq(cars.id, carId));
    expect(row).toMatchObject({ brand: 'Kia', model: 'Rio', seats: 3, plate: 'А111АА76', photoFileId: photo, status: 'verified' });
  });

  it('частичное тело меняет только названные поля', async () => {
    const owner = await createUser();
    const carId = await createCar(owner.id);
    const [before] = await db.select().from(cars).where(eq(cars.id, carId));
    const res = await call(app, owner.token).patch(`/cars/${carId}`).send({ seats: 2 });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ brand: before.brand, model: before.model, plate: before.plate, seats: 2 });
  });

  it('photoFileId: null не трогает фото — как у PATCH /me (клиент шлёт все поля)', async () => {
    const owner = await createUser();
    const carId = await createCar(owner.id);
    const photo = await fileOf(owner.id);
    await db.update(cars).set({ photoFileId: photo }).where(eq(cars.id, carId));
    const res = await call(app, owner.token).patch(`/cars/${carId}`).send({ plate: 'В222ВВ76', photoFileId: null });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ plate: 'В222ВВ76', photoUrl: `/files/${photo}` });
  });

  it('проверки тела как у POST /cars: seats 0 и пустая марка → 400 validation', async () => {
    const owner = await createUser();
    const carId = await createCar(owner.id);
    for (const bad of [{ seats: 0 }, { brand: '' }, { kind: 'plane' }]) {
      const res = await call(app, owner.token).patch(`/cars/${carId}`).send(bad);
      expect(res.status).toBe(400);
      expect(res.body.code).toBe('validation');
    }
  });

  it('чужое фото → 400 validation, авто не изменено', async () => {
    const owner = await createUser();
    const other = await createUser();
    const carId = await createCar(owner.id);
    const res = await call(app, owner.token)
      .patch(`/cars/${carId}`)
      .send({ brand: 'Kia', photoFileId: await fileOf(other.id) });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('validation');
    const [row] = await db.select().from(cars).where(eq(cars.id, carId));
    expect(row.brand).toBe('Lada');
  });

  it('чужое и удалённое авто → 404 not_found, как у DELETE', async () => {
    const owner = await createUser();
    const other = await createUser();
    const carId = await createCar(owner.id);
    const notMine = await call(app, other.token).patch(`/cars/${carId}`).send({ seats: 2 });
    expect(notMine.status).toBe(404);
    expect(notMine.body.code).toBe('not_found');
    await db.update(cars).set({ deletedAt: new Date() }).where(eq(cars.id, carId));
    const gone = await call(app, owner.token).patch(`/cars/${carId}`).send({ seats: 2 });
    expect(gone.status).toBe(404);
  });
});
