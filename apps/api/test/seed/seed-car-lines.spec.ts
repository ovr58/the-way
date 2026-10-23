/**
 * Строка J3 плана apk-acceptance-round2: три демо-водителя легковых `+79000000006…08` — у каждого
 * авто с фото и СТС, отзывы, свой маршрут и поездки на завтра и послезавтра; повторное пополнение их
 * не дублирует. Весь прогон — во внешней транзакции с откатом, как `seed-media.spec.ts`.
 */
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { and, eq, inArray, sql } from 'drizzle-orm';
import { carDocuments, cars } from '../../src/modules/cars/internal/schema';
import { reviews } from '../../src/modules/reviews/internal/schema';
import { tripStops, trips } from '../../src/modules/trips/internal/schema';
import { users } from '../../src/modules/users/internal/schema';
import { services } from '../../seed/services';
import { addDays, appTz, dateInTz, seedDemo } from '../../seed/demo';
import { seed } from '../../seed/index';
import { closeDb, db, migrate } from '../helpers/db';

class Rollback extends Error {}

let dir: string;

beforeAll(async () => {
  await migrate();
  dir = await mkdtemp(join(tmpdir(), 'theway-seed-'));
  process.env.FILES_DIR = dir;
});

afterAll(async () => {
  await closeDb();
  delete process.env.FILES_DIR;
  await rm(dir, { recursive: true, force: true });
});

const PHONES = ['+79000000006', '+79000000007', '+79000000008'];
/**
 * Рейтинг и число отзывов — по истории `seed/history.ts`. У …06 и …07 среднее 4,857 → в ленте 4,9, как у …03
 * (`ratingOf` округляет до 0,1): лента идёт по рейтингу (FR-09), и с равным рейтингом водители перемешиваются по времени.
 */
const RATINGS: Record<string, { count: number; avg: number }> = {
  '+79000000006': { count: 7, avg: 34 / 7 },
  '+79000000007': { count: 7, avg: 34 / 7 },
  '+79000000008': { count: 3, avg: 4 },
};

it('seed: у +79000000006…08 легковое авто с фото и СТС, отзывы, свой маршрут, поездки на завтра и послезавтра', async () => {
  const outcome = db.transaction(async (tx) => {
    await seed(tx);
    const tz = appTz();
    const today = dateInTz(new Date(), tz);
    // Первый экран ленты: порядок сервиса — рейтинг ↓, время ↑; на нём не меньше трёх разных водителей.
    const [viewer] = await tx.select({ id: users.id }).from(users).where(eq(users.phone, '+79000000011'));
    const feed = await services(tx).trips.search(viewer.id, {});
    expect(new Set(feed.slice(0, 8).map((c) => c.driver.id)).size).toBeGreaterThanOrEqual(3);

    const names = new Set<string>();
    const routes = new Set<string>();

    for (const phone of PHONES) {
      const [driver] = await tx.select({ id: users.id, name: users.name, photo: users.photoFileId }).from(users).where(eq(users.phone, phone));
      expect(driver?.photo).toBeTruthy();
      names.add(driver.name ?? '');

      const own = await tx
        .select({ id: cars.id, kind: cars.kind, photo: cars.photoFileId, sts: sql<number>`count(${carDocuments.id})::int` })
        .from(cars)
        .leftJoin(carDocuments, and(eq(carDocuments.carId, cars.id), eq(carDocuments.kind, 'sts')))
        .where(eq(cars.ownerId, driver.id))
        .groupBy(cars.id);
      expect(own).toEqual([{ id: expect.any(String), kind: 'car', photo: expect.any(String), sts: 1 }]);

      const [rating] = await tx
        .select({ count: sql<number>`count(*)::int`, avg: sql<string>`avg(${reviews.rating})` })
        .from(reviews)
        .where(eq(reviews.targetId, driver.id));
      expect(rating.count).toBe(RATINGS[phone].count);
      expect(Number(rating.avg)).toBeCloseTo(RATINGS[phone].avg, 5);

      for (const offset of [1, 2]) {
        const date = addDays(today, offset);
        const day = await tx
          .select({ id: trips.id, reverseOf: trips.reverseOf })
          .from(trips)
          .where(and(eq(trips.driverId, driver.id), sql`(${trips.departsAt} at time zone ${tz})::date = ${date}::date`));
        expect({ phone, date, forward: day.filter((t) => !t.reverseOf).length, reverse: day.filter((t) => t.reverseOf).length }).toEqual({
          phone,
          date,
          forward: 1,
          reverse: 1,
        });
      }

      const [forward] = await tx
        .select({ id: trips.id })
        .from(trips)
        .where(and(eq(trips.driverId, driver.id), sql`${trips.reverseOf} is null`, sql`${trips.departsAt} > now()`))
        .limit(1);
      const stops = await tx.select({ cityId: tripStops.cityId }).from(tripStops).where(eq(tripStops.tripId, forward.id)).orderBy(tripStops.idx);
      routes.add(`${stops[0].cityId}-${stops[stops.length - 1].cityId}`);
    }
    expect(names.size).toBe(3);
    expect(routes.size).toBe(3);

    const ids = (await tx.select({ id: users.id }).from(users).where(inArray(users.phone, PHONES))).map((u) => u.id);
    const future = and(inArray(trips.driverId, ids), sql`${trips.departsAt} > now()`);
    const before = await tx.$count(trips, future);
    const again = await seedDemo(tx);
    expect(again.carLineTrips).toBe(0);
    expect(await tx.$count(trips, future)).toBe(before);
    throw new Rollback();
  });
  await outcome.catch((error: unknown) => {
    if (!(error instanceof Rollback)) throw error;
  });
}, 180_000);
