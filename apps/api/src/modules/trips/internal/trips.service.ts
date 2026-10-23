import { Inject, Injectable } from '@nestjs/common';
import { and, asc, eq, inArray, ne, sql } from 'drizzle-orm';
import { logEvent } from '../../../common/logger';
import { AppError } from '../../../common/errors';
import type { CancelPreview, CancelResult, TripCard } from '../../../common/forms';
import { respondToOrder } from '../../../common/order-response';
import { haversineKm, SAME_PLACE_KM } from '../../../common/places';
import { byDriverRating, effectiveStatusSql, fileUrl, ratingOf, tripCards, tripStopsOf } from '../../../common/views';
import { DATABASE, type Database, type Transaction } from '../../../db/client';
import { bookings } from '../../bookings/internal/schema';
import { users } from '../../users/internal/schema';
import { trips } from './schema';
import { WEEKLY_LIMIT, assertWithinLimit, usedInWeek, usedOnDay } from './limits';
import * as templates from './route-templates';
import { cancelTrip, previewTripCancel } from './trip-cancel';
import { MAX_DAYS_AHEAD } from '../../../common/trip-times';
import { checkSeats, validateTrip, type TripData } from './trip-validation';
import {
  carSeatsOf,
  findTrip,
  isEditLocked,
  tripBody,
  tripDetails,
  writeTripParts,
  type ResolvedStop,
  type TripRow,
} from './trips.repository';
import type {
  DriverTripCard,
  MyTripsQuery,
  ReverseInput,
  RouteTemplate,
  RouteTemplateInput,
  SeatsInput,
  TripDetails,
  TripInput,
  TripLimits,
  TripLimitsQuery,
  TripPatch,
  TripSearchQuery,
} from './trips.dto';

