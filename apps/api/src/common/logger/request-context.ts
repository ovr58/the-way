/**
 * Контекст запроса на `AsyncLocalStorage`: `trace_id` из W3C `traceparent` (нет
 * заголовка или он кривой — создаётся новый и возвращается заголовком ответа), `user_id` —
 * после guard токена (`setRequestUserId`).
 *
 * Контроллеры берут текущего пользователя через `requestUserId()` — параметр-декоратора нет.
 */
import { AsyncLocalStorage } from 'node:async_hooks';
import { randomBytes } from 'node:crypto';
import { UnauthorizedException } from '@nestjs/common';
import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { writeLogLine } from './app-logger';

export interface RequestContext {
  traceId: string;
  userId?: string;
}

const storage = new AsyncLocalStorage<RequestContext>();

/** `00-<trace-id 32 hex>-<parent-id 16 hex>-<flags 2 hex>`; нулевой trace-id недопустим. */
const TRACEPARENT = /^[0-9a-f]{2}-([0-9a-f]{32})-[0-9a-f]{16}-[0-9a-f]{2}$/;

export function traceIdFromTraceparent(header: string | undefined): string | undefined {
  const match = TRACEPARENT.exec((header ?? '').trim().toLowerCase());
  if (!match || /^0+$/.test(match[1])) return undefined;
  return match[1];
}

export function currentContext(): RequestContext | undefined {
  return storage.getStore();
}

/** Ставит пользователя в контекст текущего запроса (guard токена). */
export function setRequestUserId(userId: string): void {
  const ctx = storage.getStore();
  if (ctx) ctx.userId = userId;
}

/** Пользователь текущего запроса; нет — 401 (guard пропустил открытый путь). */
export function requestUserId(): string {
  const userId = storage.getStore()?.userId;
  if (!userId) throw new UnauthorizedException('Требуется вход');
  return userId;
}

/** Пользователь текущего запроса, если вошёл (открытые пути: `POST /client-logs`). */
export function optionalUserId(): string | undefined {
  return storage.getStore()?.userId;
}

/** Выполнить `fn` в контексте (тесты, seed, фоновые задачи). */
export function runWithContext<T>(ctx: RequestContext, fn: () => T): T {
  return storage.run(ctx, fn);
}

/** Middleware: открывает контекст запроса и возвращает `traceparent` заголовком ответа. */
export function requestContext(): RequestHandler {
  return (req: Request, res: Response, next: NextFunction): void => {
    const traceId = traceIdFromTraceparent(req.header('traceparent')) ?? randomBytes(16).toString('hex');
    res.setHeader('traceparent', `00-${traceId}-${randomBytes(8).toString('hex')}-01`);
    storage.run({ traceId }, next);
  };
}

/**
 * Бизнес-событие — строка лога (таблица «Журнал событий» плана): `logEvent('trip_published',
 * {trip_id, car_id})`. `trace_id` и `user_id` подставляются из контекста.
 */
export function logEvent(
  name: string,
  fields: Record<string, unknown> = {},
  level: 'info' | 'warn' | 'error' = 'info',
): void {
  writeLogLine({ level, event: name, ...fields });
}
