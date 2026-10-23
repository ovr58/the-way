/**
 * События «при открытии»: `GET /updates` и `POST /updates/{bookingId}/seen`. Какое событие
 * даёт бронь — только `updateKind` из `events.ts`; здесь — выборка и отметка «видел».
 */
import { and, eq, or, sql } from 'drizzle-orm';
import type { BookingStatus } from '../../../common/enums';
import type { DbExecutor } from '../../../db/client';
import { trips } from '../../trips/internal/schema';
import type { Update } from './bookings.dto';
import { seenOnTransition, updateKind } from './events';
import { bookings } from './schema';
import type { BookingSide } from './status-machine';

/** Время, с которого бронь в своём статусе. */
function statusAt(b: typeof bookings.$inferSelect): Date {
  const at: Partial<Record<BookingStatus, Date | null>> = {
    awaiting_payment: b.confirmedAt,
    paid: b.paidAt,
    rejected: b.rejectedAt,
    cancelled: b.cancelledAt,
  };
  return at[b.status] ?? b.createdAt;
}

/** События зрителя: как пассажира его броней и как водителя броней его поездок; новые сверху. */
export async function listUpdates(tx: DbExecutor, viewerId: string): Promise<Update[]> {
  const rows = await tx
    .select({ booking: bookings, driverId: trips.driverId })
    .from(bookings)
    .innerJoin(trips, eq(trips.id, bookings.tripId))
    .where(
      or(
        and(eq(bookings.passengerId, viewerId), sql`${bookings.passengerSeenStatus} is distinct from ${bookings.status}`),
        and(eq(trips.driverId, viewerId), sql`${bookings.driverSeenStatus} is distinct from ${bookings.status}`),
      ),
    );
  const out: (Update & { ms: number })[] = [];
  for (const { booking, driverId } of rows) {
    const sides: BookingSide[] = [];
    if (booking.passengerId === viewerId) sides.push('passenger');
    if (driverId === viewerId) sides.push('driver');
    for (const side of sides) {
      const kind = updateKind(side, booking);
      if (!kind) continue;
      const at = statusAt(booking);
      out.push({ bookingId: booking.id, tripId: booking.tripId, kind, at: at.toISOString(), ms: at.getTime() });
    }
  }
  return out.sort((a, b) => b.ms - a.ms).map(({ ms: _ms, ...u }) => u);
}

/** `<сторона запрашивающего>_seen_status = status` брони. */
export async function markSeen(tx: DbExecutor, side: BookingSide, booking: { id: string; status: BookingStatus }): Promise<void> {
  await tx.update(bookings).set(seenOnTransition(side, booking.status)).where(eq(bookings.id, booking.id));
}
