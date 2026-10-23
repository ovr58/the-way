/** Таблицы модуля `cities`: справочник населённых пунктов (seed — пополнение — `resolveCityId`). */
import { doublePrecision, pgTable, serial, text, unique } from 'drizzle-orm/pg-core';
import { citySourceEnum } from '../../../db/enums';

export { citySourceEnum };

export const cities = pgTable(
  'cities',
  {
    id: serial('id').primaryKey(),
    name: text('name').notNull(),
    region: text('region').notNull(),
    lat: doublePrecision('lat').notNull(),
    lng: doublePrecision('lng').notNull(),
    source: citySourceEnum('source').notNull().default('seed'),
  },
  (t) => [unique('cities_name_region_unique').on(t.name, t.region)],
);
