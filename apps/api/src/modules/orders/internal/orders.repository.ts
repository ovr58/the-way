/**
 * Чтение и запись заказов: строки `orders`, точки, услуги и формы `OrderCard`/`OrderDetails` (план
 * passenger-order, «Контракт» — «Формы»). Пассажир — `userBrief`, расстояние — как у ленты поездок.
 */
import { and, asc, eq, inArray, sql } from 'drizzle-orm';
import { SERVICE_KINDS, type ServiceKind } from '../../../common/enums';
import type { Stop } from '../../../common/forms';
import { orderBookingIds, orderStatusSql } from '../../../common/order-response';
import { type LatLng, haversineKm } from '../../../common/places';
import { userBrief } from '../../../common/views';
import type { DbExecutor, Transaction } from '../../../db/client';
import { cities } from '../../cities/internal/schema';
import type { OrderCard } from './orders.dto';
import { orderExtras, orderStops, orders } from './schema';

/** Точка заказа с координатами города — для расстояния, когда у точки своих нет. */
export interface OrderStop extends Stop {
  cityLat: number;
  cityLng: number;
}

export function pointOf(stop: OrderStop): LatLng {
  return { lat: stop.lat ?? stop.cityLat, lng: stop.lng ?? stop.cityLng };
}

export function plainStop(s: OrderStop): Stop {
  return { idx: s.idx, cityId: s.cityId, cityName: s.cityName, address: s.address, shortAddress: s.shortAddress, lat: s.lat, lng: s.lng };
}

/** Точки заказов по `idx ↑`. */
export async function orderStopsOf(tx: DbExecutor, orderIds: string[]): Promise<Map<string, OrderStop[]>> {
  const out = new Map<string, OrderStop[]>(orderIds.map((id) => [id, []]));
  if (orderIds.length === 0) return out;
  const rows = await tx
    .select({
      orderId: orderStops.orderId,
      idx: orderStops.idx,
      cityId: orderStops.cityId,
      cityName: cities.name,
      address: orderStops.address,
      shortAddress: sql<string>`coalesce(${orderStops.shortAddress}, ${orderStops.address})`,
      lat: orderStops.lat,
      lng: orderStops.lng,
      cityLat: cities.lat,
      cityLng: cities.lng,
    })
    .from(orderStops)
    .innerJoin(cities, eq(cities.id, orderStops.cityId))
    .where(inArray(orderStops.orderId, orderIds))
    .orderBy(asc(orderStops.orderId), asc(orderStops.idx));
  for (const { orderId, ...stop } of rows) out.get(orderId)?.push(stop);
  return out;
}

export interface CardOptions {
  viewerId: string;
  lat?: number;
  lng?: number;
}

/** Карточки заказов в порядке `orderIds`. */
export async function orderCards(tx: DbExecutor, orderIds: string[], options: CardOptions): Promise<OrderCard[]> {
  const ids = [...new Set(orderIds)];
  if (ids.length === 0) return [];
  const [rows, stops, extras, bookingOf] = await Promise.all([
    tx.select({ order: orders, status: orderStatusSql }).from(orders).where(inArray(orders.id, ids)),
    orderStopsOf(tx, ids),
    tx.select().from(orderExtras).where(inArray(orderExtras.orderId, ids)),
    orderBookingIds(tx, ids),
  ]);
  const passengers = await userBrief(tx, [...new Set(rows.map((r) => r.order.passengerId))], { viewerId: options.viewerId });
  const passengerById = new Map(passengers.map((p) => [p.id, p]));
  const byId = new Map(rows.map((r) => [r.order.id, r]));
  const hasPoint = typeof options.lat === 'number' && typeof options.lng === 'number';

  return orderIds.flatMap((id): OrderCard[] => {
    const row = byId.get(id);
    const list = stops.get(id) ?? [];
    const passenger = row ? passengerById.get(row.order.passengerId) : undefined;
    if (!row || list.length < 2 || !passenger) return [];
    const { order } = row;
    const kinds = extras.filter((e) => e.orderId === id).map((e) => e.kind);
    const start = list[0];
    return [
      {
        id: order.id,
        number: order.number,
        kind: order.kind,
        from: plainStop(start),
        to: plainStop(list[list.length - 1]),
        stopsCount: list.length - 2,
        departsAt: order.departsAt.toISOString(),
        arrivesAt: order.arrivesAt.toISOString(),
        seats: order.seats,
        parcelSize: order.parcelSize,
        parcelOnly: order.kind === 'parcel',
        parcelComment: order.parcelComment,
        extras: SERVICE_KINDS.filter((k) => kinds.includes(k)),
        passenger,
        distanceKm: hasPoint ? haversineKm({ lat: options.lat as number, lng: options.lng as number }, pointOf(start)) : null,
        status: row.status,
        bookingId: row.status === 'open' ? null : (bookingOf.get(id) ?? null),
        createdAt: order.createdAt.toISOString(),
      },
    ];
  });
}

export interface NewOrder {
  passengerId: string;
  kind: OrderCard['kind'];
  departsAt: Date;
  arrivesAt: Date;
  seats: number;
  parcelSize: OrderCard['parcelSize'];
  parcelComment: string | null;
  stops: { cityId: number; address: string; shortAddress: string | null; lat: number | null; lng: number | null }[];
  services: ServiceKind[];
}

/** Строка заказа, точки и услуги; возвращает id. */
export async function insertOrder(tx: Transaction, data: NewOrder): Promise<string> {
  const [row] = await tx
    .insert(orders)
    .values({
      passengerId: data.passengerId,
      kind: data.kind,
      departsAt: data.departsAt,
      arrivesAt: data.arrivesAt,
      seats: data.seats,
      parcelSize: data.parcelSize,
      parcelComment: data.parcelComment,
    })
    .returning({ id: orders.id });
  await tx.insert(orderStops).values(data.stops.map((s, idx) => ({ orderId: row.id, idx, ...s })));
  if (data.services.length > 0) await tx.insert(orderExtras).values(data.services.map((kind) => ({ orderId: row.id, kind })));
  return row.id;
}

/** Открытые заказы ленты водителя: не свои, выезд впереди; фильтры — города первой и последней точки, вид. */
export async function feedOrderIds(
  tx: DbExecutor,
  viewerId: string,
  filter: { fromCityId?: number; toCityId?: number; kind?: OrderCard['kind'] },
): Promise<{ id: string; departsAt: Date }[]> {
  const conditions = [sql`${orderStatusSql} = 'open'`, sql`${orders.passengerId} <> ${viewerId}`];
  if (filter.kind) conditions.push(eq(orders.kind, filter.kind));
  if (filter.fromCityId !== undefined) {
    conditions.push(sql`exists (select 1 from order_stops s where s.order_id = ${orders.id} and s.idx = 0 and s.city_id = ${filter.fromCityId})`);
  }
  if (filter.toCityId !== undefined) {
    conditions.push(
      sql`exists (select 1 from order_stops s where s.order_id = ${orders.id} and s.city_id = ${filter.toCityId} and s.idx = (select max(m.idx) from order_stops m where m.order_id = ${orders.id}))`,
    );
  }
  return tx
    .select({ id: orders.id, departsAt: orders.departsAt })
    .from(orders)
    .where(and(...conditions))
    .orderBy(asc(orders.departsAt), asc(orders.id));
}
