/**
 * Таблицы модуля `trips`: поездки, остановки, цены отрезков, услуги и размеры посылки, шаблоны
 * маршрутов. Правила — «Правила поездки и цены».
 */
import { type AnyPgColumn, boolean, integer, jsonb, pgTable, primaryKey, serial, text, timestamp, uuid, doublePrecision } from 'drizzle-orm/pg-core';
import { bookingModeEnum, extraKindEnum, tripKindEnum, tripStatusEnum, vehicleKindEnum } from '../../../db/enums';
import { cars } from '../../cars/internal/schema';
import { cities } from '../../cities/internal/schema';
import { users } from '../../users/internal/schema';

export { bookingModeEnum, extraKindEnum, tripKindEnum, tripStatusEnum };

export const trips = pgTable('trips', {
  id: uuid('id').primaryKey().defaultRandom(),
  driverId: uuid('driver_id')
    .notNull()
    .references(() => users.id),
  carId: uuid('car_id')
    .notNull()
    .references(() => cars.id),
  kind: tripKindEnum('kind').notNull(),
  vehicleKind: vehicleKindEnum('vehicle_kind').notNull(),
  departsAt: timestamp('departs_at', { withTimezone: true }).notNull(),
  arrivesAt: timestamp('arrives_at', { withTimezone: true }).notNull(),
  seatsTotal: integer('seats_total').notNull(),
  seatsTaken: integer('seats_taken').notNull().default(0),
  priceFull: integer('price_full').notNull(),
  priceBoardingMin: integer('price_boarding_min').notNull(),
  bookingMode: bookingModeEnum('booking_mode').notNull(),
  status: tripStatusEnum('status').notNull().default('active'),
  reverseOf: uuid('reverse_of').references((): AnyPgColumn => trips.id),
  /** «Заказ №» на «Базовые экраны - Поездок нет». */
  number: serial('number').notNull().unique(),
  parcelOnlyAllowed: boolean('parcel_only_allowed').notNull().default(false),
  /** Мест для посылок. */
  parcelSeatsTotal: integer('parcel_seats_total').notNull().default(0),
  parcelSeatsTaken: integer('parcel_seats_taken').notNull().default(0),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  cancelledAt: timestamp('cancelled_at', { withTimezone: true }),
});

/** `idx` 0 — старт, последний — финиш. */
export const tripStops = pgTable(
  'trip_stops',
  {
    tripId: uuid('trip_id')
      .notNull()
      .references(() => trips.id),
    idx: integer('idx').notNull(),
    cityId: integer('city_id')
      .notNull()
      .references(() => cities.id),
    address: text('address').notNull(),
    /** Короткий адрес для карточки (`GeoSuggestion.shortLabel`, PN-2); null — карточка берёт `address`. */
    shortAddress: text('short_address'),
    /** Из подсказки Mapbox; без подсказки — null. */
    lat: doublePrecision('lat'),
    lng: doublePrecision('lng'),
  },
  (t) => [primaryKey({ columns: [t.tripId, t.idx] })],
);

export const tripPrices = pgTable(
  'trip_prices',
  {
    tripId: uuid('trip_id')
      .notNull()
      .references(() => trips.id),
    fromIdx: integer('from_idx').notNull(),
    toIdx: integer('to_idx').notNull(),
    price: integer('price').notNull(),
  },
  (t) => [primaryKey({ columns: [t.tripId, t.fromIdx, t.toIdx] })],
);

/** Строка = услуга разрешена / размер посылки возится; цену задаёт водитель. */
export const tripExtras = pgTable(
  'trip_extras',
  {
    tripId: uuid('trip_id')
      .notNull()
      .references(() => trips.id),
    kind: extraKindEnum('kind').notNull(),
    price: integer('price').notNull(),
  },
  (t) => [primaryKey({ columns: [t.tripId, t.kind] })],
);

export interface RouteTemplateStop {
  cityId: number;
  address: string;
  /** Нет в шаблонах до PN-2 — тогда `address`. */
  shortAddress?: string | null;
  lat: number | null;
  lng: number | null;
}

export const routeTemplates = pgTable('route_templates', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id),
  stops: jsonb('stops').$type<RouteTemplateStop[]>().notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});
