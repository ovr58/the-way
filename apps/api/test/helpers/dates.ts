/**
 * Даты проверок — в `APP_TZ`: сутки лимита, кратность 30 минутам и «≤ 3 дня» считаются по
 * стенным часам пояса, клиент шлёт ISO со смещением.
 */
export const APP_TZ = process.env.APP_TZ ?? 'Europe/Moscow';

function wallParts(at: Date): { y: number; m: number; d: number; h: number; min: number } {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: APP_TZ,
    hourCycle: 'h23',
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
    hour: 'numeric',
    minute: 'numeric',
  }).formatToParts(at);
  const get = (type: string): number => Number(parts.find((p) => p.type === type)?.value);
  return { y: get('year'), m: get('month'), d: get('day'), h: get('hour'), min: get('minute') };
}

/** Смещение пояса в минутах в момент `at`. */
function offsetMinutes(at: Date): number {
  const w = wallParts(at);
  return Math.round((Date.UTC(w.y, w.m - 1, w.d, w.h, w.min) - Math.floor(at.getTime() / 60_000) * 60_000) / 60_000);
}

/** Момент «сегодня + days, hh:mm» по стенным часам `APP_TZ`. */
export function atLocal(days: number, hours: number, minutes = 0): Date {
  const today = wallParts(new Date());
  const guess = Date.UTC(today.y, today.m - 1, today.d + days, hours, minutes);
  return new Date(guess - offsetMinutes(new Date(guess)) * 60_000);
}

/** ISO-8601 со смещением пояса: `2026-10-22T10:00:00+03:00`. */
export function isoLocal(at: Date): string {
  const w = wallParts(at);
  const off = offsetMinutes(at);
  const pad = (n: number): string => String(n).padStart(2, '0');
  const sign = off >= 0 ? '+' : '-';
  const abs = Math.abs(off);
  return `${w.y}-${pad(w.m)}-${pad(w.d)}T${pad(w.h)}:${pad(w.min)}:00${sign}${pad(Math.floor(abs / 60))}:${pad(abs % 60)}`;
}

/** Дата `YYYY-MM-DD` момента в `APP_TZ`. */
export function dateLocal(at: Date): string {
  return isoLocal(at).slice(0, 10);
}

export const HOUR = 3600_000;
export const DAY = 24 * HOUR;
