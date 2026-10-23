/** Строка A3.2: автомобили водителя и документ СТС (интеграционный, `DATABASE_URL`). */
import type { INestApplication } from '@nestjs/common';
import { and, eq } from 'drizzle-orm';
import { createTestApp, call } from '../../../test/helpers/app';
import { atLocal } from '../../../test/helpers/dates';
import { closeDb, createCar, createCity, createTrip, createUser, db } from '../../../test/helpers/db';
import { files } from '../files/internal/schema';
import { adminChecks, cars } from './internal/schema';

let app: INestApplication;

beforeAll(async () => {
  app = await createTestApp();
});

afterAll(async () => {
  await app.close();
  await closeDb();
});

const KIA = { brand: 'Kia', model: 'Rio', kind: 'car', seats: 4, plate: 'Е333ЕЕ76' };

async function fileOf(ownerId: string): Promise<string> {
  const [row] = await db.insert(files).values({ ownerId, mime: 'image/png', path: 'x/y.png', size: 1 }).returning({ id: files.id });
  return row.id;
}

/** События бизнес-журнала, попавшие в stdout за время `action`. */
async function eventsDuring(action: () => Promise<unknown>): Promise<Record<string, unknown>[]> {
  const lines: string[] = [];
  const original = process.stdout.write.bind(process.stdout);
  process.stdout.write = ((chunk: string | Uint8Array): boolean => {
    lines.push(String(chunk));
    return true;
  }) as typeof process.stdout.write;
  try {
    await action();
  } finally {
    process.stdout.write = original;
  }
  return lines
    .join('')
    .split('\n')
    .filter((l) => l.startsWith('{'))
    .map((l) => JSON.parse(l) as Record<string, unknown>);
}

describe('POST /cars', () => {
  it('201, Car со статусом verified и пустыми документами; admin_checks(car, approved)', async () => {
    const owner = await createUser({ mode: 'driver' });
    const photo = await fileOf(owner.id);
    const res = await call(app, owner.token).post('/cars').send({ ...KIA, photoFileId: photo });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ ...KIA, status: 'verified', documents: [], photoUrl: `/files/${photo}` });
    const [check] = await db
      .select()
      .from(adminChecks)
      .where(and(eq(adminChecks.subjectKind, 'car'), eq(adminChecks.subjectId, res.body.id as string)));
    expect(check.status).toBe('approved');
  });

  it('чужое фото → 400 validation, авто не создано', async () => {
    const owner = await createUser();
    const other = await createUser();
    const res = await call(app, owner.token).post('/cars').send({ ...KIA, photoFileId: await fileOf(other.id) });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('validation');
    expect((await call(app, owner.token).get('/cars')).body).toEqual([]);
  });

  it('seats 0 → 400 validation', async () => {
    const owner = await createUser();
    const res = await call(app, owner.token).post('/cars').send({ ...KIA, seats: 0 });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('validation');
  });

  it('«Другая модель»: свободное название 40 символов → 201; 41 → 400 validation', async () => {
    const owner = await createUser({ mode: 'driver' });
    const free = 'Ё'.repeat(40);
    const ok = await call(app, owner.token).post('/cars').send({ ...KIA, model: free });
    expect(ok.status).toBe(201);
    expect(ok.body.model).toBe(free);
    const long = await call(app, owner.token).post('/cars').send({ ...KIA, model: `${free}Ж`, plate: 'К401КК76' });
    expect(long.status).toBe(400);
    expect(long.body.code).toBe('validation');
  });

  it('пишет событие car_created с car_id', async () => {
    const owner = await createUser();
    let carId = '';
    const events = await eventsDuring(async () => {
      carId = (await call(app, owner.token).post('/cars').send(KIA)).body.id as string;
    });
    expect(carId).toMatch(/^[0-9a-f-]{36}$/);
    expect(events.find((e) => e.event === 'car_created')?.car_id).toBe(carId);
  });
});

