/**
 * Логгер проекта (без OpenTelemetry).
 * Единственный способ что-либо напечатать из прод-кода: `console.log` запрещён конвенцией.
 *
 * Запись — одна JSON-строка в stdout с `trace_id` и `user_id` текущего запроса
 * (`request-context.ts`): строка лога, по которой нельзя восстановить запрос, недиагностична.
 */
import { inspect } from 'node:util';
import type { LoggerService, LogLevel } from '@nestjs/common';
import { currentContext } from './request-context';

/** Пишет одну строку лога с полями контекста запроса. Общая точка для логгера и `logEvent`. */
export function writeLogLine(record: Record<string, unknown>): void {
  const ctx = currentContext();
  const line = {
    time: new Date().toISOString(),
    ...record,
    trace_id: ctx?.traceId,
    user_id: ctx?.userId,
  };
  process.stdout.write(`${JSON.stringify(line)}\n`);
}

export class AppLogger implements LoggerService {
  log(message: unknown, ...rest: unknown[]): void {
    this.write('log', message, rest);
  }

  error(message: unknown, ...rest: unknown[]): void {
    this.write('error', message, rest);
  }

  warn(message: unknown, ...rest: unknown[]): void {
    this.write('warn', message, rest);
  }

  debug(message: unknown, ...rest: unknown[]): void {
    this.write('debug', message, rest);
  }

  verbose(message: unknown, ...rest: unknown[]): void {
    this.write('verbose', message, rest);
  }

  fatal(message: unknown, ...rest: unknown[]): void {
    this.write('fatal', message, rest);
  }

  private write(level: LogLevel, message: unknown, rest: unknown[]): void {
    // Nest передаёт контекст (имя класса) последним аргументом.
    const last = rest.at(-1);
    writeLogLine({
      level,
      message: typeof message === 'string' ? message : inspect(message, { depth: 3 }),
      context: typeof last === 'string' ? last : undefined,
    });
  }
}
