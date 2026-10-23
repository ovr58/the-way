/**
 * Доступ к таблицам броней и (импортом схем) поездок. Места меняются только под
 * `SELECT … FOR UPDATE` строки `trips`: транзакция, которая создаёт бронь или меняет её
 * статус, берёт `lockTrip` до того, как читает статус брони и места.
 */
import { type SQL, and, asc, desc, eq, inArray, not, sql } from 'drizzle-orm';
import type { ListStatus } from '../../../common/enums';
import { effectiveStatusSql } from '../../../common/views';
import type { DbExecutor, Transaction } from '../../../db/client';
import { tripExtras, tripPrices, tripStops, trips } from '../../trips/internal/schema';
import type { SeenStatuses } from './events';
import type { TripPricing } from '../../../common/pricing';
import { bookingExtras, bookings } from './schema';

export type TripRow = typeof trips.$inferSelect;
export type BookingRow = typeof bookings.$inferSelect;
export type NewBooking = typeof bookings.$inferInsert;

const ACTIVE = ['requested', 'awaiting_payment', 'paid'] as const;

/** Строка поездки под блокировкой до конца транзакции; нет поездки — `null`. */
export async function lockTrip(tx: Transaction, tripId: string): Promise<TripRow | null> {
  const [row] = await tx.select().from(trips).where(eq(trips.id, tripId)).for('update');
  return row ?? null;
}

export async function findBooking(tx: DbExecutor, bookingId: string): Promise<BookingRow | null> {
  const [row] = await tx.select().from(bookings).where(eq(bookings.id, bookingId));
  return row ?? null;
}

export async function tripOwner(tx: DbExecutor, tripId: string): Promise<string | null> {
  const [row] = await tx.select({ driverId: trips.driverId }).from(trips).where(eq(trips.id, tripId));
  return row?.driverId ?? null;
}

/** Активная бронь пассажира на поездку (`requested | awaiting_payment | paid`). */
export async function activeBookingId(tx: DbExecutor, tripId: string, passengerId: string): Promise<string | null> {
  const [row] = await tx
    .select({ id: bookings.id })
    .from(bookings)
    .where(and(eq(bookings.tripId, tripId), eq(bookings.passengerId, passengerId), inArray(bookings.status, [...ACTIVE])));
  return row?.id ?? null;
}

/** Брони поездки для водителя (без `rejected`, `cancelled`), по `created_at ↑`. */
export async function tripBookingIds(tx: DbExecutor, tripId: string): Promise<string[]> {
  const rows = await tx
    .select({ id: bookings.id })
    .from(bookings)
    .where(and(eq(bookings.tripId, tripId), inArray(bookings.status, [...ACTIVE])))
    .orderBy(asc(bookings.createdAt), asc(bookings.id));
  return rows.map((r) => r.id);
}

/**
 * Брони пассажира, новые сверху («Флаги поездки», `GET /bookings/mine`): `active` — активный
 * статус на поездке `active | intake_closed`; `completed` — остальные; без фильтра — все.
 */
export async function passengerBookingIds(tx: DbExecutor, passengerId: string, status?: ListStatus): Promise<string[]> {
  const isActive = and(inArray(bookings.status, [...ACTIVE]), sql`${effectiveStatusSql} in ('active', 'intake_closed')`) as SQL;
  const filter = status === 'active' ? isActive : status === 'completed' ? not(isActive) : undefined;
  const rows = await tx
    .select({ id: bookings.id })
    .from(bookings)
    .innerJoin(trips, eq(trips.id, bookings.tripId))
    .where(and(eq(bookings.passengerId, passengerId), filter))
    .orderBy(desc(bookings.createdAt), desc(bookings.id));
  return rows.map((r) => r.id);
}

/** Цены поездки для `pricing.ts`. */
export async function tripPricing(tx: DbExecutor, trip: Pick<TripRow, 'id' | 'priceFull'>): Promise<TripPricing> {
  const [stops, prices, extras] = await Promise.all([
    tx.select({ n: sql<number>`count(*)::int` }).from(tripStops).where(eq(tripStops.tripId, trip.id)),
    tx.select().from(tripPrices).where(eq(tripPrices.tripId, trip.id)),
    tx.select().from(tripExtras).where(eq(tripExtras.tripId, trip.id)),
  ]);
  return {
    priceFull: trip.priceFull,
    stopsCount: stops[0]?.n ?? 0,
    prices: prices.map(({ fromIdx, toIdx, price }) => ({ fromIdx, toIdx, price })),
    extras: extras.map(({ kind, price }) => ({ kind, price })),
  };
}

export async function insertBooking(tx: Transaction, values: NewBooking, extras: { kind: (typeof bookingExtras.$inferInsert)['kind']; price: number }[]): Promise<string> {
  const [row] = await tx.insert(bookings).values(values).returning({ id: bookings.id });
  if (extras.length) await tx.insert(bookingExtras).values(extras.map((e) => ({ bookingId: row.id, ...e })));
  return row.id;
}

/** Новый статус брони с отметкой «кто видел» и временем перехода. */
export async function setStatus(
  tx: Transaction,
  bookingId: string,
  patch: Pick<NewBooking, 'status'> & SeenStatuses & Pick<NewBooking, 'confirmedAt' | 'paidAt' | 'rejectedAt' | 'cancelledAt'>,
): Promise<void> {
  await tx.update(bookings).set(patch).where(eq(bookings.id, bookingId));
}

/** Сдвиг занятых мест поездки (под `lockTrip` той же транзакции). */
export async function shiftTaken(tx: Transaction, tripId: string, seats: number, parcelSeats: number): Promise<void> {
  await tx
    .update(trips)
    .set({ seatsTaken: sql`${trips.seatsTaken} + ${seats}`, parcelSeatsTaken: sql`${trips.parcelSeatsTaken} + ${parcelSeats}` })
    .where(eq(trips.id, tripId));
}
