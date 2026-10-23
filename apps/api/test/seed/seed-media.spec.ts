/**
 * Шаг G плана apk-acceptance-round2: после `db:seed` у каждого авто есть СТС, у водителя
 * автобуса `+79000000005` — ПАЗ на 30 мест и поездки; повторное ночное пополнение не дублирует его
 * поездки. Seed очищает таблицы, поэтому весь прогон идёт во внешней транзакции и откатывается: база
 * `DATABASE_URL` после теста та же, что до него. Файлы seed — во временный `FILES_DIR`.
 */
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { and, eq, gt, sql } from 'drizzle-orm';
import { carDocuments, cars } from '../../src/modules/cars/internal/schema';
import { files } from '../../src/modules/files/internal/schema';
import { trips } from '../../src/modules/trips/internal/schema';
import { users } from '../../src/modules/users/internal/schema';
import { seedDemo } from '../../seed/demo';
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

it('seed: СТС у всех авто, автобус и поездки у +79000000005, повторное пополнение без дублей', async () => {
  const outcome = db.transaction(async (tx) => {
    await seed(tx);

    const all = await tx
      .select({ plate: cars.plate, sts: sql<number>`count(${carDocuments.id})::int`, mime: sql<string>`min(${files.mime})` })
      .from(cars)
      .leftJoin(carDocuments, and(eq(carDocuments.carId, cars.id), eq(carDocuments.kind, 'sts')))
      .leftJoin(files, eq(files.id, carDocuments.fileId))
      .groupBy(cars.plate);
    expect(all.length).toBeGreaterThanOrEqual(6);
    for (const car of all) expect({ plate: car.plate, sts: car.sts, mime: car.mime }).toEqual({ plate: car.plate, sts: 1, mime: 'image/png' });

    const [driver] = await tx.select({ id: users.id, name: users.name, photo: users.photoFileId }).from(users).where(eq(users.phone, '+79000000005'));
    expect(driver?.photo).toBeTruthy();
    const busList = await tx
      .select({ kind: cars.kind, seats: cars.seats, plate: cars.plate, photo: cars.photoFileId })
      .from(cars)
      .where(eq(cars.ownerId, driver.id));
    expect(busList).toEqual([{ kind: 'bus', seats: 30, plate: 'Р777РР76', photo: expect.any(String) }]);

    const future = and(eq(trips.driverId, driver.id), gt(trips.departsAt, sql`now()`));
    const before = await tx.$count(trips, future);
    expect(before).toBeGreaterThanOrEqual(2);
    const again = await seedDemo(tx);
    expect(again.busTrips).toBe(0);
    expect(await tx.$count(trips, future)).toBe(before);
    throw new Rollback();
  });
  // Не Rollback — упавшая проверка внутри транзакции: пробрасывается как есть, с её сообщением.
  await outcome.catch((error: unknown) => {
    if (!(error instanceof Rollback)) throw error;
  });
}, 180_000);