describe('GET /cars · DELETE /cars/{id}', () => {
  it('список — только свои живые авто', async () => {
    const owner = await createUser();
    const other = await createUser();
    const mine = await createCar(owner.id);
    await createCar(other.id);
    const gone = await createCar(owner.id);
    await db.update(cars).set({ deletedAt: new Date() }).where(eq(cars.id, gone));
    const res = await call(app, owner.token).get('/cars');
    expect(res.status).toBe(200);
    expect((res.body as { id: string }[]).map((c) => c.id)).toEqual([mine]);
  });

  it('удаление → 204, строка остаётся с deleted_at, из списка исчезает; повтор и чужое → 404', async () => {
    const owner = await createUser();
    const other = await createUser();
    const carId = await createCar(owner.id);
    expect((await call(app, other.token).delete(`/cars/${carId}`)).status).toBe(404);
    let status = 0;
    const events = await eventsDuring(async () => {
      status = (await call(app, owner.token).delete(`/cars/${carId}`)).status;
    });
    expect(status).toBe(204);
    expect(events.find((e) => e.event === 'car_deleted')?.car_id).toBe(carId);
    const [row] = await db.select().from(cars).where(eq(cars.id, carId));
    expect(row.deletedAt).not.toBeNull();
    expect((await call(app, owner.token).get('/cars')).body).toEqual([]);
    const again = await call(app, owner.token).delete(`/cars/${carId}`);
    expect(again.status).toBe(404);
    expect(again.body.code).toBe('not_found');
  });
});

describe('POST /cars/{id}/documents', () => {
  it('свой файл как СТС → 201 и Car с документом {id, kind, url}; событие car_document_added', async () => {
    const owner = await createUser();
    const carId = await createCar(owner.id);
    const fileId = await fileOf(owner.id);
    let status = 0;
    let body: { id: string; documents: { kind: string; url: string }[] } = { id: '', documents: [] };
    const events = await eventsDuring(async () => {
      const res = await call(app, owner.token).post(`/cars/${carId}/documents`).send({ fileId, kind: 'sts' });
      status = res.status;
      body = res.body as typeof body;
    });
    expect(status).toBe(201);
    expect(body.id).toBe(carId);
    expect(body.documents).toHaveLength(1);
    expect(body.documents[0]).toMatchObject({ kind: 'sts', url: `/files/${fileId}` });
    expect(events.find((e) => e.event === 'car_document_added')?.car_id).toBe(carId);
    const list = await call(app, owner.token).get('/cars');
    expect(list.body[0].documents).toHaveLength(1);
  });

  it('чужой файл → 400 validation; чужое авто → 404 not_found', async () => {
    const owner = await createUser();
    const other = await createUser();
    const carId = await createCar(owner.id);
    const foreign = await call(app, owner.token)
      .post(`/cars/${carId}/documents`)
      .send({ fileId: await fileOf(other.id), kind: 'sts' });
    expect(foreign.status).toBe(400);
    expect(foreign.body.code).toBe('validation');
    const notMine = await call(app, other.token)
      .post(`/cars/${carId}/documents`)
      .send({ fileId: await fileOf(other.id), kind: 'sts' });
    expect(notMine.status).toBe(404);
    expect(notMine.body.code).toBe('not_found');
  });
});

describe('Госномер заглавными кириллицей', () => {
  it('POST и PATCH хранят и отдают «А777АА76» вместо набранного «a777aa76»; разделители остаются', async () => {
    const http = call(app, (await createUser({ mode: 'driver' })).token);
    const created = await http.post('/cars').send({ ...KIA, plate: 'a777aa76' });
    expect(created.status).toBe(201);
    expect(created.body.plate).toBe('А777АА76');
    const [row] = await db.select({ plate: cars.plate }).from(cars).where(eq(cars.id, created.body.id));
    expect(row.plate).toBe('А777АА76');

    const renamed = await http.patch(`/cars/${created.body.id}`).send({ plate: 'в 123 ук-76' });
    expect(renamed.status).toBe(200);
    expect(renamed.body.plate).toBe('В 123 УК-76');
    const [patched] = await db.select({ plate: cars.plate }).from(cars).where(eq(cars.id, created.body.id));
    expect(patched.plate).toBe('В 123 УК-76');
  });

  it('старая строка, записанная как набрано, — заглавными кириллицей и в списке авто, и в деталях поездки', async () => {
    const driver = await createUser({ mode: 'driver' });
    const carId = await createCar(driver.id);
    await db.update(cars).set({ plate: 'a555mk76' }).where(eq(cars.id, carId));
    const list = await call(app, driver.token).get('/cars');
    expect((list.body as { plate: string }[]).map((c) => c.plate)).toEqual(['А555МК76']);

    const trip = await createTrip({
      driverId: driver.id,
      carId,
      cityIds: [await createCity('НомерА', 57.6, 39.8), await createCity('НомерБ', 58.0, 38.8)],
      departsAt: atLocal(1, 10),
    });
    const details = await call(app, (await createUser()).token).get(`/trips/${trip}`);
    expect(details.body.car.plate).toBe('А555МК76');
  });
});