/** Поездки, лимиты, обратная поездка, места, отмена, шаблоны маршрутов (строка A1). */
@Injectable()
export class TripsService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  /** Лента: активные чужие поездки; порядок — рейтинг водителя ↓, `departs_at` ↑, `id` ↑. */
  async search(viewerId: string, query: TripSearchQuery): Promise<TripCard[]> {
    const { fromCityId: from, toCityId: to } = query;
    const conditions = [
      sql`${effectiveStatusSql} = 'active'`,
      ne(trips.driverId, viewerId),
      eq(trips.vehicleKind, query.vehicleKind ?? 'car'),
    ];
    if (query.kind) conditions.push(eq(trips.kind, query.kind));
    // «откуда» стоит раньше «куда» (остановки по `idx`); одно из двух — раньше/позже любой другой остановки.
    if (from !== undefined && to !== undefined) {
      conditions.push(
        sql`exists (select 1 from trip_stops a join trip_stops b on b.trip_id = a.trip_id and b.idx > a.idx where a.trip_id = ${trips.id} and a.city_id = ${from} and b.city_id = ${to})`,
      );
    } else if (from !== undefined) {
      conditions.push(
        sql`exists (select 1 from trip_stops a where a.trip_id = ${trips.id} and a.city_id = ${from} and a.idx < (select max(m.idx) from trip_stops m where m.trip_id = ${trips.id}))`,
      );
    } else if (to !== undefined) {
      conditions.push(sql`exists (select 1 from trip_stops b where b.trip_id = ${trips.id} and b.city_id = ${to} and b.idx > 0)`);
    }
    let rows = await this.db
      .select({ id: trips.id, driverId: trips.driverId, departsAt: trips.departsAt })
      .from(trips)
      .where(and(...conditions));

    if (query.near && typeof query.lat === 'number' && typeof query.lng === 'number') {
      const stops = await tripStopsOf(this.db, rows.map((r) => r.id));
      const point = { lat: query.lat, lng: query.lng };
      rows = rows.filter((r) => {
        const start = stops.get(r.id)?.[0];
        if (!start) return false;
        return haversineKm(point, { lat: start.lat ?? start.cityLat, lng: start.lng ?? start.cityLng }) <= SAME_PLACE_KM;
      });
    }

    const ratings = await ratingOf(this.db, [...new Set(rows.map((r) => r.driverId))]);
    rows.sort(
      (a, b) =>
        byDriverRating(ratings, a.driverId, b.driverId) ||
        a.departsAt.getTime() - b.departsAt.getTime() ||
        (a.id < b.id ? -1 : a.id > b.id ? 1 : 0),
    );
    return tripCards(this.db, rows.map((r) => r.id), { viewerId, lat: query.lat, lng: query.lng });
  }

  /** «Мои поездки» водителя: `active` — активные и с закрытым приёмом, `completed` — остальные. */
  async mine(viewerId: string, query: MyTripsQuery): Promise<DriverTripCard[]> {
    const open = sql`${effectiveStatusSql} in ('active', 'intake_closed')`;
    const isActive = query.status === 'active';
    const rows = await this.db
      .select({ id: trips.id })
      .from(trips)
      .where(and(eq(trips.driverId, viewerId), isActive ? open : sql`not (${open})`))
      .orderBy(isActive ? asc(trips.departsAt) : sql`${trips.departsAt} desc`, asc(trips.id));
    const ids = rows.map((r) => r.id);
    const cards = await tripCards(this.db, ids, { viewerId });
    const live = ids.length
      ? await this.db
          .select({
            tripId: bookings.tripId,
            status: bookings.status,
            passengerId: bookings.passengerId,
            parcelSize: bookings.parcelSize,
            photoFileId: users.photoFileId,
          })
          .from(bookings)
          .innerJoin(users, eq(users.id, bookings.passengerId))
          .where(and(inArray(bookings.tripId, ids), inArray(bookings.status, ['requested', 'awaiting_payment', 'paid'])))
          .orderBy(asc(bookings.createdAt), asc(bookings.id))
      : [];
    return cards.map((card) => {
      const own = live.filter((b) => b.tripId === card.id);
      return {
        ...card,
        requested: own.filter((b) => b.status === 'requested').length,
        awaitingPayment: own.filter((b) => b.status === 'awaiting_payment').length,
        paid: own.filter((b) => b.status === 'paid').length,
        parcels: own.filter((b) => b.parcelSize !== 'none').length,
        responders: own.slice(0, 2).map((b) => ({ id: b.passengerId, photoUrl: b.photoFileId ? fileUrl(b.photoFileId) : null })),
      };
    });
  }

  async limits(viewerId: string, query: TripLimitsQuery): Promise<TripLimits> {
    if (Number.isNaN(Date.parse(query.date))) throw new AppError('validation', 'Некорректная дата');
    const day = sql`${query.date}::date`;
    const [used, weekUsed] = await Promise.all([
      // Лимит — на водителя по всем его авто: `carId` запроса для подсчёта не нужен.
      usedOnDay(this.db, viewerId, day),
      usedInWeek(this.db, viewerId, day),
    ]);
    return { ...used, weekUsed, weekLimit: WEEKLY_LIMIT, maxDaysAhead: MAX_DAYS_AHEAD };
  }

  async details(viewerId: string, tripId: string): Promise<TripDetails> {
    const details = await tripDetails(this.db, tripId, viewerId);
    if (!details) throw new AppError('not_found', 'Поездка не найдена');
    return details;
  }

  /** Публикация; с `orderId` — отклик новой поездкой: поездка и бронь пассажира одной транзакцией. */
  async create(viewerId: string, body: TripInput): Promise<TripDetails> {
    return this.db.transaction(async (tx) => {
      const data: TripData = {
        ...body,
        departsAt: new Date(body.departsAt),
        arrivesAt: new Date(body.arrivesAt),
      };
      const stops = await validateTrip(tx, viewerId, data);
      await assertWithinLimit(tx, { driverId: viewerId, carId: data.carId, departsAt: data.departsAt, reverse: false });
      const tripId = await insertTrip(tx, viewerId, data, stops, null);
      if (body.orderId) await respondToOrder(tx, { orderId: body.orderId, tripId, driverId: viewerId, via: 'new_trip' });
      logEvent('trip_published', { trip_id: tripId, car_id: data.carId });
      return (await tripDetails(tx, tripId, viewerId)) as TripDetails;
    });
  }

  /** Правка: проверяется результат слияния «текущая + тело»; после присоединившегося — `edit_locked`. */
  async update(viewerId: string, tripId: string, body: TripPatch): Promise<TripDetails> {
    return this.db.transaction(async (tx) => {
      const trip = await ownTrip(tx, viewerId, tripId);
      if (await isEditLocked(tx, tripId)) throw new AppError('edit_locked', 'Редактирование недоступно');
      if (body.stops && !body.prices) throw new AppError('validation', 'После правки маршрута нужны цены отрезков');
      const current = await tripBody(tx, tripId);
      const data: TripData = {
        kind: body.kind ?? trip.kind,
        vehicleKind: body.vehicleKind ?? trip.vehicleKind,
        stops: body.stops ?? current.stops,
        departsAt: body.departsAt ? new Date(body.departsAt) : trip.departsAt,
        arrivesAt: body.arrivesAt ? new Date(body.arrivesAt) : trip.arrivesAt,
        seatsTotal: body.seatsTotal ?? trip.seatsTotal,
        priceFull: body.priceFull ?? trip.priceFull,
        prices: body.prices ?? current.prices,
        priceBoardingMin: body.priceBoardingMin ?? trip.priceBoardingMin,
        carId: body.carId ?? trip.carId,
        extras: body.extras ?? current.extras,
        parcelOnlyAllowed: body.parcelOnlyAllowed ?? trip.parcelOnlyAllowed,
        parcelSeatsTotal: body.parcelSeatsTotal ?? trip.parcelSeatsTotal,
        bookingMode: body.bookingMode ?? trip.bookingMode,
      };
      const stops = await validateTrip(tx, viewerId, data, { seats: trip.seatsTaken, parcelSeats: trip.parcelSeatsTaken });
      await assertWithinLimit(tx, {
        driverId: viewerId,
        carId: data.carId,
        departsAt: data.departsAt,
        reverse: trip.reverseOf !== null,
        excludeTripId: tripId,
      });
      await tx
        .update(trips)
        .set({
          carId: data.carId,
          kind: data.kind,
          vehicleKind: data.vehicleKind,
          departsAt: data.departsAt,
          arrivesAt: data.arrivesAt,
          seatsTotal: data.seatsTotal,
          priceFull: data.priceFull,
          priceBoardingMin: data.priceBoardingMin,
          bookingMode: data.bookingMode,
          parcelOnlyAllowed: data.parcelOnlyAllowed,
          parcelSeatsTotal: data.parcelSeatsTotal,
        })
        .where(eq(trips.id, tripId));
      await writeTripParts(tx, tripId, { stops, prices: data.prices, extras: data.extras });
      logEvent('trip_updated', { trip_id: tripId, car_id: data.carId });
      return (await tripDetails(tx, tripId, viewerId)) as TripDetails;
    });
  }

  /** Обратная: те же остановки наоборот, цены `(i, j) → (n−1−j, n−1−i)`, новое время, `reverse_of`. */
  async reverse(viewerId: string, tripId: string, body: ReverseInput): Promise<TripDetails> {
    return this.db.transaction(async (tx) => {
      const trip = await findTrip(tx, tripId);
      if (!trip) throw new AppError('not_found', 'Поездка не найдена');
      if (trip.driverId !== viewerId) throw new AppError('forbidden', 'Чужая поездка');
      const parts = await tripBody(tx, tripId);
      const last = parts.stops.length - 1;
      const data: TripData = {
        kind: trip.kind,
        vehicleKind: trip.vehicleKind,
        stops: [...parts.stops].reverse(),
        departsAt: new Date(body.departsAt),
        arrivesAt: new Date(body.arrivesAt),
        seatsTotal: trip.seatsTotal,
        priceFull: trip.priceFull,
        prices: parts.prices.map((p) => ({ fromIdx: last - p.toIdx, toIdx: last - p.fromIdx, price: p.price })),
        priceBoardingMin: trip.priceBoardingMin,
        carId: trip.carId,
        extras: parts.extras,
        parcelOnlyAllowed: trip.parcelOnlyAllowed,
        parcelSeatsTotal: trip.parcelSeatsTotal,
        bookingMode: trip.bookingMode,
      };
      const stops = await validateTrip(tx, viewerId, data);
      await assertWithinLimit(tx, { driverId: viewerId, carId: data.carId, departsAt: data.departsAt, reverse: true });
      const newId = await insertTrip(tx, viewerId, data, stops, tripId);
      logEvent('trip_reversed', { trip_id: newId, car_id: data.carId, reverse_of: tripId });
      return (await tripDetails(tx, newId, viewerId)) as TripDetails;
    });
  }

  /** Число мест — не ниже занятых и в пределах мест авто. */
  async setSeats(viewerId: string, tripId: string, body: SeatsInput): Promise<TripDetails> {
    return this.db.transaction(async (tx) => {
      const trip = await ownTrip(tx, viewerId, tripId);
      if (body.seatsTotal < trip.seatsTaken) throw new AppError('seats_below_taken', 'Мест меньше, чем занято');
      checkSeats(trip.kind, body.seatsTotal, await carSeatsOf(tx, trip.carId));
      await tx.update(trips).set({ seatsTotal: body.seatsTotal }).where(eq(trips.id, tripId));
      logEvent('trip_seats_changed', { trip_id: tripId, car_id: trip.carId, seats_total: body.seatsTotal });
      return (await tripDetails(tx, tripId, viewerId)) as TripDetails;
    });
  }

  /** «Завершить приём» — `active` → `intake_closed`; повтор ничего не меняет. */
  async closeIntake(viewerId: string, tripId: string): Promise<TripDetails> {
    return this.db.transaction(async (tx) => {
      const trip = await ownTrip(tx, viewerId, tripId);
      if (trip.status === 'active' && trip.departsAt.getTime() > Date.now()) {
        await tx.update(trips).set({ status: 'intake_closed' }).where(eq(trips.id, tripId));
        logEvent('trip_intake_closed', { trip_id: tripId, car_id: trip.carId });
      } else if (trip.status !== 'intake_closed') {
        throw new AppError('invalid_transition', 'Приём уже нельзя завершить');
      }
      return (await tripDetails(tx, tripId, viewerId)) as TripDetails;
    });
  }

  async cancelPreview(viewerId: string, tripId: string): Promise<CancelPreview> {
    const trip = await findTrip(this.db, tripId);
    if (!trip) throw new AppError('not_found', 'Поездка не найдена');
    if (trip.driverId !== viewerId) throw new AppError('forbidden', 'Чужая поездка');
    return previewTripCancel(this.db, viewerId, tripId);
  }

  async cancel(viewerId: string, tripId: string): Promise<CancelResult> {
    return this.db.transaction(async (tx) => {
      const trip = await ownTrip(tx, viewerId, tripId);
      const { result, joinedPassengers } = await cancelTrip(tx, viewerId, trip);
      logEvent('trip_cancelled', {
        trip_id: tripId,
        car_id: trip.carId,
        joined_passengers: joinedPassengers,
        cancellations_30: result.cancellationsLast30,
      });
      return result;
    });
  }

  async listTemplates(viewerId: string): Promise<RouteTemplate[]> {
    return templates.listTemplates(this.db, viewerId);
  }

  async createTemplate(viewerId: string, body: RouteTemplateInput): Promise<RouteTemplate> {
    return this.db.transaction((tx) => templates.createTemplate(tx, viewerId, body.stops));
  }

  async deleteTemplate(viewerId: string, templateId: string): Promise<void> {
    await templates.deleteTemplate(this.db, viewerId, templateId);
  }
}

