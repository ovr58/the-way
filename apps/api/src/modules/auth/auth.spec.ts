/**
 * Шаг 1.2: вход по коду, охрана токеном, `POST /client-logs`. Интеграционный — приложение из
 * `configureApp` и база из `DATABASE_URL`.
 */
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { eq } from 'drizzle-orm';
import request from 'supertest';
import { AppModule } from '../../app.module';
import { configureApp } from '../../configure-app';
import { DATABASE, type Database, runMigrations } from '../../db/client';
import { users } from '../users/internal/schema';

let app: INestApplication;
let db: Database;

function randomPhone(): string {
  return `+7999${String(Math.floor(Math.random() * 1e7)).padStart(7, '0')}`;
}

async function login(phone: string): Promise<string> {
  const res = await request(app.getHttpServer()).post('/auth/verify').send({ phone, code: '111111' });
  expect(res.status).toBe(200);
  return res.body.token as string;
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

describe('auth', () => {
  it('код 111111 → токен, новый пользователь isNew', async () => {
    const res = await request(app.getHttpServer())
      .post('/auth/verify')
      .send({ phone: randomPhone(), code: '111111' });
    expect(res.status).toBe(200);
    expect(typeof res.body.token).toBe('string');
    expect(res.body.isNew).toBe(true);
    expect(res.body.me.mode).toBe('passenger');
    expect(res.body.me.rating).toEqual({ value: 5, count: 0 });
  });

  it('код 000000 → 400 invalid_code', async () => {
    const res = await request(app.getHttpServer())
      .post('/auth/verify')
      .send({ phone: randomPhone(), code: '000000' });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('invalid_code');
  });

  it('номер любого кода страны приводится к E.164', async () => {
    const phone = '+375 25 777 44 20';
    const sent = await request(app.getHttpServer()).post('/auth/request-code').send({ phone });
    expect(sent.status).toBe(200);
    expect(sent.body).toEqual({ resendAfterSec: 60 });
    const res = await request(app.getHttpServer()).post('/auth/verify').send({ phone, code: '111111' });
    expect(res.status).toBe(200);
    expect(res.body.token).toBeTruthy();
    const rows = await db.select().from(users).where(eq(users.phone, '+375257774420'));
    expect(rows).toHaveLength(1);
  });

  it('кривой номер → validation', async () => {
    const res = await request(app.getHttpServer()).post('/auth/request-code').send({ phone: '123' });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('validation');
  });

  it('«+7» и «+1» — ровно 11 цифр, остальные коды — 8–15', async () => {
    const send = (phone: string) => request(app.getHttpServer()).post('/auth/request-code').send({ phone });
    for (const phone of ['+7 900 000 00 0', '+7 900 000 00 001', '+1 202 555 01', '+1 202 555 01 234']) {
      const res = await send(phone);
      expect({ phone, status: res.status, code: res.body.code }).toEqual({ phone, status: 400, code: 'validation' });
    }
    for (const phone of ['+7 900 000 00 01', '+1 202 555 01 23', '+44 20 7946 09', '+375 25 777 44 20']) {
      expect({ phone, status: (await send(phone)).status }).toEqual({ phone, status: 200 });
    }
  });

  it('без токена /me → 401', async () => {
    const res = await request(app.getHttpServer()).get('/me');
    expect(res.status).toBe(401);
    expect(res.body.code).toBe('unauthorized');
  });

  it('GET /health → {ok: true} без токена', async () => {
    const res = await request(app.getHttpServer()).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ok: true });
  });

  it('logout гасит сессию', async () => {
    const token = await login(randomPhone());
    const out = await request(app.getHttpServer()).post('/auth/logout').set('authorization', `Bearer ${token}`);
    expect(out.status).toBe(204);
    const after = await request(app.getHttpServer()).get('/cars').set('authorization', `Bearer ${token}`);
    expect(after.status).toBe(401);
  });

  it('admin_blocked → 403 account_blocked, кроме GET /me', async () => {
    const phone = randomPhone();
    const token = await login(phone);
    await db.update(users).set({ adminBlocked: true }).where(eq(users.phone, phone));
    const cars = await request(app.getHttpServer()).get('/cars').set('authorization', `Bearer ${token}`);
    expect(cars.status).toBe(403);
    expect(cars.body.code).toBe('account_blocked');
    const me = await request(app.getHttpServer()).get('/me').set('authorization', `Bearer ${token}`);
    expect(me.status).not.toBe(403);
    expect(me.status).not.toBe(401);
  });
});

describe('client-logs', () => {
  it('204 и строка client_log с trace_id из traceparent', async () => {
    const traceId = '4bf92f3577b34da6a3ce929d0e0e4736';
    const lines: string[] = [];
    const spy = jest.spyOn(process.stdout, 'write').mockImplementation((chunk: string | Uint8Array) => {
      lines.push(String(chunk));
      return true;
    });
    try {
      const res = await request(app.getHttpServer())
        .post('/client-logs')
        .set('traceparent', `00-${traceId}-00f067aa0ba902b7-01`)
        .send({ level: 'error', message: 'boom', screen: 'search', appVersion: '1.0.0', device: 'emulator' });
      expect(res.status).toBe(204);
    } finally {
      spy.mockRestore();
    }
    const records = lines.map((l) => JSON.parse(l) as Record<string, unknown>);
    const entry = records.find((r) => r.event === 'client_log');
    expect(entry).toBeDefined();
    expect(entry?.trace_id).toBe(traceId);
    expect(entry?.message).toBe('boom');
  });

  it('тело 5 КБ → 413', async () => {
    const res = await request(app.getHttpServer())
      .post('/client-logs')
      .send({ level: 'info', message: 'x'.repeat(5 * 1024), appVersion: '1', device: 'd' });
    expect(res.status).toBe(413);
  });
});
