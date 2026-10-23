/** Точка входа API (SPEC §1): `npm run dev`, на стенде — `node dist/main.js` под pm2. */
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { AppLogger } from './common/logger';
import { configureApp } from './configure-app';
import { DATABASE, type Database, runMigrations } from './db/client';

async function bootstrap(): Promise<void> {
  const logger = new AppLogger();
  const app = await NestFactory.create(AppModule, { logger });
  configureApp(app);

  // Миграции — до первого принятого запроса: процесс не обслуживает трафик на старой схеме.
  await runMigrations(app.get<Database>(DATABASE));
  logger.log('Миграции применены', 'Bootstrap');

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
  logger.log(`API слушает порт ${port}`, 'Bootstrap');
}

void bootstrap();
