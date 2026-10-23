/**
 * Заказ пассажира и поездка водителя: подходит ли поездка
 * под заказ, отклик водителя (сразу бронь «Ожидает оплаты»), повторное открытие и закрытие заказа при
 * отмене его брони. Общее для модулей `orders` (отклик своей поездкой, подходящие поездки), `trips`
 * (отклик новой поездкой, отмена поездки) и `bookings` (отмена брони) — чужие таблицы импортом схем,
 * чужие сервисы не импортируются.
 */
import { and, asc, desc, eq, inArray, sql } from 'drizzle-orm';
import type { DbExecutor, Transaction } from '../db/client';
import { bookingExtras, bookings } from '../modules/bookings/internal/schema';
import { orderExtras, orderStops, orders } from '../modules/orders/internal/schema';
import { tripExtras, tripPrices, tripStops, trips } from '../modules/trips/internal/schema';
import { SERVICE_KINDS, type OrderStatus, type ParcelSize, type ServiceKind, type TripKind, type TripStatus } from './enums';
import { AppError } from './errors';
import { logEvent } from './logger';
import { priceBooking, segPrice, type TripPricing } from './pricing';
import { appDay } from './trip-times';
import { effectiveStatusSql } from './views';

/** Живые брони: у заказа такая одна (индекс `bookings_active_order_unique`). */
const LIVE_BOOKING_STATUSES = ['requested', 'awaiting_payment', 'paid'] as const;

/** Действующий статус заказа: открытый с выездом в прошлом — `expired`, без крона. */
export const orderStatusSql = sql<OrderStatus>`(case when ${orders.status} = 'open' and ${orders.departsAt} <= now() then 'expired' else ${orders.status}::text end)`;

/** Заказ — то, что нужно для подбора поездки. */
export interface OrderFacts {
  id: string;
  passengerId: string;
  kind: TripKind;
  departsAt: Date;
  seats: number;
  parcelSize: ParcelSize;
  services: ServiceKind[];
  fromCityId: number;
  toCityId: number;
}

/** Поездка — то, что нужно для подбора: статус, места, города остановок по `idx`, цены. */
export interface TripFacts {
  id: string;
  driverId: string;
  effectiveStatus: TripStatus;
  departsAt: Date;
  seatsFree: number;
  parcelSeatsFree: number;
  parcelOnlyAllowed: boolean;
  cityIds: number[];
  pricing: TripPricing;
}

export type OrderMatch = { ok: true; fromIdx: number; toIdx: number; priceTotal: number } | { ok: false; reason: string };

const PARCEL_EXTRA = { S: 'parcel_s', M: 'parcel_m', L: 'parcel_l' } as const;

const no = (reason: string): OrderMatch => ({ ok: false, reason });

/**
 * Подходит ли поездка под заказ: поездка активна; выезд — в те же сутки `APP_TZ`; город «откуда»
 * стоит раньше города «куда», и у отрезка есть цена (сумма участков); хватает мест; размер
 * посылки водитель возит и есть место для посылки; заказ-посылку водитель берёт без проезда; услуги
 * заказа водитель предлагает. Цена — та же, что у брони (`priceBooking`).
 */
export function matchOrderToTrip(order: OrderFacts, trip: TripFacts): OrderMatch {
  if (trip.effectiveStatus !== 'active') return no('Поездка не принимает пассажиров');
  if (appDay(trip.departsAt) !== appDay(order.departsAt)) return no('Поездка в другой день');
  const fromIdx = trip.cityIds.indexOf(order.fromCityId);
  const toIdx = trip.cityIds.lastIndexOf(order.toCityId);
  if (fromIdx < 0 || toIdx <= fromIdx) return no('Маршрут поездки не проходит через точки заказа');
  if (segPrice(trip.pricing, fromIdx, toIdx) === null) return no('У этого отрезка поездки нет цены');
  if (order.seats > trip.seatsFree) return no('Мест в поездке не хватает');
  const offered = new Set<string>(trip.pricing.extras.map((e) => e.kind));
  if (order.parcelSize !== 'none') {
    if (!offered.has(PARCEL_EXTRA[order.parcelSize])) return no(`Посылку ${order.parcelSize} водитель не возит`);
    if (trip.parcelSeatsFree < 1) return no('Мест для посылок нет');
  }
  if (order.kind === 'parcel' && !trip.parcelOnlyAllowed) return no('Посылку без проезда водитель не возит');
  const missing = order.services.find((k) => !offered.has(k));
  if (missing) return no(`Услуга ${missing} не предлагается`);
  const { priceTotal } = priceBooking(trip.pricing, {
    fromIdx,
    toIdx,
    seats: order.seats,
    parcelSize: order.parcelSize,
    services: order.services,
  });
  return { ok: true, fromIdx, toIdx, priceTotal };
}

/** Заказ с действующим статусом, номером и комментарием; под `FOR UPDATE` строки `orders` при `lock`. */
export interface OrderRecord extends OrderFacts {
  number: number;
  status: OrderStatus;
  parcelComment: string | null;
}

