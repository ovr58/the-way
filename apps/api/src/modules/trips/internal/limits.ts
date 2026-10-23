/**
 * Лимит публикаций — на водителя по всем его авто: в сутки — одна неотменённая
 * поездка «туда» (`reverse_of = null`) и одна обратная; в календарную неделю (пн–вс) — не больше
 * `WEEKLY_LIMIT` неотменённых поездок обоих направлений. Сутки и неделя — по дате `departs_at` в `APP_TZ`.
 */
import { and, eq, isNotNull, isNull, ne, sql, type SQL } from 'drizzle-orm';
import { AppError } from '../../../common/errors';
import { logEvent } from '../../../common/logger';
import type { DbExecutor } from '../../../db/client';
import { trips } from './schema';

/** Сколько неотменённых поездок каждого направления допускается водителю в сутки. */
export const DAILY_LIMIT = 1;

/** Сколько неотменённых поездок водителя допускается в календарную неделю (кадр «Обратное направление - Заказ создан» «На неделе 3/10»). */
export const WEEKLY_LIMIT = 10;

const appTz = (): string => process.env.APP_TZ ?? 'Europe/Moscow';

/** Дата `departs_at` в `APP_TZ`. */
const tripDaySql = sql`date(timezone(${appTz()}::text, ${trips.departsAt}))`;

export interface DayUsage {
  forwardUsed: number;
  reverseUsed: number;
}

/** Неотменённые поездки водителя (все его авто) за сутки `day` (SQL-выражение даты); `excludeTripId` — правка себя. */
export async function usedOnDay(tx: DbExecutor, driverId: string, day: SQL, excludeTripId?: string): Promise<DayUsage> {
  const base = [eq(trips.driverId, driverId), ne(trips.status, 'cancelled'), sql`${tripDaySql} = ${day}`];
  if (excludeTripId) base.push(ne(trips.id, excludeTripId));
  const [forwardUsed, reverseUsed] = await Promise.all([
    tx.$count(trips, and(...base, isNull(trips.reverseOf))),
    tx.$count(trips, and(...base, isNotNull(trips.reverseOf))),
  ]);
  return { forwardUsed, reverseUsed };
}

/** Неотменённые поездки водителя (все его авто) в календарную неделю (пн–вс, Postgres `date_trunc('week')`) суток `day`. */
export async function usedInWeek(tx: DbExecutor, driverId: string, day: SQL, excludeTripId?: string): Promise<number> {
  const where = [
    eq(trips.driverId, driverId),
    ne(trips.status, 'cancelled'),
    sql`date_trunc('week', ${tripDaySql}) = date_trunc('week', (${day})::date)`,
  ];
  if (excludeTripId) where.push(ne(trips.id, excludeTripId));
  return tx.$count(trips, and(...where));
}

/** Сутки момента `at` в `APP_TZ`, как SQL-дата. */
export const dayOf = (at: Date): SQL => sql`date(timezone(${appTz()}::text, ${at.toISOString()}::timestamptz))`;

/** Лимит исчерпан — событие `trip_limit_rejected` и `limit_reached`. */
export async function assertWithinLimit(
  tx: DbExecutor,
  input: { driverId: string; carId: string; departsAt: Date; reverse: boolean; excludeTripId?: string },
): Promise<void> {
  const used = await usedOnDay(tx, input.driverId, dayOf(input.departsAt), input.excludeTripId);
  if ((input.reverse ? used.reverseUsed : used.forwardUsed) >= DAILY_LIMIT) {
    logEvent('trip_limit_rejected', { car_id: input.carId, date: input.departsAt.toLocaleDateString('en-CA', { timeZone: appTz() }) });
    throw new AppError('limit_reached', 'Достигнут лимит публикаций на эти сутки');
  }
  if ((await usedInWeek(tx, input.driverId, dayOf(input.departsAt), input.excludeTripId)) >= WEEKLY_LIMIT) {
    logEvent('trip_limit_rejected', { car_id: input.carId, date: input.departsAt.toLocaleDateString('en-CA', { timeZone: appTz() }) });
    throw new AppError('limit_reached', 'Достигнут лимит на неделю — следующая публикация с понедельника');
  }
}
