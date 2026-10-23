/**
 * Общие формы чтения (`meView` — с него берут вход и профиль). Только чтение
 * базы; модули импортируют этот файл, а не друг друга. Правила — рейтинг, телефон второй стороны и
 * «Флаги поездки».
 */
import { and, asc, eq, inArray, or, sql } from 'drizzle-orm';
import type { DbExecutor } from '../db/client';
import { bookingExtras, bookings } from '../modules/bookings/internal/schema';
import { cities } from '../modules/cities/internal/schema';
import { orders } from '../modules/orders/internal/schema';
import { reviews } from '../modules/reviews/internal/schema';
import { tripExtras, tripPrices, tripStops, trips } from '../modules/trips/internal/schema';
import { users } from '../modules/users/internal/schema';
import { countCancellations30 } from './cancellations';
import { CARRIED_PARCEL_SIZES, SERVICE_KINDS, type CarriedParcelSize, type ExtraKind, type TripBadge, type TripStatus } from './enums';
import type { Booking, Me, Rating, Stop, TripCard, UserBrief } from './forms';
import { type LatLng, haversineKm } from './places';
import { segPrice } from './pricing';

/** Ссылка на загруженный файл: `/files/{id}` (относительная, клиент дописывает `API_URL`). */
export function fileUrl(id: string): string {
  return `/files/${id}`;
}

/** Действующий статус поездки: `cancelled` · `completed`, если `departs_at ≤ now` · `status`. */
export const effectiveStatusSql = sql<string>`(case when ${trips.status} = 'cancelled' then 'cancelled' when ${trips.departsAt} <= now() then 'completed' else ${trips.status}::text end)`;

/** Рейтинг — среднее `reviews.rating` адресата; 0 отзывов → `{value: 5, count: 0}`. */
export async function ratingOf(tx: DbExecutor, userIds: string[]): Promise<Map<string, Rating>> {
  const out = new Map<string, Rating>(userIds.map((id) => [id, { value: 5, count: 0 }]));
  if (userIds.length === 0) return out;
  const rows = await tx
    .select({
      id: reviews.targetId,
      value: sql<string>`avg(${reviews.rating})`,
      count: sql<number>`count(*)::int`,
    })
    .from(reviews)
    .where(inArray(reviews.targetId, userIds))
    .groupBy(reviews.targetId);
  for (const row of rows) {
    out.set(row.id, { value: Math.round(Number(row.value) * 10) / 10, count: row.count });
  }
  return out;
}

/** Порядок водителей (FR-09): с отзывами раньше безотзывных, затем рейтинг ↓. Отрицательное — `a` раньше `b`. */
export function byDriverRating(ratings: Map<string, Rating>, a: string, b: string): number {
  const reviewed = (id: string): number => ((ratings.get(id)?.count ?? 0) > 0 ? 1 : 0);
  return reviewed(b) - reviewed(a) || (ratings.get(b)?.value ?? 5) - (ratings.get(a)?.value ?? 5);
}

/**
 * «N поездок»: поездки водителя с `effectiveStatus = completed` + брони пассажира `paid`
 * на таких поездках.
 */
export async function tripsCountOf(tx: DbExecutor, userIds: string[]): Promise<Map<string, number>> {
  const out = new Map<string, number>(userIds.map((id) => [id, 0]));
  if (userIds.length === 0) return out;
  const completed = sql`${effectiveStatusSql} = 'completed'`;
  const asDriver = await tx
    .select({ id: trips.driverId, n: sql<number>`count(*)::int` })
    .from(trips)
    .where(and(inArray(trips.driverId, userIds), completed))
    .groupBy(trips.driverId);
  const asPassenger = await tx
    .select({ id: bookings.passengerId, n: sql<number>`count(*)::int` })
    .from(bookings)
    .innerJoin(trips, eq(trips.id, bookings.tripId))
    .where(and(inArray(bookings.passengerId, userIds), eq(bookings.status, 'paid'), completed))
    .groupBy(bookings.passengerId);
  for (const row of [...asDriver, ...asPassenger]) out.set(row.id, (out.get(row.id) ?? 0) + row.n);
  return out;
}

