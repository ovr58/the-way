/**
 * Отмена поездки водителем: если есть присоединившиеся пассажиры — отмена идёт в счёт 2/30
 * (`common/cancellations.ts`); брони поездки обновляются напрямую (модуль `bookings` не
 * импортируется).
 */
import { and, eq, inArray, isNotNull } from 'drizzle-orm';
import { AppError } from '../../../common/errors';
import type { CancelPreview, CancelResult } from '../../../common/forms';
import { countCancellations30, nextCancellationBlocks, recordCancellation } from '../../../common/cancellations';
import { reopenOrders } from '../../../common/order-response';
import type { DbExecutor } from '../../../db/client';
import { bookings } from '../../bookings/internal/schema';
import { trips } from './schema';
import { JOINED_STATUSES, type TripRow } from './trips.repository';

/** Брони, которые закрываются вместе с поездкой. */
const LIVE_BOOKING_STATUSES = ['requested', 'awaiting_payment', 'paid'] as const;

async function joinedPassengers(tx: DbExecutor, tripId: string): Promise<number> {
  return tx.$count(bookings, and(eq(bookings.tripId, tripId), inArray(bookings.status, [...JOINED_STATUSES])));
}

/** Сколько отмен уже в счёте и заблокирует ли эта (только при присоединившихся). */
export async function previewTripCancel(tx: DbExecutor, driverId: string, tripId: string): Promise<CancelPreview> {
  const [joined, count] = await Promise.all([joinedPassengers(tx, tripId), countCancellations30(tx, driverId)]);
  return {
    cancellationsLast30: count,
    willBlock: joined > 0 && (await nextCancellationBlocks(tx, driverId)),
    refundAmount: null,
    counts: joined > 0,
  };
}

export interface CancelledTrip {
  result: CancelResult;
  joinedPassengers: number;
}

/** Отменяет поездку (строка `trips` уже заблокирована `FOR UPDATE`); поездка не отменена и не прошла. */
export async function cancelTrip(tx: DbExecutor, driverId: string, trip: TripRow): Promise<CancelledTrip> {
  if (trip.status === 'cancelled' || trip.departsAt.getTime() <= Date.now()) {
    throw new AppError('invalid_transition', 'Поездку уже нельзя отменить');
  }
  const joined = await joinedPassengers(tx, trip.id);
  // Брони из заказов пассажиров: их заказы снова открыты.
  const fromOrders = await tx
    .select({ id: bookings.id, orderId: bookings.orderId })
    .from(bookings)
    .where(and(eq(bookings.tripId, trip.id), inArray(bookings.status, [...LIVE_BOOKING_STATUSES]), isNotNull(bookings.orderId)));
  const now = new Date();
  await tx.update(trips).set({ status: 'cancelled', cancelledAt: now }).where(eq(trips.id, trip.id));
  await tx
    .update(bookings)
    .set({ status: 'cancelled', cancelledAt: now, driverSeenStatus: 'cancelled' })
    .where(and(eq(bookings.tripId, trip.id), inArray(bookings.status, [...LIVE_BOOKING_STATUSES])));
  await reopenOrders(tx, fromOrders, 'trip_cancelled');

  if (joined === 0) {
    return { result: { status: 'cancelled', cancellationsLast30: await countCancellations30(tx, driverId) }, joinedPassengers: 0 };
  }
  const outcome = await recordCancellation(tx, { userId: driverId, role: 'driver', tripId: trip.id });
  return {
    result: { status: 'cancelled', cancellationsLast30: outcome.cancellationsLast30, blockedUntil: outcome.blockedUntil ?? null },
    joinedPassengers: joined,
  };
}
