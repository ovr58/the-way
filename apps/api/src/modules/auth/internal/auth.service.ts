import { Inject, Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { AppError } from '../../../common/errors';
import { logEvent, setRequestUserId } from '../../../common/logger';
import { meView } from '../../../common/views';
import { DATABASE, type Database } from '../../../db/client';
import { users } from '../../users/internal/schema';
import type { HealthResult, RequestCodeBody, RequestCodeResult, VerifyBody, VerifyResult } from './auth.dto';
import { AUTH_CODE, maskPhone, normalizePhone } from './phone';
import { sessions } from './schema';
import { SESSION_LIFETIME_MS, bearerTokenOf, hashSessionToken, newSessionToken } from './session-token';

/** Через сколько секунд можно запросить код снова («Вход - Базовый экран» – «Вход - СМС код (базовый экран)»). */
const RESEND_AFTER_SEC = 60;

/** Вход по телефону и коду `111111`, сессии, выход. SMS-шлюза нет (`docs/task.md`). */
@Injectable()
export class AuthService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async requestCode(body: RequestCodeBody): Promise<RequestCodeResult> {
    const phone = normalizePhone(body.phone);
    logEvent('auth_code_requested', { phone_masked: maskPhone(phone) });
    return { resendAfterSec: RESEND_AFTER_SEC };
  }

  async verify(body: VerifyBody): Promise<VerifyResult> {
    const phone = normalizePhone(body.phone);
    if (body.code !== AUTH_CODE) {
      logEvent('auth_failed', { phone_masked: maskPhone(phone) });
      throw new AppError('invalid_code', 'Неверный код');
    }
    return this.db.transaction(async (tx) => {
      await tx.insert(users).values({ phone }).onConflictDoNothing();
      const [user] = await tx.select().from(users).where(eq(users.phone, phone));
      const token = newSessionToken();
      await tx.insert(sessions).values({
        tokenHash: hashSessionToken(token),
        userId: user.id,
        expiresAt: new Date(Date.now() + SESSION_LIFETIME_MS),
      });
      setRequestUserId(user.id);
      const isNew = user.name === null;
      logEvent('auth_verified', { phone_masked: maskPhone(phone), is_new: isNew });
      const me = await meView(tx, user.id);
      if (!me) throw new AppError('internal', 'Пользователь не найден после входа');
      return { token, isNew, me };
    });
  }

  /** Без токена или с чужим — тихо 204: выйти можно всегда. */
  async logout(authorization: string | undefined): Promise<void> {
    const token = bearerTokenOf(authorization);
    if (token === null) return;
    await this.db.delete(sessions).where(eq(sessions.tokenHash, hashSessionToken(token)));
    logEvent('auth_logout');
  }

  async health(): Promise<HealthResult> {
    return { ok: true };
  }
}
