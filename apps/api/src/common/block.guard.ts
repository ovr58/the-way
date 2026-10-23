import { type CanActivate, type ExecutionContext, Inject, Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import type { Request } from 'express';
import { DATABASE, type Database } from '../db/client';
import { users } from '../modules/users/internal/schema';
import { routeOf } from './auth.guard';
import { AppError } from './errors';
import { optionalUserId } from './logger';

/** Действия, которые закрывает блокировка 2/30 (одна на пользователя, обе роли). */
export const BLOCKED_ROUTES: ReadonlyArray<readonly [string, string]> = [
  ['POST', '/trips'],
  ['POST', '/trips/:id/reverse'],
  ['POST', '/trips/:id/bookings'],
  // Заказ пассажира и отклик водителя — того же рода, что бронь и публикация.
  ['POST', '/orders'],
  ['POST', '/orders/:id/respond'],
];

/**
 * Глобальный guard блокировки (стоит после `AuthGuard`): `users.blocked_until > now()` на
 * действии из `BLOCKED_ROUTES` → 403 `blocked` с `blockedUntil`. Контроллеры о нём не знают.
 */
@Injectable()
export class BlockGuard implements CanActivate {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<Request>();
    const path = routeOf(req);
    if (!BLOCKED_ROUTES.some(([method, route]) => method === req.method && route === path)) return true;

    const userId = optionalUserId();
    if (!userId) return true;
    const [user] = await this.db.select({ blockedUntil: users.blockedUntil }).from(users).where(eq(users.id, userId));
    if (user?.blockedUntil && user.blockedUntil.getTime() > Date.now()) {
      throw new AppError('blocked', 'Действие заблокировано', { blockedUntil: user.blockedUntil.toISOString() });
    }
    return true;
  }
}
