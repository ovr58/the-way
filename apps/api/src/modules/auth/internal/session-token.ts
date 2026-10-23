import { createHash, randomBytes } from 'node:crypto';

/**
 * Сессионный токен:
 * 32 случайных байта в `base64url`, в базе — SHA-256 hex (64 знака, `CHECK` в `sessions`).
 * Подпись не нужна: сессию обязаны уметь прекратить (`logout`), а строка в базе это даёт сама.
 */

const TOKEN_BYTES = 32;

/** 32 байта в `base64url` без выравнивания — ровно 43 знака. */
const TOKEN_SHAPE = /^[A-Za-z0-9_-]{43}$/;

/** Абсолютный срок сессии — 30 суток (`sessions.expires_at`). */
export const SESSION_LIFETIME_MS = 30 * 24 * 60 * 60 * 1000;

export function newSessionToken(): string {
  return randomBytes(TOKEN_BYTES).toString('base64url');
}

/** SHA-256 без соли: 256 случайных бит перебором не берутся, а искать сессию надо по хешу. */
export function hashSessionToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export function isWellFormedSessionToken(token: string): boolean {
  return TOKEN_SHAPE.test(token);
}

/** Токен из `Authorization: Bearer <токен>`; схема регистронезависима (RFC 7235). */
export function bearerTokenOf(header: string | undefined): string | null {
  const match = /^bearer +(\S+)$/i.exec(header ?? '');
  return match ? match[1] : null;
}