/** Своя поездка под `FOR UPDATE`: нет — `not_found`, чужая — `forbidden`. */
async function ownTrip(tx: Transaction, driverId: string, tripId: string): Promise<TripRow> {
  const trip = await findTrip(tx, tripId, true);
  if (!trip) throw new AppError('not_found', 'Поездка не найдена');
  if (trip.driverId !== driverId) throw new AppError('forbidden', 'Чужая поездка');
  return trip;
}

/** Строка поездки и её остановки, цены, услуги; возвращает id. */
async function insertTrip(
  tx: Transaction,
  driverId: string,
  data: TripData,
  stops: ResolvedStop[],
  reverseOf: string | null,
): Promise<string> {
  const [row] = await tx
    .insert(trips)
    .values({
      driverId,
      carId: data.carId,
      kind: data.kind,
      vehicleKind: data.vehicleKind,
      departsAt: data.departsAt,
      arrivesAt: data.arrivesAt,
      seatsTotal: data.seatsTotal,
      priceFull: data.priceFull,
      priceBoardingMin: data.priceBoardingMin,
      bookingMode: data.bookingMode,
      reverseOf,
      parcelOnlyAllowed: data.parcelOnlyAllowed,
      parcelSeatsTotal: data.parcelSeatsTotal,
    })
    .returning({ id: trips.id });
  await writeTripParts(tx, row.id, { stops, prices: data.prices, extras: data.extras });
  return row.id;
}
