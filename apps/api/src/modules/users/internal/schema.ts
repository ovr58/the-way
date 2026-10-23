/**
 * Таблицы модуля `users`: пользователь (обе роли в одном аккаунте), отмены и блокировки
 * (пишет `common/cancellations.ts`).
 */
import { type AnyPgColumn, boolean, integer, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { blockReasonEnum, cancellationRoleEnum, userModeEnum } from '../../../db/enums';
import { bookings } from '../../bookings/internal/schema';
import { cities } from '../../cities/internal/schema';
import { files } from '../../files/internal/schema';
import { trips } from '../../trips/internal/schema';

export { blockReasonEnum, cancellationRoleEnum, userModeEnum };

export const users = pgTable('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  /** E.164: `+` и 8–15 цифр. */
  phone: text('phone').notNull().unique(),
  name: text('name'),
  photoFileId: uuid('photo_file_id').references((): AnyPgColumn => files.id),
  cityId: integer('city_id').references(() => cities.id),
  currentMode: userModeEnum('current_mode').notNull().default('passenger'),
  blockedUntil: timestamp('blocked_until', { withTimezone: true }),
  adminBlocked: boolean('admin_blocked').notNull().default(false),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const cancellations = pgTable('cancellations', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id),
  role: cancellationRoleEnum('role').notNull(),
  bookingId: uuid('booking_id').references(() => bookings.id),
  tripId: uuid('trip_id').references(() => trips.id),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const blocks = pgTable('blocks', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id),
  reason: blockReasonEnum('reason').notNull(),
  startsAt: timestamp('starts_at', { withTimezone: true }).notNull(),
  endsAt: timestamp('ends_at', { withTimezone: true }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});