export async function loadOrder(tx: DbExecutor, orderId: string, lock = false): Promise<OrderRecord | null> {
  const query = tx.select({ order: orders, status: orderStatusSql }).from(orders).where(eq(orders.id, orderId));
  const [row] = lock ? await query.for('update') : await query;
  if (!row) return null;
  const [stops, extras] = await Promise.all([
    tx.select({ idx: orderStops.idx, cityId: orderStops.cityId }).from(orderStops).where(eq(orderStops.orderId, orderId)).orderBy(asc(orderStops.idx)),
    tx.select({ kind: orderExtras.kind }).from(orderExtras).where(eq(orderExtras.orderId, orderId)),
  ]);
  const { order } = row;
  const kinds = extras.map((e) => e.kind);
  return {
    id: order.id,
    number: order.number,
    passengerId: order.passengerId,
    kind: order.kind,
    departsAt: order.departsAt,
    seats: order.seats,
    parcelSize: order.parcelSize,
    parcelComment: order.parcelComment,
    services: SERVICE_KINDS.filter((k) => kinds.includes(k)),
    fromCityId: stops[0]?.cityId ?? -1,
    toCityId: stops[stops.length - 1]?.cityId ?? -1,
    status: row.status,
  };
}

/** Поездки для подбора в порядке `tripIds`. */
export async function loadTrips(tx: DbExecutor, tripIds: string[]): Promise<TripFacts[]> {
  const ids = [...new Set(tripIds)];
  if (ids.length === 0) return [];
  const [rows, stops, prices, extras] = await Promise.all([
    tx.select({ trip: trips, effectiveStatus: effectiveStatusSql }).from(trips).where(inArray(trips.id, ids)),
    tx
      .select({ tripId: tripStops.tripId, cityId: tripStops.cityId })
      .from(tripStops)
      .where(inArray(tripStops.tripId, ids))
      .orderBy(asc(tripStops.tripId), asc(tripStops.idx)),
    tx.select().from(tripPrices).where(inArray(tripPrices.tripId, ids)),
    tx.select().from(tripExtras).where(inArray(tripExtras.tripId, ids)),
  ]);
  const byId = new Map(rows.map((r) => [r.trip.id, r]));
  return tripIds.flatMap((id): TripFacts[] => {
    const row = byId.get(id);
    if (!row) return [];
    const { trip } = row;
    const cityIds = stops.filter((s) => s.tripId === id).map((s) => s.cityId);
    return [
      {
        id,
        driverId: trip.driverId,
        effectiveStatus: row.effectiveStatus as TripStatus,
        departsAt: trip.departsAt,
        seatsFree: trip.seatsTotal - trip.seatsTaken,
        parcelSeatsFree: trip.parcelSeatsTotal - trip.parcelSeatsTaken,
        parcelOnlyAllowed: trip.parcelOnlyAllowed,
        cityIds,
        pricing: {
          priceFull: trip.priceFull,
          stopsCount: cityIds.length,
          prices: prices.filter((p) => p.tripId === id).map(({ fromIdx, toIdx, price }) => ({ fromIdx, toIdx, price })),
          extras: extras.filter((e) => e.tripId === id).map(({ kind, price }) => ({ kind, price })),
        },
      },
    ];
  });
}

/** Есть ли у пассажира живая бронь этой поездки (`booking_exists`). */
async function hasLiveBooking(tx: DbExecutor, tripId: string, passengerId: string): Promise<boolean> {
  const count = await tx.$count(
    bookings,
    and(eq(bookings.tripId, tripId), eq(bookings.passengerId, passengerId), inArray(bookings.status, [...LIVE_BOOKING_STATUSES])),
  );
  return count > 0;
}

export interface TripMatch {
  tripId: string;
  fromIdx: number;
  toIdx: number;
  priceTotal: number;
}

/** Свои активные поездки водителя, подходящие под заказ, по выезду ↑ (`OrderDetails.matchingTrips`). */
export async function matchingTripsFor(tx: DbExecutor, order: OrderFacts, driverId: string): Promise<TripMatch[]> {
  const own = await tx
    .select({ id: trips.id })
    .from(trips)
    .where(and(eq(trips.driverId, driverId), sql`${effectiveStatusSql} = 'active'`))
    .orderBy(asc(trips.departsAt), asc(trips.id));
  const facts = await loadTrips(tx, own.map((t) => t.id));
  const out: TripMatch[] = [];
  for (const trip of facts) {
    const match = matchOrderToTrip(order, trip);
    if (!match.ok || (await hasLiveBooking(tx, trip.id, order.passengerId))) continue;
    out.push({ tripId: trip.id, fromIdx: match.fromIdx, toIdx: match.toIdx, priceTotal: match.priceTotal });
  }
  return out;
}

/**
 * Отклик водителя поездкой `tripId` на заказ: под `FOR UPDATE` заказа и поездки — заказ открыт
 * и не свой (`order_unavailable`), поездка своя (`forbidden`), подходит (`order_mismatch`), у пассажира
 * нет живой брони этой поездки (`booking_exists`). Бронь — сразу «Ожидает оплаты»: пассажиру придёт
 * «Водитель принял заявку» (`passenger_seen_status = null`), водителю о своём отклике события нет.
 * Заказ — «найден водитель». Возвращает id брони.
 */