/** Форма `Me` (вход и `GET /me`); пользователя нет — `null`. */
export async function meView(tx: DbExecutor, userId: string): Promise<Me | null> {
  const [row] = await tx
    .select({ user: users, cityName: cities.name })
    .from(users)
    .leftJoin(cities, eq(cities.id, users.cityId))
    .where(eq(users.id, userId));
  if (!row) return null;
  const { user } = row;
  const [rating, tripsCount, cancelled] = await Promise.all([
    ratingOf(tx, [userId]),
    tripsCountOf(tx, [userId]),
    countCancellations30(tx, userId),
  ]);
  const blocked = user.blockedUntil && user.blockedUntil.getTime() > Date.now() ? user.blockedUntil : null;
  return {
    id: user.id,
    phone: user.phone,
    name: user.name,
    photoUrl: user.photoFileId ? fileUrl(user.photoFileId) : null,
    city: user.cityId !== null && row.cityName !== null ? { id: user.cityId, name: row.cityName } : null,
    mode: user.currentMode,
    rating: rating.get(userId) ?? { value: 5, count: 0 },
    tripsCount: tripsCount.get(userId) ?? 0,
    blockedUntil: blocked ? blocked.toISOString() : null,
    cancellationsLast30: cancelled,
  };
}


// ── Карточки поездок и брони ─────────────────────────────────────

/** Активная бронь пассажира: она занимает «моё место» в поездке и даёт `myBooking`. */
const ACTIVE_BOOKING_STATUSES = ['requested', 'awaiting_payment', 'paid'] as const;
/** Бронь принята — стороны видят телефоны друг друга. */
const ACCEPTED_BOOKING_STATUSES = ['awaiting_payment', 'paid'] as const;

const PARCEL_SIZE_OF: Partial<Record<ExtraKind, CarriedParcelSize>> = {
  parcel_s: 'S',
  parcel_m: 'M',
  parcel_l: 'L',
};

export interface ViewerOptions {
  viewerId: string;
}

export interface TripCardOptions extends ViewerOptions {
  lat?: number;
  lng?: number;
}

/** Остановка с координатами города — для расстояний, когда у точки своих нет. */
export interface StopWithCity extends Stop {
  cityLat: number;
  cityLng: number;
}

function pointOf(stop: StopWithCity): LatLng {
  return { lat: stop.lat ?? stop.cityLat, lng: stop.lng ?? stop.cityLng };
}

function toStop(s: StopWithCity): Stop {
  return {
    idx: s.idx,
    cityId: s.cityId,
    cityName: s.cityName,
    address: s.address,
    shortAddress: s.shortAddress,
    lat: s.lat,
    lng: s.lng,
  };
}

/** Остановки поездок по `idx ↑`. */
export async function tripStopsOf(tx: DbExecutor, tripIds: string[]): Promise<Map<string, StopWithCity[]>> {
  const out = new Map<string, StopWithCity[]>(tripIds.map((id) => [id, []]));
  if (tripIds.length === 0) return out;
  const rows = await tx
    .select({
      tripId: tripStops.tripId,
      idx: tripStops.idx,
      cityId: tripStops.cityId,
      cityName: cities.name,
      address: tripStops.address,
      shortAddress: sql<string>`coalesce(${tripStops.shortAddress}, ${tripStops.address})`,
      lat: tripStops.lat,
      lng: tripStops.lng,
      cityLat: cities.lat,
      cityLng: cities.lng,
    })
    .from(tripStops)
    .innerJoin(cities, eq(cities.id, tripStops.cityId))
    .where(inArray(tripStops.tripId, tripIds))
    .orderBy(asc(tripStops.tripId), asc(tripStops.idx));
  for (const { tripId, ...stop } of rows) out.get(tripId)?.push(stop);
  return out;
}

