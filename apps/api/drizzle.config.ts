/**
 * Конфиг drizzle-kit — генератора миграций (`npm run db:generate --workspace=api`).
 * Схема каждого модуля живёт в `modules/<m>/internal/schema.ts`; генератору база не нужна.
 */
import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  dialect: 'postgresql',
  schema: './src/modules/*/internal/schema.ts',
  out: './drizzle',
  dbCredentials: { url: process.env.DATABASE_URL ?? '' },
});
