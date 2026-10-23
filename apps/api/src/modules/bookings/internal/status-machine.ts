/**
 * Машина статусов брони (V-07) — одна таблица переходов. Сервис меняет статус только через
 * `nextStatus`; кто вправе делать переход — `actor`.
 */
import { AppError } from '../../../common/errors';
import type { BookingMode, BookingStatus } from '../../../common/enums';

export type BookingAction = 'confirm' | 'reject' | 'pay' | 'cancel';
/** Сторона брони: пассажир брони или водитель её поездки. */
export type BookingSide = 'passenger' | 'driver';

export const BOOKING_TRANSITIONS: Record<BookingAction, { from: readonly BookingStatus[]; to: BookingStatus; actor: BookingSide }> = {
  confirm: { from: ['requested'], to: 'awaiting_payment', actor: 'driver' },
  reject: { from: ['requested'], to: 'rejected', actor: 'driver' },
  pay: { from: ['awaiting_payment'], to: 'paid', actor: 'passenger' },
  cancel: { from: ['requested', 'awaiting_payment', 'paid'], to: 'cancelled', actor: 'passenger' },
};

/** Статус новой брони: стандартное бронирование — заявка, быстрое — сразу к оплате. */
export function initialStatus(mode: BookingMode): BookingStatus {
  return mode === 'instant' ? 'awaiting_payment' : 'requested';
}

/** Статус после `action`; из `from` такого перехода нет — `invalid_transition`. */
export function nextStatus(action: BookingAction, from: BookingStatus): BookingStatus {
  const t = BOOKING_TRANSITIONS[action];
  if (!t.from.includes(from)) throw new AppError('invalid_transition', `Из ${from} перехода ${action} нет`);
  return t.to;
}