export async function respondToOrder(
  tx: Transaction,
  input: { orderId: string; tripId: string; driverId: string; via: 'trip' | 'new_trip' },
): Promise<string> {
  const order = await loadOrder(tx, input.orderId, true);
  if (!order) throw new AppError('not_found', 'Заказ не найден');
  if (order.status !== 'open' || order.passengerId === input.driverId) {
    throw new AppError('order_unavailable', 'Заказ уже взят, отменён или истёк');
  }
  const [locked] = await tx.select({ driverId: trips.driverId }).from(trips).where(eq(trips.id, input.tripId)).for('update');
  if (!locked) throw new AppError('not_found', 'Поездка не найдена');
  if (locked.driverId !== input.driverId) throw new AppError('forbidden', 'Чужая поездка');
  const [trip] = await loadTrips(tx, [input.tripId]);
  const match = matchOrderToTrip(order, trip);
  if (!match.ok) throw new AppError('order_mismatch', match.reason);
  if (await hasLiveBooking(tx, trip.id, order.passengerId)) throw new AppError('booking_exists', 'Бронь на эту поездку уже есть');

  const price = priceBooking(trip.pricing, {
    fromIdx: match.fromIdx,
    toIdx: match.toIdx,
    seats: order.seats,
    parcelSize: order.parcelSize,
    services: order.services,
  });
  const [booking] = await tx
    .insert(bookings)
    .values({
      tripId: trip.id,
      passengerId: order.passengerId,
      fromIdx: match.fromIdx,
      toIdx: match.toIdx,
      seats: order.seats,
      parcelSize: order.parcelSize,
      parcelOnly: order.kind === 'parcel',
      parcelComment: order.parcelSize !== 'none' ? order.parcelComment : null,
      priceTotal: price.priceTotal,
      status: 'awaiting_payment',
      passengerSeenStatus: null,
      driverSeenStatus: 'awaiting_payment',
      confirmedAt: new Date(),
      orderId: order.id,
    })
    .returning({ id: bookings.id });
  if (price.extras.length > 0) {
    await tx.insert(bookingExtras).values(price.extras.map((e) => ({ bookingId: booking.id, kind: e.kind, price: e.price })));
  }
  await tx.update(orders).set({ status: 'matched' }).where(eq(orders.id, order.id));
  logEvent('booking_created', {
    trip_id: trip.id,
    booking_id: booking.id,
    status_from: null,
    status_to: 'awaiting_payment',
    seats: order.seats,
    price_total: price.priceTotal,
  });
  logEvent('order_responded', { order_id: order.id, trip_id: trip.id, booking_id: booking.id, via: input.via });
  return booking.id;
}

/** Брони, отменённые до оплаты пассажиром (отказ от отклика) или отменой поездки, — их заказы снова открыты. */
export async function reopenOrders(
  tx: DbExecutor,
  cancelled: { id: string; orderId: string | null }[],
  reason: 'passenger_declined' | 'trip_cancelled',
): Promise<void> {
  for (const b of cancelled) {
    if (!b.orderId) continue;
    const reopened = await tx
      .update(orders)
      .set({ status: 'open' })
      .where(and(eq(orders.id, b.orderId), eq(orders.status, 'matched')))
      .returning({ id: orders.id });
    if (reopened.length > 0) logEvent('order_reopened', { order_id: b.orderId, booking_id: b.id, reason });
  }
}

/** Пассажир отменил оплаченную бронь из заказа — заказ закрыт. */
export async function closeOrder(tx: DbExecutor, orderId: string, bookingId: string): Promise<void> {
  const closed = await tx
    .update(orders)
    .set({ status: 'cancelled', cancelledAt: new Date() })
    .where(and(eq(orders.id, orderId), eq(orders.status, 'matched')))
    .returning({ id: orders.id });
  if (closed.length > 0) logEvent('order_cancelled', { order_id: orderId, booking_id: bookingId });
}

/** Бронь заказа для карточки: живая, иначе последняя; у открытого заказа — нет. */
export async function orderBookingIds(tx: DbExecutor, orderIds: string[]): Promise<Map<string, string>> {
  const out = new Map<string, string>();
  if (orderIds.length === 0) return out;
  const rows = await tx
    .select({ id: bookings.id, orderId: bookings.orderId, status: bookings.status })
    .from(bookings)
    .where(inArray(bookings.orderId, orderIds))
    .orderBy(desc(bookings.createdAt), desc(bookings.id));
  const withLive = new Set<string>();
  for (const r of rows) {
    if (!r.orderId || withLive.has(r.orderId)) continue;
    // Строки — новые сверху: первая встреченная — последняя бронь, живая её заменяет.
    if ((LIVE_BOOKING_STATUSES as readonly string[]).includes(r.status)) {
      withLive.add(r.orderId);
      out.set(r.orderId, r.id);
    } else if (!out.has(r.orderId)) {
      out.set(r.orderId, r.id);
    }
  }
  return out;
}
