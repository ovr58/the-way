/** Таблицы модуля `cars`: автомобили, документы (СТС), записи проверки администратором. */
import { sql } from 'drizzle-orm';
import { integer, pgTable, text, timestamp, uniqueIndex, uuid } from 'drizzle-orm/pg-core';
import {
  adminCheckStatusEnum,
  adminCheckSubjectEnum,
  carDocumentKindEnum,
  carStatusEnum,
  vehicleKindEnum,
} from '../../../db/enums';
import { files } from '../../files/internal/schema';
import { users } from '../../users/internal/schema';

export { adminCheckStatusEnum, adminCheckSubjectEnum, carDocumentKindEnum, carStatusEnum, vehicleKindEnum };

/**
 * Ключ госномера: без пробелов, дефисов и знаков, заглавными; кириллица,
 * похожая на латиницу (А В Е К М Н О Р С Т У Х), — латиницей. «а 123 вс-76», «А123ВС76» и «A123BC76» —
 * один ключ. Строчные кириллицы — в `translate` явно: `upper()` зависит от локали базы.
 */
const PLATE_KEY = sql`translate(upper(regexp_replace(plate, '[^0-9A-Za-zА-Яа-яЁё]', '', 'g')), 'АВЕКМНОРСТУХавекмнорстух', 'ABEKMHOPCTYXABEKMHOPCTYX')`;

/**
 * Госномер для хранения и показа: заглавные, латинские буквы-двойники — кириллицей, разделители как
 * набраны. Буквы те же, что у ключа `PLATE_KEY`, только в обратную сторону: ключ показанного номера равен
 * ключу набранного. Здесь, а не в сервисе: детали поездки берут авто импортом этой схемы.
 */
export function normalizePlate(plate: string): string {
  return plate
    .trim()
    .toUpperCase()
    .replace(/[ABEKMHOPCTYX]/g, (ch) => 'АВЕКМНОРСТУХ'['ABEKMHOPCTYX'.indexOf(ch)]);
}

export const cars = pgTable('cars', {
  id: uuid('id').primaryKey().defaultRandom(),
  ownerId: uuid('owner_id')
    .notNull()
    .references(() => users.id),
  brand: text('brand').notNull(),
  model: text('model').notNull(),
  kind: vehicleKindEnum('kind').notNull(),
  seats: integer('seats').notNull(),
  plate: text('plate').notNull(),
  photoFileId: uuid('photo_file_id').references(() => files.id),
  /** `verified` сразу. */
  status: carStatusEnum('status').notNull().default('verified'),
  deletedAt: timestamp('deleted_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  /** Генерирует база (`PLATE_KEY`); вставка и правка его не пишут. */
  plateKey: text('plate_key').generatedAlwaysAs(PLATE_KEY),
}, (t) => [
  // Госномер уникален у владельца среди неудалённых авто; нарушение — `car_plate_taken`.
  uniqueIndex('cars_owner_plate_unique').on(t.ownerId, t.plateKey).where(sql`${t.deletedAt} is null`),
]);

export const carDocuments = pgTable('car_documents', {
  id: uuid('id').primaryKey().defaultRandom(),
  carId: uuid('car_id')
    .notNull()
    .references(() => cars.id),
  kind: carDocumentKindEnum('kind').notNull(),
  fileId: uuid('file_id')
    .notNull()
    .references(() => files.id),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

/** Интерфейса администратора нет (B3); сервер пишет `approved` с `subject_kind = car` при создании авто. */
export const adminChecks = pgTable('admin_checks', {
  id: uuid('id').primaryKey().defaultRandom(),
  subjectKind: adminCheckSubjectEnum('subject_kind').notNull(),
  subjectId: uuid('subject_id').notNull(),
  status: adminCheckStatusEnum('status').notNull(),
  note: text('note'),
  checkedAt: timestamp('checked_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});
