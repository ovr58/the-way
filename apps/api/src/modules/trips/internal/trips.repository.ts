/**
 * Чтение и запись таблиц поездок (строка A1): детали поездки, остановки, цены, услуги.
 * Чужие таблицы — импортом их `schema.ts`; бизнес-правила — в `trip-validation.ts`.
 */
import { and, asc, eq, inArray, isNull, sql } from 'drizzle-orm';
import type { Car, Stop } from '../../../common/forms';
import { bookingViews, fileUrl, tripCards, tripStopsOf, type StopWithCity } from '../../../common/views';
import type { DbExecutor } from '../../../db/client';
import { bookings } from '../../bookings/internal/schema';
import { carDocuments, cars, normalizePlate } from '../../cars/internal/schema';
import { tripExtras, tripPrices, tripStops, trips } from './schema';
import type { TripDetails } from './trips.dto';

export type TripRow = typeof trips.$inferSelect;

/** Присоединившийся пассажир = бронь `awaiting_payment` или `paid`; есть такая — правка закрыта. */
export const JOINED_STATUSES = ['awaiting_payment', 'paid'] as const;

export async function isEditLocked(tx: DbExecutor, tripId: string): Promise<boolean> {
  const [row] = await tx
    .select({ id: bookings.id })
    .from(bookings)
    .where(and(eq(bookings.tripId, tripId), inArray(bookings.status, [...JOINED_STATUSES])))
    .limit(1);
  return row !== undefined;
}

/** Строка поездки; `forUpdate` держит её до конца транзакции. */
export async function findTrip(tx: DbExecutor, tripId: string, forUpdate = false): Promise<TripRow | undefined> {
  const query = tx.select().from(trips).where(eq(trips.id, tripId));
  const [row] = await (forUpdate ? query.for('update') : query);
  return row;
}

export function plainStop(s: StopWithCity): Stop {
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

async function carOf(tx: DbExecutor, carId: string): Promise<Car> {
  const [car] = await tx.select().from(cars).where(eq(cars.id, carId));
  const docs = await tx.select().from(carDocuments).where(eq(carDocuments.carId, carId)).orderBy(asc(carDocuments.createdAt));
  return {
    id: car.id,
    brand: car.brand,
    model: car.model,
    kind: car.kind,
    seats: car.seats,
    plate: normalizePlate(car.plate),
    photoUrl: car.photoFileId ? fileUrl(car.photoFileId) : null,
    status: car.status,
    documents: docs.map((d) => ({ id: d.id, kind: d.kind, url: fileUrl(d.fileId) })),
  };
}

/** `TripDetails` для зрителя; поездки нет — `null`. */
export async function tripDetails(tx: DbExecutor, tripId: string, viewerId: string): Promise<TripDetails | null> {
  const trip = await findTrip(tx, tripId);
  const [card] = trip ? await tripCards(tx, [tripId], { viewerId }) : [];
  if (!trip || !card) return null;
  const isMine = trip.driverId === viewerId;
  const [stops, prices, extras, car, locked, mine, paid] = await Promise.all([
    tripStopsOf(tx, [tripId]),
    tx.select().from(tripPrices).where(eq(tripPrices.tripId, tripId)).orderBy(asc(tripPrices.fromIdx), asc(tripPrices.toIdx)),
    tx.select().from(tripExtras).where(eq(tripExtras.tripId, tripId)),
    carOf(tx, trip.carId),
    isEditLocked(tx, tripId),
    tx
      .select({ id: bookings.id })
      .from(bookings)
      .where(
        and(
          eq(bookings.tripId, tripId),
          eq(bookings.passengerId, viewerId),
          inArray(bookings.status, ['requested', 'awaiting_payment', 'paid']),
        ),
      )
      .limit(1),
    isMine
      ? tx
          .select({ total: sql<number>`coalesce(sum(${bookings.priceTotal}), 0)::int` })
          .from(bookings)
          .where(and(eq(bookings.tripId, tripId), eq(bookings.status, 'paid')))
      : Promise.resolve([]),
  ]);
  const [myBooking] = mine.length ? await bookingViews(tx, [mine[0].id], { viewerId }) : [];
  return {
    ...card,
    stops: (stops.get(tripId) ?? []).map(plainStop),
    prices: prices.map((p) => ({ fromIdx: p.fromIdx, toIdx: p.toIdx, price: p.price })),
    priceBoardingMin: trip.priceBoardingMin,
    extrasPriced: extras.map((e) => ({ kind: e.kind, price: e.price })),
    parcelOnlyAllowed: trip.parcelOnlyAllowed,
    bookingMode: trip.bookingMode,
    car,
    isMine,
    editLocked: locked,
    myBooking: myBooking ?? null,
    reverseOf: trip.reverseOf,
    paidTotal: isMine ? (paid[0]?.total ?? 0) : null,
  };
}

/** Остановки, цены и услуги поездки в форме входа (для слияния при правке и для обратной). */
export async function tripBody(tx: DbExecutor, tripId: string) {
  const [stops, prices, extras] = await Promise.all([
    tripStopsOf(tx, [tripId]),
    tx.select().from(tripPrices).where(eq(tripPrices.tripId, tripId)),
    tx.select().from(tripExtras).where(eq(tripExtras.tripId, tripId)),
  ]);
  return {
    stops: (stops.get(tripId) ?? []).map((s) => ({
      cityId: s.cityId,
      address: s.address,
      shortAddress: s.shortAddress,
      lat: s.lat,
      lng: s.lng,
    })),
    prices: prices.map((p) => ({ fromIdx: p.fromIdx, toIdx: p.toIdx, price: p.price })),
    extras: extras.map((e) => ({ kind: e.kind, price: e.price })),
  };
}

export interface ResolvedStop {
  cityId: number;
  address: string;
  shortAddress: string | null;
  lat: number | null;
  lng: number | null;
}

/** Заменяет остановки, цены отрезков и услуги поездки целиком. */
export async function writeTripParts(
  tx: DbExecutor,
  tripId: string,
  parts: {
    stops: ResolvedStop[];
    prices: { fromIdx: number; toIdx: number; price: number }[];
    extras: { kind: (typeof tripExtras.$inferInsert)['kind']; price: number }[];
  },
): Promise<void> {
  await tx.delete(tripStops).where(eq(tripStops.tripId, tripId));
  await tx.delete(tripPrices).where(eq(tripPrices.tripId, tripId));
  await tx.delete(tripExtras).where(eq(tripExtras.tripId, tripId));
  await tx.insert(tripStops).values(parts.stops.map((s, idx) => ({ tripId, idx, ...s })));
  if (parts.prices.length) await tx.insert(tripPrices).values(parts.prices.map((p) => ({ tripId, ...p })));
  if (parts.extras.length) await tx.insert(tripExtras).values(parts.extras.map((e) => ({ tripId, ...e })));
}

/** Свободное авто водителя: не удалено (для проверок, где нужна сама строка). */
export async function findOwnCar(tx: DbExecutor, ownerId: string, carId: string) {
  const [row] = await tx
    .select()
    .from(cars)
    .where(and(eq(cars.id, carId), eq(cars.ownerId, ownerId), isNull(cars.deletedAt)));
  return row;
}

/** Число мест авто (в том числе удалённого — поездка ссылается на него по id). */
export async function carSeatsOf(tx: DbExecutor, carId: string): Promise<number> {
  const [row] = await tx.select({ seats: cars.seats }).from(cars).where(eq(cars.id, carId));
  return row.seats;
}
