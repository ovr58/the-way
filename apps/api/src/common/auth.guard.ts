import { type CanActivate, type ExecutionContext, Inject, Injectable } from '@nestjs/common';
import { and, eq, gt, sql } from 'drizzle-orm';
import type { Request } from 'express';
import { DATABASE, type Database } from '../db/client';
import { sessions } from '../modules/auth/internal/schema';
import { bearerTokenOf, hashSessionToken, isWellFormedSessionToken } from '../modules/auth/internal/session-token';
import { users } from '../modules/users/internal/schema';
import { AppError } from './errors';
import { setRequestUserId } from './logger';

/** Шаблон пути маршрута (`/trips/:id/reverse`), а не фактический путь. */
export function routeOf(req: Request): string {
  const route = (req as Request & { route?: { path?: unknown } }).route;
  return typeof route?.path === 'string' ? route.path : req.path;
}

/** Без токена доступны (раздел «Охрана» плана): город выбирается до входа, ошибки шлются до входа. */
function isOpen(method: string, path: string): boolean {
  return (
    path.startsWith('/auth/') ||
    (method === 'GET' && (path === '/health' || path === '/cities')) ||
    (method === 'POST' && path === '/client-logs')
  );
}

/** `admin_blocked` пускают только сюда. */
function allowsAdminBlocked(method: string, path: string): boolean {
  return path.startsWith('/auth/') || path === '/health' || (method === 'GET' && path === '/me');
}

/**
 * Глобальный guard токена: bearer → живая сессия → пользователь в контексте запроса
 * (`setRequestUserId`); нет сессии — 401 `unauthorized`, кроме открытых путей; `admin_blocked` —
 * 403 `account_blocked` на всём, кроме `/auth/*`, `/health` и `GET /me`.
 */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<Request>();
    const method = req.method;
    const path = routeOf(req);

    const token = bearerTokenOf(req.header('authorization'));
    const user = token !== null && isWellFormedSessionToken(token) ? await this.sessionUser(token) : null;

    if (!user) {
      if (isOpen(method, path)) return true;
      throw new AppError('unauthorized', 'Требуется вход');
    }
    setRequestUserId(user.id);
    if (user.adminBlocked && !allowsAdminBlocked(method, path)) {
      throw new AppError('account_blocked', 'Аккаунт заблокирован');
    }
    return true;
  }

  private async sessionUser(token: string): Promise<{ id: string; adminBlocked: boolean } | null> {
    const [row] = await this.db
      .select({ id: users.id, adminBlocked: users.adminBlocked })
      .from(sessions)
      .innerJoin(users, eq(users.id, sessions.userId))
      .where(and(eq(sessions.tokenHash, hashSessionToken(token)), gt(sessions.expiresAt, sql`now()`)));
    return row ?? null;
  }
}
