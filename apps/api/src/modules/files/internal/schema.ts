/** Таблицы модуля `files`: загруженные изображения (фото профиля, авто, СТС). */
import { type AnyPgColumn, integer, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { users } from '../../users/internal/schema';

export const files = pgTable('files', {
  id: uuid('id').primaryKey().defaultRandom(),
  ownerId: uuid('owner_id')
    .notNull()
    .references((): AnyPgColumn => users.id),
  mime: text('mime').notNull(),
  /** Путь относительно `FILES_DIR`. */
  path: text('path').notNull(),
  size: integer('size').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});
