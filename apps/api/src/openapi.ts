/**
 * Эмиттер контракта (`npm run openapi:emit`): поднимает контекст приложения без `listen()` и
 * пишет `contracts/openapi.json`. Файл коммитится; руками не правится — источник контракта код.
 * База не нужна: пул `pg` соединяется лениво.
 */
import 'reflect-metadata';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { buildOpenApiDocument } from './configure-app';

const OUTPUT = join(__dirname, '../../../contracts/openapi.json');

async function emit(): Promise<void> {
  const app = await NestFactory.create(AppModule, { logger: false });
  const document = buildOpenApiDocument(app);
  mkdirSync(dirname(OUTPUT), { recursive: true });
  writeFileSync(OUTPUT, `${JSON.stringify(document, null, 2)}\n`, 'utf8');
  await app.close();
  process.stdout.write(`контракт выгружен: ${OUTPUT}\n`);
}

void emit();
