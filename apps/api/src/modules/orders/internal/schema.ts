/**
 * Таблицы модуля `orders`: заказ пассажира, его точки и нужные услуги (план passenger-order,
 * «Контракт»). Заказ — встречная сторона поездки: пассажир публикует, водитель откликается бронью.
 */
import { sql } from 'drizzle-orm';
import { doublePrecision, integer, pgTable, primaryKey, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { extraKindEnum, orderStatusEnum, parcelSizeEnum, tripKindEnum } from '../../../db/enums';
import { cities } from '../../cities/internal/schema';
import { users } from '../../users/internal/schema';

export { orderStatusEnum };

export const orders = pgTable('orders', {
  id: uuid('id').primaryKey().defaultRandom(),
  /**
   * «Заказ №» — из последовательности номеров броней: номера заказов и броней в одном списке
   * пассажира не совпадают, бронь из заказа показывает номер заказа.
   */
  number: integer('number')
    .notNull()
    .unique()
    .default(sql`nextval('bookings_number_seq')`),
  passengerId: uuid('passenger_id')
    .notNull()
    .references(() => users.id),
  kind: tripKindEnum('kind').notNull(),
  departsAt: timestamp('departs_at', { withTimezone: true }).notNull(),
  /** «Примерное время прибытия» мастера. */
  arrivesAt: timestamp('arrives_at', { withTimezone: true }).notNull(),
  /** Мест: у поездки 1–8, у посылки 0. */
  seats: integer('seats').notNull(),
  parcelSize: parcelSizeEnum('parcel_size').notNull().default('none'),
  /** ≤ 250 символов, только при посылке. */
  parcelComment: text('parcel_comment'),
  /** Хранимый статус; ответ отдаёт действующий (`expired` — открытый с выездом в прошлом). */
  status: orderStatusEnum('status').notNull().default('open'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  cancelledAt: timestamp('cancelled_at', { withTimezone: true }),
});

/** `idx` 0 — откуда, последний — куда; как `trip_stops`. */
export const orderStops = pgTable(
  'order_stops',
  {
    orderId: uuid('order_id')
      .notNull()
      .references(() => orders.id),
    idx: integer('idx').notNull(),
    cityId: integer('city_id')
      .notNull()
      .references(() => cities.id),
    address: text('address').notNull(),
    shortAddress: text('short_address'),
    lat: doublePrecision('lat'),
    lng: doublePrecision('lng'),
  },
  (t) => [primaryKey({ columns: [t.orderId, t.idx] })],
);

/** Нужные пассажиру услуги: только `child_seat`, `pets`, `luggage` (посылка — `orders.parcel_size`). */
export const orderExtras = pgTable(
  'order_extras',
  {
    orderId: uuid('order_id')
      .notNull()
      .references(() => orders.id),
    kind: extraKindEnum('kind').notNull(),
  },
  (t) => [primaryKey({ columns: [t.orderId, t.kind] })],
);
