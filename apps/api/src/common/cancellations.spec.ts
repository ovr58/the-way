/** Шаг 1.2: подсчёт отмен, блокировка 2/30 и `BlockGuard`. */
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { eq } from 'drizzle-orm';
import request from 'supertest';
import { AppModule } from '../app.module';
import { configureApp } from '../configure-app';
import { DATABASE, type Database, runMigrations } from '../db/client';
import { blocks, users } from '../modules/users/internal/schema';
import { countCancellations30, recordCancellation } from './cancellations';

let app: INestApplication;
let db: Database;

function randomPhone(): string {
  return `+7998${String(Math.floor(Math.random() * 1e7)).padStart(7, '0')}`;
}

async function login(): Promise<{ token: string; userId: string }> {
  const res = await request(app.getHttpServer()).post('/auth/verify').send({ phone: randomPhone(), code: '111111' });
  return { token: res.body.token as string, userId: res.body.me.id as string };
}

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication({ logger: false });
  configureApp(app);
  await app.init();
  db = app.get<Database>(DATABASE);
  await runMigrations(db);
});

afterAll(async () => {
  await app.close();
});

describe('cancellations', () => {
  it('первая отмена — без блокировки, вторая за 30 дней — блок на 30 дней', async () => {
    const { userId } = await login();
    const first = await db.transaction((tx) => recordCancellation(tx, { userId, role: 'passenger' }));
    expect(first.cancellationsLast30).toBe(1);
    expect(first.blockedUntil).toBeUndefined();
    expect(await db.$count(blocks, eq(blocks.userId, userId))).toBe(0);

    const second = await db.transaction((tx) => recordCancellation(tx, { userId, role: 'driver' }));
    expect(second.cancellationsLast30).toBe(2);
    expect(second.blockedUntil).toBeDefined();
    const rows = await db.select().from(blocks).where(eq(blocks.userId, userId));
    expect(rows).toHaveLength(1);
    expect(rows[0].reason).toBe('cancellations');
    const days = (rows[0].endsAt.getTime() - rows[0].startsAt.getTime()) / 86_400_000;
    expect(days).toBe(30);
    const [user] = await db.select().from(users).where(eq(users.id, userId));
    expect(user.blockedUntil?.getTime()).toBe(rows[0].endsAt.getTime());
    expect(await countCancellations30(db, userId)).toBe(2);
  });

  it('заблокированный: POST /trips и POST /trips/:id/reverse → 403 blocked', async () => {
    const { token, userId } = await login();
    const until = new Date(Date.now() + 86_400_000);
    await db.update(users).set({ blockedUntil: until }).where(eq(users.id, userId));
    const trips = await request(app.getHttpServer()).post('/trips').set('authorization', `Bearer ${token}`).send({});
    expect(trips.status).toBe(403);
    expect(trips.body.code).toBe('blocked');
    expect(new Date(trips.body.blockedUntil as string).getTime()).toBe(until.getTime());
    const reverse = await request(app.getHttpServer())
      .post('/trips/00000000-0000-4000-8000-000000000000/reverse')
      .set('authorization', `Bearer ${token}`)
      .send({});
    expect(reverse.status).toBe(403);
    expect(reverse.body.code).toBe('blocked');
  });

  it('без блокировки POST /trips до проверки блокировки не отказывает', async () => {
    const { token } = await login();
    const res = await request(app.getHttpServer()).post('/trips').set('authorization', `Bearer ${token}`).send({});
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('validation');
  });
});
