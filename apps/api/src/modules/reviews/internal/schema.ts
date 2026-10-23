/** Таблицы модуля `reviews`: отзывы (seed, интерфейса нет) и жалобы (FR-20, только чтение). */
import { sql } from 'drizzle-orm';
import { check, pgTable, smallint, text, timestamp, unique, uuid } from 'drizzle-orm/pg-core';
import { complaintStatusEnum } from '../../../db/enums';
import { bookings } from '../../bookings/internal/schema';
import { trips } from '../../trips/internal/schema';
import { users } from '../../users/internal/schema';

export { complaintStatusEnum };

export const reviews = pgTable(
  'reviews',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    authorId: uuid('author_id')
      .notNull()
      .references(() => users.id),
    targetId: uuid('target_id')
      .notNull()
      .references(() => users.id),
    tripId: uuid('trip_id')
      .notNull()
      .references(() => trips.id),
    bookingId: uuid('booking_id').references(() => bookings.id),
    rating: smallint('rating').notNull(),
    body: text('body'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    check('reviews_rating_range', sql`${t.rating} between 1 and 5`),
    unique('reviews_author_booking_unique').on(t.authorId, t.bookingId),
  ],
);

export const complaints = pgTable('complaints', {
  id: uuid('id').primaryKey().defaultRandom(),
  authorId: uuid('author_id')
    .notNull()
    .references(() => users.id),
  targetId: uuid('target_id')
    .notNull()
    .references(() => users.id),
  tripId: uuid('trip_id').references(() => trips.id),
  reason: text('reason').notNull(),
  status: complaintStatusEnum('status').notNull().default('open'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});
