/**
 * `npm run db:migrate` — накат схемы без запуска API. Печатает прямо в поток: это вывод утилиты
 * человеку за терминалом, а не запись журнала приложения.
 */
import { createDatabase, createPool, runMigrations } from './client';

async function main(): Promise<void> {
  const pool = createPool();
  try {
    await runMigrations(createDatabase(pool));
    process.stdout.write('Миграции накатаны.\n');
  } finally {
    await pool.end();
  }
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
});
