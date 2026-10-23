/** Строка A3.1: профиль, публичная карточка, жалобы (интеграционный, `DATABASE_URL`). */
import type { INestApplication } from '@nestjs/common';
import { createTestApp, call } from '../../../test/helpers/app';
import { addCancellation, closeDb, createBooking, createCar, createCity, createTrip, createUser, db } from '../../../test/helpers/db';
import { atLocal } from '../../../test/helpers/dates';
import { files } from '../files/internal/schema';
import { complaints } from '../reviews/internal/schema';

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

describe('GET /me', () => {
  it('форма Me + число отмен за 30 дней', async () => {
    const user = await createUser({ name: 'Анна' });
    await addCancellation(user.id, 'passenger');
    const res = await call(app, user.token).get('/me');
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      id: user.id,
      phone: user.phone,
      name: 'Анна',
      mode: 'passenger',
      rating: { value: 5, count: 0 },
      tripsCount: 0,
      cancellationsLast30: 1,
    });
  });
});

describe('PATCH /me', () => {
  it('имя, город, режим и свой файл-фото сохраняются; ответ — Me', async () => {
    const user = await createUser();
    const cityId = await createCity('Город-профиля', 57, 39);
    const photoFileId = await fileOf(user.id);
    const res = await call(app, user.token).patch('/me').send({ name: 'Борис', cityId, mode: 'driver', photoFileId });
    expect(res.status).toBe(200);
    expect(res.body.name).toBe('Борис');
    expect(res.body.mode).toBe('driver');
    expect(res.body.city.id).toBe(cityId);
    expect(res.body.photoUrl).toBe(`/files/${photoFileId}`);
    const again = await call(app, user.token).get('/me');
    expect(again.body.mode).toBe('driver');
  });

  it('null ≡ поле не прислано: {name:null, photoFileId:null, cityId:null, mode:driver} меняет только режим', async () => {
    const user = await createUser({ name: 'Прежнее' });
    const cityId = await createCity('Город-прежний', 57, 39);
    const photoFileId = await fileOf(user.id);
    await call(app, user.token).patch('/me').send({ cityId, photoFileId });
    const res = await call(app, user.token).patch('/me').send({ name: null, photoFileId: null, cityId: null, mode: 'driver' });
    expect(res.status).toBe(200);
    expect(res.body.mode).toBe('driver');
    expect(res.body.name).toBe('Прежнее');
    expect(res.body.city.id).toBe(cityId);
    expect(res.body.photoUrl).toBe(`/files/${photoFileId}`);
  });

  it('несуществующий город → 400 validation', async () => {
    const user = await createUser();
    const res = await call(app, user.token).patch('/me').send({ cityId: 99_999_999 });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('validation');
  });

  it('чужой файл как фото → 400 validation, профиль не изменён', async () => {
    const user = await createUser({ name: 'Свой' });
    const other = await createUser();
    const foreign = await fileOf(other.id);
    const res = await call(app, user.token).patch('/me').send({ name: 'Новое', photoFileId: foreign });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('validation');
    expect((await call(app, user.token).get('/me')).body.name).toBe('Свой');
  });

  it('пишет событие profile_updated с именами изменённых полей', async () => {
    const user = await createUser();
    const events = await eventsDuring(() => call(app, user.token).patch('/me').send({ name: 'Вера', mode: 'driver' }));
    const event = events.find((e) => e.event === 'profile_updated');
    expect(event).toBeDefined();
    expect(event?.fields).toEqual(['name', 'mode']);
    expect(JSON.stringify(event)).not.toContain('Вера');
  });
});

describe('GET /users/{id}/public', () => {
  it('карточка другого пользователя без телефона; нет брони — phone пуст', async () => {
    const viewer = await createUser();
    const other = await createUser({ name: 'Глеб' });
    const res = await call(app, viewer.token).get(`/users/${other.id}/public`);
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ id: other.id, name: 'Глеб', rating: { value: 5, count: 0 }, tripsCount: 0 });
    expect(res.body.phone ?? null).toBeNull();
  });

  it('телефон водителя виден пассажиру с бронью в awaiting_payment', async () => {
    const driver = await createUser({ mode: 'driver' });
    const passenger = await createUser();
    const from = await createCity('Откуда', 57, 39);
    const to = await createCity('Куда', 58, 38);
    const tripId = await createTrip({ driverId: driver.id, carId: await createCar(driver.id), cityIds: [from, to], departsAt: atLocal(1, 10) });
    await createBooking({ tripId, passengerId: passenger.id, status: 'awaiting_payment', toIdx: 1 });
    const res = await call(app, passenger.token).get(`/users/${driver.id}/public`);
    expect(res.body.phone).toBe(driver.phone);
  });

  it('неизвестный id → 404 not_found', async () => {
    const viewer = await createUser();
    const res = await call(app, viewer.token).get('/users/00000000-0000-4000-8000-000000000000/public');
    expect(res.status).toBe(404);
    expect(res.body.code).toBe('not_found');
  });
});

describe('GET /me/complaints', () => {
  it('только полученные пользователем жалобы, новые сверху; поданные им — нет', async () => {
    const target = await createUser();
    const author = await createUser();
    await db.insert(complaints).values({ authorId: author.id, targetId: target.id, reason: 'старая', createdAt: new Date(Date.now() - 60_000) });
    await db.insert(complaints).values({ authorId: author.id, targetId: target.id, reason: 'новая' });
    await db.insert(complaints).values({ authorId: target.id, targetId: author.id, reason: 'поданная' });
    const res = await call(app, target.token).get('/me/complaints');
    expect(res.status).toBe(200);
    expect((res.body as { reason: string; status: string }[]).map((c) => c.reason)).toEqual(['новая', 'старая']);
    expect(res.body[0].status).toBe('open');
  });
});