/** Краткая карточка пользователя; телефон — только второй стороне принятой брони. */
export async function userBrief(tx: DbExecutor, ids: string[], { viewerId }: ViewerOptions): Promise<UserBrief[]> {
  const unique = [...new Set(ids)];
  if (unique.length === 0) return [];
  const [rows, ratings, counts, linked] = await Promise.all([
    tx.select().from(users).where(inArray(users.id, unique)),
    ratingOf(tx, unique),
    tripsCountOf(tx, unique),
    tx
      .select({ passengerId: bookings.passengerId, driverId: trips.driverId })
      .from(bookings)
      .innerJoin(trips, eq(trips.id, bookings.tripId))
      .where(
        and(
          inArray(bookings.status, [...ACCEPTED_BOOKING_STATUSES]),
          or(
            and(eq(bookings.passengerId, viewerId), inArray(trips.driverId, unique)),
            and(eq(trips.driverId, viewerId), inArray(bookings.passengerId, unique)),
          ),
        ),
      ),
  ]);
  const phoneVisible = new Set(linked.map((l) => (l.passengerId === viewerId ? l.driverId : l.passengerId)));
  const byId = new Map(rows.map((u) => [u.id, u]));
  return ids.flatMap((id) => {
    const u = byId.get(id);
    if (!u) return [];
    return [
      {
        id: u.id,
        name: u.name,
        photoUrl: u.photoFileId ? fileUrl(u.photoFileId) : null,
        rating: ratings.get(id) ?? { value: 5, count: 0 },
        tripsCount: counts.get(id) ?? 0,
        phone: phoneVisible.has(id) ? u.phone : null,
      },
    ];
  });
}

/**
 * Первые в своей группе дублей: группа — поездки с `effectiveStatus = active`, одинаковыми
 * городами остановки 0 и последней и одинаковым `departs_at`; порядок — рейтинг водителя ↓,
 * `created_at` ↑, `id` ↑. Возвращает размер группы и признак «первая» для каждой поездки `tripIds`.
 */
async function duplicateGroups(
  tx: DbExecutor,
  tripIds: string[],
): Promise<Map<string, { size: number; first: boolean }>> {
  const out = new Map<string, { size: number; first: boolean }>();
  if (tripIds.length === 0) return out;
  const ends = sql`(select s0.city_id from trip_stops s0 where s0.trip_id = ${trips.id} and s0.idx = 0)`;
  const last = sql`(select sl.city_id from trip_stops sl where sl.trip_id = ${trips.id} order by sl.idx desc limit 1)`;
  const keyed = tx
    .select({ id: trips.id, departsAt: trips.departsAt, fromCity: sql<number>`${ends}`, toCity: sql<number>`${last}` })
    .from(trips);
  const own = await keyed.where(and(inArray(trips.id, tripIds), sql`${effectiveStatusSql} = 'active'`));
  if (own.length === 0) return out;

  const candidates = await tx
    .select({
      id: trips.id,
      driverId: trips.driverId,
      createdAt: trips.createdAt,
      departsAt: trips.departsAt,
      fromCity: sql<number>`${ends}`,
      toCity: sql<number>`${last}`,
    })
    .from(trips)
    .where(
      and(
        inArray(trips.departsAt, [...new Set(own.map((t) => t.departsAt.getTime()))].map((ms) => new Date(ms))),
        sql`${effectiveStatusSql} = 'active'`,
      ),
    );
  const ratings = await ratingOf(tx, [...new Set(candidates.map((c) => c.driverId))]);
  const keyOf = (t: { fromCity: number; toCity: number; departsAt: Date }): string =>
    `${t.fromCity}|${t.toCity}|${t.departsAt.getTime()}`;
  const groups = new Map<string, typeof candidates>();
  for (const c of candidates) groups.set(keyOf(c), [...(groups.get(keyOf(c)) ?? []), c]);
  for (const group of groups.values()) {
    group.sort(
      (a, b) =>
        byDriverRating(ratings, a.driverId, b.driverId) ||
        a.createdAt.getTime() - b.createdAt.getTime() ||
        (a.id < b.id ? -1 : a.id > b.id ? 1 : 0),
    );
  }
  for (const t of own) {
    const group = groups.get(keyOf(t)) ?? [];
    out.set(t.id, { size: Math.max(group.length, 1), first: group[0]?.id === t.id });
  }
  return out;
}

/** «Топ» («Базовые экраны - Поездки есть», «Базовые экраны - Идёт регистрация пассажиров»): рейтинг водителя (как в карточке, до десятых) не ниже порога и не меньше стольких отзывов. */
export const TOP_RATING = 4.8;
export const TOP_REVIEWS = 5;

