/** Шаг 1.2: `GET /cities` без токена и `resolveCityId`. */
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { and, eq } from 'drizzle-orm';
import request from 'supertest';
import { AppModule } from '../../app.module';
import { AppError } from '../../common/errors';
import { resolveCityId } from '../../common/places';
import { configureApp } from '../../configure-app';
import { DATABASE, type Database, runMigrations } from '../../db/client';
import { cities } from './internal/schema';

let app: INestApplication;
let db: Database;

/** Строка справочника: есть — её id, нет — вставка. */
async function cityFixture(name: string, region: string, lat: number, lng: number): Promise<number> {
  await db.insert(cities).values({ name, region, lat, lng }).onConflictDoNothing();
  const [row] = await db
    .select({ id: cities.id })
    .from(cities)
    .where(and(eq(cities.name, name), eq(cities.region, region)));
  return row.id;
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

describe('cities', () => {
  it('без токена GET /cities?q=мос → 200 и «Москва»', async () => {
    await cityFixture('Москва', 'г Москва', 55.7540471, 37.620405);
    const res = await request(app.getHttpServer()).get('/cities').query({ q: 'мос' });
    expect(res.status).toBe(200);
    expect((res.body as { name: string }[]).map((c) => c.name)).toContain('Москва');
  });

  /** Имена ответа `GET /cities?q=`. */
  async function search(q: string): Promise<string[]> {
    const res = await request(app.getHttpServer()).get('/cities').query({ q });
    expect(res.status).toBe(200);
    return (res.body as { name: string }[]).map((c) => c.name);
  }

  it('латиница: «yar», «Yaroslavl» → Ярославль; «Pereslavl» → Переславль-Залесский', async () => {
    await cityFixture('Ярославль', 'Ярославская область', 57.63, 39.88);
    await cityFixture('Переславль-Залесский', 'Ярославская область', 56.73, 38.85);
    expect(await search('yar')).toContain('Ярославль');
    expect(await search('Yaroslavl')).toContain('Ярославль');
    expect(await search('Pereslavl')).toContain('Переславль-Залесский');
    expect(await search('qqqzzz')).toEqual([]);
  });

  it('английские написания: «Yekaterinburg», «Nizhny Novgorod», «Pereslavl-Zalessky» находят город', async () => {
    await cityFixture('Екатеринбург', 'Свердловская область', 56.84, 60.6);
    await cityFixture('Нижний Новгород', 'Нижегородская область', 56.33, 44.0);
    await cityFixture('Переславль-Залесский', 'Ярославская область', 56.73, 38.85);
    expect(await search('Yekaterinburg')).toContain('Екатеринбург');
    expect(await search('Nizhny Novgorod')).toContain('Нижний Новгород');
    expect(await search('Pereslavl-Zalessky')).toContain('Переславль-Залесский');
  });

  it('сначала названия, начинающиеся с запроса: «яр» — Ярославль раньше Красноярска', async () => {
    await cityFixture('Ярославль', 'Ярославская область', 57.63, 39.88);
    await cityFixture('Красноярск', 'Красноярский край', 56.01, 92.85);
    for (const q of ['яр', 'yar']) {
      const names = await search(q);
      const lastPrefix = names.map((n) => n.toLowerCase().startsWith('яр')).lastIndexOf(true);
      const firstOther = names.findIndex((n) => !n.toLowerCase().startsWith('яр'));
      expect(names).toEqual(expect.arrayContaining(['Ярославль', 'Красноярск']));
      expect(lastPrefix).toBeLessThan(firstOther);
    }
  });
});

describe('resolveCityId', () => {
  it('подсказка Mapbox рядом с городом справочника → его id, без новой строки', async () => {
    // Пополнение прошлых прогонов (строка Mapbox с тем же именем ближе к точке) подменило бы ответ.
    await db.delete(cities).where(and(eq(cities.name, 'Ярославль'), eq(cities.source, 'mapbox')));
    const yaroslavl = await cityFixture('Ярославль', 'Ярославская область', 57.63, 39.88);
    const before = await db.$count(cities);
    const id = await resolveCityId(db, {
      place: { name: 'Ярославль', region: 'Ярославская область' },
      lat: 57.62,
      lng: 39.89,
    });
    expect(id).toBe(yaroslavl);
    expect(await db.$count(cities)).toBe(before);
  });

  it('пункта нет в справочнике → одна новая строка source=mapbox, повтор — тот же id', async () => {
    await db.delete(cities).where(and(eq(cities.name, 'Борисоглебский'), eq(cities.source, 'mapbox')));
    const before = await db.$count(cities);
    const input = { place: { name: 'Борисоглебский', region: 'Ярославская область' }, lat: 57.27, lng: 39.15 };
    const first = await resolveCityId(db, input);
    const second = await resolveCityId(db, input);
    expect(second).toBe(first);
    expect(await db.$count(cities)).toBe(before + 1);
    const [row] = await db.select().from(cities).where(eq(cities.id, first));
    expect(row.source).toBe('mapbox');
  });

  it('существующий cityId → он же; несуществующий → validation', async () => {
    const yaroslavl = await cityFixture('Ярославль', 'Ярославская область', 57.63, 39.88);
    expect(await resolveCityId(db, { cityId: yaroslavl })).toBe(yaroslavl);
    await expect(resolveCityId(db, { cityId: 99_999_999 })).rejects.toMatchObject({ code: 'validation' });
  });

  it('ни cityId, ни place (или оба) → validation', async () => {
    await expect(resolveCityId(db, {})).rejects.toBeInstanceOf(AppError);
    await expect(
      resolveCityId(db, { cityId: 1, place: { name: 'А', region: 'Б' }, lat: 1, lng: 1 }),
    ).rejects.toMatchObject({ code: 'validation' });
  });
});
