/** Строка A3.2: загрузка и выдача изображений (интеграционный, `DATABASE_URL`). */
import { existsSync } from 'node:fs';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import type { INestApplication } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { createTestApp, call } from '../../../test/helpers/app';
import { closeDb, createUser, db } from '../../../test/helpers/db';
import { files } from './internal/schema';

let app: INestApplication;
let dir: string;
const PNG = Buffer.from('89504e470d0a1a0a0000000d49484452', 'hex');

beforeAll(async () => {
  dir = await mkdtemp(join(tmpdir(), 'theway-files-'));
  process.env.FILES_DIR = dir;
  app = await createTestApp();
});

afterAll(async () => {
  await app.close();
  await closeDb();
  delete process.env.FILES_DIR;
  await rm(dir, { recursive: true, force: true });
});

describe('POST /files · GET /files/{id}', () => {
  it('png → 201 {id, url}; файл лежит в FILES_DIR; любой вошедший читает те же байты и тип', async () => {
    const owner = await createUser();
    const reader = await createUser();
    const up = await call(app, owner.token).post('/files').attach('file', PNG, { filename: 'a.png', contentType: 'image/png' });
    expect(up.status).toBe(201);
    expect(up.body.url).toBe(`/files/${up.body.id}`);

    const [row] = await db.select().from(files).where(eq(files.id, up.body.id as string));
    expect(row.ownerId).toBe(owner.id);
    expect(row.mime).toBe('image/png');
    expect(row.size).toBe(PNG.length);
    expect(existsSync(join(dir, row.path))).toBe(true);

    const got = await call(app, reader.token)
      .get(up.body.url as string)
      .buffer(true)
      .parse((res, cb) => {
        const chunks: Buffer[] = [];
        res.on('data', (c: Buffer) => chunks.push(c));
        res.on('end', () => cb(null, Buffer.concat(chunks)));
      });
    expect(got.status).toBe(200);
    expect(got.headers['content-type']).toContain('image/png');
    expect((got.body as Buffer).equals(PNG)).toBe(true);
  });

  it('без токена → 401 на обоих путях', async () => {
    const owner = await createUser();
    const up = await call(app, owner.token).post('/files').attach('file', PNG, { filename: 'a.png', contentType: 'image/png' });
    expect((await call(app).post('/files').attach('file', PNG, { filename: 'a.png', contentType: 'image/png' })).status).toBe(401);
    expect((await call(app).get(up.body.url as string)).status).toBe(401);
  });

  it('больше 10 МБ → 413 file_too_large', async () => {
    const user = await createUser();
    const big = Buffer.alloc(10 * 1024 * 1024 + 1, 1);
    const res = await call(app, user.token).post('/files').attach('file', big, { filename: 'big.png', contentType: 'image/png' });
    expect(res.status).toBe(413);
    expect(res.body.code).toBe('file_too_large');
  });

  it('не изображение → 415 file_type; ровно 10 МБ проходит', async () => {
    const user = await createUser();
    const text = await call(app, user.token).post('/files').attach('file', Buffer.from('hi'), { filename: 'a.txt', contentType: 'text/plain' });
    expect(text.status).toBe(415);
    expect(text.body.code).toBe('file_type');
    const edge = Buffer.alloc(10 * 1024 * 1024, 1);
    const ok = await call(app, user.token).post('/files').attach('file', edge, { filename: 'e.webp', contentType: 'image/webp' });
    expect(ok.status).toBe(201);
  });

  it('поля file нет → 400 validation; неизвестный id → 404 not_found', async () => {
    const user = await createUser();
    const none = await call(app, user.token).post('/files').field('x', 'y');
    expect(none.status).toBe(400);
    expect(none.body.code).toBe('validation');
    const missing = await call(app, user.token).get('/files/00000000-0000-4000-8000-000000000000');
    expect(missing.status).toBe(404);
    expect(missing.body.code).toBe('not_found');
  });
});
