/**
 * Доступ к PostgreSQL: один пул `pg` на процесс и Drizzle поверх него.
 * База — только из `DATABASE_URL` окружения.
 *
 * Пул соединяется лениво — `npm run openapi:emit` поднимает контекст приложения без базы.
 */
import { join } from 'node:path';
import { Global, Inject, Module, type OnApplicationShutdown } from '@nestjs/common';
import { drizzle, type NodePgDatabase } from 'drizzle-orm/node-postgres';
import { migrate } from 'drizzle-orm/node-postgres/migrator';
import { Pool } from 'pg';

export const DATABASE_POOL = Symbol('DATABASE_POOL');
export const DATABASE = Symbol('DATABASE');

/** Схема параметром не передаётся: таблицы живут по модулям (`modules/<m>/internal/schema.ts`). */
export type Database = NodePgDatabase<Record<string, never>>;

/** Открытая транзакция — единица работы, которую функции общих модулей принимают первым аргументом. */
export type Transaction = Parameters<Parameters<Database['transaction']>[0]>[0];

/** Кто исполняет запрос: соединение пула или открытая транзакция. */
export type DbExecutor = Database | Transaction;

export function createPool(): Pool {
  return new Pool({ connectionString: process.env.DATABASE_URL });
}

export function createDatabase(pool: Pool): Database {
  return drizzle(pool);
}

const MIGRATIONS_FOLDER = join(__dirname, '../../drizzle');

/** Накат миграций `apps/api/drizzle`; повторный прогон на накатанной базе — не ошибка. */
export async function runMigrations(db: Database): Promise<void> {
  await migrate(db, { migrationsFolder: MIGRATIONS_FOLDER });
}

class PoolCloser implements OnApplicationShutdown {
  constructor(@Inject(DATABASE_POOL) private readonly pool: Pool) {}

  async onApplicationShutdown(): Promise<void> {
    await this.pool.end();
  }
}

/** Глобальный модуль: сервисы всех модулей берут `@Inject(DATABASE)` отсюда. */
@Global()
@Module({
  providers: [
    { provide: DATABASE_POOL, useFactory: createPool },
    { provide: DATABASE, useFactory: createDatabase, inject: [DATABASE_POOL] },
    PoolCloser,
  ],
  exports: [DATABASE],
})
export class DbModule {}
