/**
 * Отмены и блокировка 2/30: одна блокировка на пользователя закрывает и бронирование, и
 * публикацию, какой бы ролью ни набраны отмены. Пишет только этот файл; A1.3 и A2.3 импортируют.
 */
import { and, eq, gt, sql } from 'drizzle-orm';
import type { DbExecutor } from '../db/client';
import { blocks, cancellations, users } from '../modules/users/internal/schema';
import type { CancellationRole } from './enums';
import { logEvent } from './logger';

/** Сколько отмен за окно даёт блокировку (вторая за 30 дней). */
export const CANCELLATIONS_TO_BLOCK = 2;
const BLOCK_MS = 30 * 24 * 60 * 60 * 1000;

/** Отмены пользователя за последние 30 дней. */
export async function countCancellations30(tx: DbExecutor, userId: string): Promise<number> {
  return tx.$count(
    cancellations,
    and(eq(cancellations.userId, userId), gt(cancellations.createdAt, sql`now() - interval '30 days'`)),
  );
}

export interface CancellationInput {
  userId: string;
  role: CancellationRole;
  bookingId?: string;
  tripId?: string;
}

export interface CancellationOutcome {
  cancellationsLast30: number;
  /** ISO; есть, если эта отмена заблокировала пользователя. */
  blockedUntil?: string;
}

/**
 * Записывает отмену; вторая за 30 дней — строка `blocks` на 30 дней и `users.blocked_until`
 * (событие `user_blocked`). Вызывать внутри транзакции действия отмены.
 */
export async function recordCancellation(tx: DbExecutor, input: CancellationInput): Promise<CancellationOutcome> {
  await tx.insert(cancellations).values({
    userId: input.userId,
    role: input.role,
    bookingId: input.bookingId ?? null,
    tripId: input.tripId ?? null,
  });
  const count = await countCancellations30(tx, input.userId);
  if (count < CANCELLATIONS_TO_BLOCK) return { cancellationsLast30: count };

  const startsAt = new Date();
  const endsAt = new Date(startsAt.getTime() + BLOCK_MS);
  await tx.insert(blocks).values({ userId: input.userId, reason: 'cancellations', startsAt, endsAt });
  await tx.update(users).set({ blockedUntil: endsAt }).where(eq(users.id, input.userId));
  logEvent('user_blocked', { blocked_user_id: input.userId, until: endsAt.toISOString(), reason: 'cancellations' });
  return { cancellationsLast30: count, blockedUntil: endsAt.toISOString() };
}

/** Даст ли следующая отмена блокировку (`CancelPreview.willBlock`). */
export async function nextCancellationBlocks(tx: DbExecutor, userId: string): Promise<boolean> {
  return (await countCancellations30(tx, userId)) + 1 >= CANCELLATIONS_TO_BLOCK;
}
