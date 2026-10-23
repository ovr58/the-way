/** Строка A3.3: список отзывов адресата (интеграционный, `DATABASE_URL`). */
import type { INestApplication } from '@nestjs/common';
import { createTestApp, call } from '../../../test/helpers/app';
import { atLocal } from '../../../test/helpers/dates';
import { closeDb, createCar, createCity, createTrip, createUser, db } from '../../../test/helpers/db';
import { reviews } from './internal/schema';

let app: INestApplication;

beforeAll(async () => {
  app = await createTestApp();
});

afterAll(async () => {
  await app.close();
  await closeDb();
});

describe('GET /users/{id}/reviews', () => {
  it('отзывы адресата, новые сверху, с именем автора; чужие отзывы не попадают', async () => {
    const target = await createUser({ mode: 'driver' });
    const viewer = await createUser();
    const ann = await createUser({ name: 'Анна' });
    const nameless = await createUser({ name: null });
    const from = await createCity('Отзывы-А', 57, 39);
    const to = await createCity('Отзывы-Б', 58, 38);
    const tripId = await createTrip({ driverId: target.id, carId: await createCar(target.id), cityIds: [from, to], departsAt: atLocal(1, 10) });
    const other = await createTrip({ driverId: ann.id, carId: await createCar(ann.id), cityIds: [from, to], departsAt: atLocal(1, 12) });

    await db.insert(reviews).values([
      { authorId: ann.id, targetId: target.id, tripId, rating: 4, body: 'Старый', createdAt: new Date(Date.now() - 120_000) },
      { authorId: nameless.id, targetId: target.id, tripId, rating: 5, body: null, createdAt: new Date(Date.now() - 60_000) },
      { authorId: viewer.id, targetId: ann.id, tripId: other, rating: 1, body: 'Чужой адресат' },
    ]);

    const res = await call(app, viewer.token).get(`/users/${target.id}/reviews`);
    expect(res.status).toBe(200);
    const list = res.body as { authorName: string | null; rating: number; body: string | null; createdAt: string; id: string }[];
    expect(list.map((r) => r.rating)).toEqual([5, 4]);
    expect(list[1]).toMatchObject({ authorName: 'Анна', body: 'Старый' });
    expect(list[0].authorName ?? null).toBeNull();
    expect(typeof list[0].id).toBe('string');
    expect(new Date(list[0].createdAt).toISOString()).toBe(list[0].createdAt);
  });

  it('нет отзывов → []', async () => {
    const viewer = await createUser();
    const res = await call(app, viewer.token).get(`/users/${viewer.id}/reviews`);
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });
});
