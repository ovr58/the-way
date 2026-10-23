/**
 * Шаг H плана apk-acceptance-round2: пополнение демо-поездок не превышает недельный лимит —
 * водитель, у авто которого на неделе не осталось места на «туда» и обратную, пропускается; исключений
 * для демо-водителей нет. Весь прогон — во внешней транзакции с откатом, как `seed-media.spec.ts`.
 */
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { eq } from 'drizzle-orm';
import { trips } from '../../src/modules/trips/internal/schema';
import { WEEKLY_LIMIT, dayOf, usedInWeek } from '../../src/modules/trips/internal/limits';
import { demoDrivers, withWeekRoom } from '../../seed/demo';
import { seed } from '../../seed/index';
import { atLocal } from '../helpers/dates';
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

it('seed: у демо-водителя без недельного остатка на «туда» и обратную день пропускается', async () => {
  const outcome = db.transaction(async (tx) => {
    await seed(tx);
    const [d02, d03] = await demoDrivers(tx);
    const at = atLocal(1, 12);

    // Заливка сама лимит не превышает.
    for (const d of [d02, d03]) expect(await usedInWeek(tx, d.id, dayOf(at))).toBeLessThanOrEqual(WEEKLY_LIMIT);

    // У …02 на неделе остаётся одна публикация — на «туда» с обратной не хватает.
    const [template] = await tx.select().from(trips).where(eq(trips.driverId, d02.id)).limit(1);
    const { id: _id, number: _number, ...row } = template;
    const used = await usedInWeek(tx, d02.id, dayOf(at));
    for (let k = used; k < WEEKLY_LIMIT - 1; k += 1) {
      await tx.insert(trips).values({ ...row, reverseOf: null, departsAt: at, arrivesAt: new Date(at.getTime() + 3600_000) });
    }
    expect(await withWeekRoom(tx, [d02, d03], at)).toEqual([d03]);
    throw new Rollback();
  });
  await outcome.catch((error: unknown) => {
    if (!(error instanceof Rollback)) throw error;
  });
}, 180_000);
