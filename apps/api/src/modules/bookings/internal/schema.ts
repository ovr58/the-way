/**
 * Таблицы модуля `bookings`: брони и выбранные услуги. Статусы и события «при открытии» —
 * «Контракт данных» и «События».
 */
import { sql } from 'drizzle-orm';
import { boolean, integer, pgTable, primaryKey, serial, text, timestamp, uniqueIndex, uuid } from 'drizzle-orm/pg-core';
import { bookingStatusEnum, extraKindEnum, parcelSizeEnum } from '../../../db/enums';
import { orders } from '../../orders/internal/schema';
import { trips } from '../../trips/internal/schema';
import { users } from '../../users/internal/schema';

export { bookingStatusEnum, parcelSizeEnum };

export const bookings = pgTable(
  'bookings',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    number: serial('number').notNull().unique(),
    tripId: uuid('trip_id')
      .notNull()
      .references(() => trips.id),
    passengerId: uuid('passenger_id')
      .notNull()
      .references(() => users.id),
    fromIdx: integer('from_idx').notNull(),
    toIdx: integer('to_idx').notNull(),
    seats: integer('seats').notNull(),
    parcelSize: parcelSizeEnum('parcel_size').notNull().default('none'),
    parcelOnly: boolean('parcel_only').notNull().default(false),
    /** ≤ 250 символов, только при `parcel_size ≠ none`. */
    parcelComment: text('parcel_comment'),
    priceTotal: integer('price_total').notNull(),
    status: bookingStatusEnum('status').notNull(),
    passengerSeenStatus: bookingStatusEnum('passenger_seen_status'),
    driverSeenStatus: bookingStatusEnum('driver_seen_status'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    confirmedAt: timestamp('confirmed_at', { withTimezone: true }),
    paidAt: timestamp('paid_at', { withTimezone: true }),
    rejectedAt: timestamp('rejected_at', { withTimezone: true }),
    cancelledAt: timestamp('cancelled_at', { withTimezone: true }),
    /** Заказ пассажира, из которого бронь родилась откликом водителя. */
    orderId: uuid('order_id').references(() => orders.id),
  },
  (t) => [
    uniqueIndex('bookings_active_trip_passenger_unique')
      .on(t.tripId, t.passengerId)
      .where(sql`${t.status} in ('requested', 'awaiting_payment', 'paid')`),
    // У заказа одна живая бронь: второй отклик на взятый заказ не пройдёт и при гонке.
    uniqueIndex('bookings_active_order_unique')
      .on(t.orderId)
      .where(sql`${t.orderId} is not null and ${t.status} in ('requested', 'awaiting_payment', 'paid')`),
  ],
);

export const bookingExtras = pgTable(
  'booking_extras',
  {
    bookingId: uuid('booking_id')
      .notNull()
      .references(() => bookings.id),
    kind: extraKindEnum('kind').notNull(),
    price: integer('price').notNull(),
  },
  (t) => [primaryKey({ columns: [t.bookingId, t.kind] })],
);