/**
 * Плашка карточки, не больше одной: «Ближайший» — одна карточка выдачи с наименьшим `distanceKm`
 * (только при координатах клиента; при равенстве — первая по порядку выдачи), иначе «Топ».
 */
function withBadges(cards: TripCard[]): TripCard[] {
  let nearest: TripCard | undefined;
  for (const c of cards) {
    if (typeof c.distanceKm === 'number' && (nearest === undefined || c.distanceKm < (nearest.distanceKm as number))) nearest = c;
  }
  return cards.map((c) => {
    const { value, count } = c.driver.rating;
    const badge: TripBadge | null =
      c === nearest ? 'nearest' : value >= TOP_RATING && count >= TOP_REVIEWS ? 'top' : null;
    return { ...c, badge };
  });
}

/** Карточки поездок в порядке `tripIds` (несуществующие пропускаются); поля — «Флаги поездки». */
export async function tripCards(tx: DbExecutor, tripIds: string[], options: TripCardOptions): Promise<TripCard[]> {
  const ids = [...new Set(tripIds)];
  if (ids.length === 0) return [];
  const { viewerId } = options;
  const rows = await tx
    .select({ trip: trips, effectiveStatus: effectiveStatusSql })
    .from(trips)
    .where(inArray(trips.id, ids));
  const [stops, extras, groups, mine] = await Promise.all([
    tripStopsOf(tx, ids),
    tx.select().from(tripExtras).where(inArray(tripExtras.tripId, ids)),
    duplicateGroups(tx, ids),
    tx
      .select({ tripId: bookings.tripId })
      .from(bookings)
      .where(
        and(
          inArray(bookings.tripId, ids),
          eq(bookings.passengerId, viewerId),
          inArray(bookings.status, [...ACTIVE_BOOKING_STATUSES]),
        ),
      ),
  ]);
  const drivers = await userBrief(tx, [...new Set(rows.map((r) => r.trip.driverId))], { viewerId });
  const driverById = new Map(drivers.map((d) => [d.id, d]));
  const withMyBooking = new Set(mine.map((m) => m.tripId));
  const hasPoint = typeof options.lat === 'number' && typeof options.lng === 'number';
  const byId = new Map(rows.map((r) => [r.trip.id, r]));

  const cards = tripIds.flatMap((id): TripCard[] => {
    const row = byId.get(id);
    const tripStopsList = stops.get(id) ?? [];
    if (!row || tripStopsList.length === 0) return [];
    const { trip } = row;
    const effectiveStatus = row.effectiveStatus as TripStatus;
    const kinds = extras.filter((e) => e.tripId === id).map((e) => e.kind);
    const parcelSizes = CARRIED_PARCEL_SIZES.filter((size) => kinds.some((k) => PARCEL_SIZE_OF[k] === size));
    const parcelAllowed = parcelSizes.length > 0;
    const seatsFree = trip.seatsTotal - trip.seatsTaken;
    const parcelSeatsFree = trip.parcelSeatsTotal - trip.parcelSeatsTaken;
    const group = groups.get(id);
    const registrationOpen = effectiveStatus === 'active' && (group?.first ?? true);
    const isOwn = trip.driverId === viewerId;
    const free = !isOwn && !withMyBooking.has(id);
    const start = tripStopsList[0];
    const finish = tripStopsList[tripStopsList.length - 1];
    return [
      {
        id: trip.id,
        number: trip.number,
        kind: trip.kind,
        from: toStop(start),
        to: toStop(finish),
        stopsCount: tripStopsList.length - 2,
        departsAt: trip.departsAt.toISOString(),
        arrivesAt: trip.arrivesAt.toISOString(),
        seatsFree,
        seatsTotal: trip.seatsTotal,
        parcelSeatsFree,
        parcelSeatsTotal: trip.parcelSeatsTotal,
        price: trip.priceFull,
        distanceKm: hasPoint
          ? haversineKm({ lat: options.lat as number, lng: options.lng as number }, pointOf(start))
          : null,
        driver: driverById.get(trip.driverId) as UserBrief,
        extras: SERVICE_KINDS.filter((k) => kinds.includes(k)),
        parcelAllowed,
        parcelSizes,
        duplicates: group?.size ?? 1,
        registrationOpen,
        bookable: registrationOpen && seatsFree > 0 && free,
        parcelBookable:
          registrationOpen && parcelAllowed && parcelSeatsFree > 0 && (seatsFree > 0 || trip.parcelOnlyAllowed) && free,
        effectiveStatus,
      },
    ];
  });
  return withBadges(cards);
}

/** Брони целиком (форма `Booking`) в порядке `bookingIds`; `trip` — карточка для того же зрителя. */
export async function bookingViews(tx: DbExecutor, bookingIds: string[], { viewerId }: ViewerOptions): Promise<Booking[]> {
  const ids = [...new Set(bookingIds)];
  if (ids.length === 0) return [];
  const rows = await tx.select().from(bookings).where(inArray(bookings.id, ids));
  const tripIds = [...new Set(rows.map((b) => b.tripId))];
  const orderIds = [...new Set(rows.flatMap((b) => (b.orderId ? [b.orderId] : [])))];
  const [extras, cards, stops, prices, tripRows, passengers, orderRows] = await Promise.all([
    tx.select().from(bookingExtras).where(inArray(bookingExtras.bookingId, ids)),
    tripCards(tx, tripIds, { viewerId }),
    tripStopsOf(tx, tripIds),
    tripIds.length ? tx.select().from(tripPrices).where(inArray(tripPrices.tripId, tripIds)) : Promise.resolve([]),
    tx.select({ id: trips.id, priceFull: trips.priceFull }).from(trips).where(inArray(trips.id, tripIds)),
    userBrief(tx, [...new Set(rows.map((b) => b.passengerId))], { viewerId }),
    orderIds.length ? tx.select({ id: orders.id, number: orders.number }).from(orders).where(inArray(orders.id, orderIds)) : Promise.resolve([]),
  ]);
  const orderNumberById = new Map(orderRows.map((o) => [o.id, o.number]));
  const cardById = new Map(cards.map((c) => [c.id, c]));
  const priceFullById = new Map(tripRows.map((t) => [t.id, t.priceFull]));
  const passengerById = new Map(passengers.map((p) => [p.id, p]));
  const byId = new Map(rows.map((b) => [b.id, b]));

  return bookingIds.flatMap((id) => {
    const b = byId.get(id);
    const card = b ? cardById.get(b.tripId) : undefined;
    const tripStopsList = b ? (stops.get(b.tripId) ?? []) : [];
    const from = tripStopsList.find((s) => s.idx === b?.fromIdx);
    const to = tripStopsList.find((s) => s.idx === b?.toIdx);
    if (!b || !card || !from || !to) return [];
    return [
      {
        id: b.id,
        number: b.number,
        status: b.status,
        seats: b.seats,
        fromIdx: b.fromIdx,
        toIdx: b.toIdx,
        from: toStop(from),
        to: toStop(to),
        // Цена отрезка — та же `segPrice`, что считает бронь; нет цены — 0.
        segmentPrice:
          segPrice(
            {
              priceFull: priceFullById.get(b.tripId) ?? card.price,
              stopsCount: tripStopsList.length,
              prices: prices.filter((p) => p.tripId === b.tripId),
              extras: [],
            },
            b.fromIdx,
            b.toIdx,
          ) ?? 0,
        parcelSize: b.parcelSize,
        parcelOnly: b.parcelOnly,
        parcelComment: b.parcelComment,
        extras: extras.filter((e) => e.bookingId === id).map((e) => ({ kind: e.kind, price: e.price })),
        priceTotal: b.priceTotal,
        segmentKm: haversineKm(pointOf(from), pointOf(to)),
        createdAt: b.createdAt.toISOString(),
        paidAt: b.paidAt ? b.paidAt.toISOString() : null,
        trip: card,
        passenger: passengerById.get(b.passengerId) as UserBrief,
        orderId: b.orderId,
        orderNumber: b.orderId ? (orderNumberById.get(b.orderId) ?? null) : null,
      },
    ];
  });
}
