/**
 * Правила времени и вместимости, общие для поездки водителя и заказа пассажира («Правила
 * поездки и цены»): выезд кратен 30 минутам, не в прошлом и не
 * дальше 3 дней, прибытие позже выезда, но не позже чем через 24 ч; у легкового — от 1 до 8 мест, у автобуса — от 9 до 60.
 */
import { AppError } from './errors';

const STEP_MS = 30 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

/** Поездку и заказ можно публиковать не дальше чем на столько дней вперёд. */
export const MAX_DAYS_AHEAD = 3;

/** Мест у легкового авто — и у заказа пассажира на поездку. */
export const CAR_SEATS_MAX = 8;

/** Мест у автобуса: от 9 до 60. */
export const BUS_SEATS_MIN = 9;
export const BUS_SEATS_MAX = 60;

const appTz = (): string => process.env.APP_TZ ?? 'Europe/Moscow';

/** Сутки момента в `APP_TZ`: `YYYY-MM-DD`. */
export function appDay(at: Date): string {
  return at.toLocaleDateString('en-CA', { timeZone: appTz() });
}

/** Выезд и прибытие: `validation`, `invalid_time_step`, `too_far_ahead`. */
export function checkTimes(departsAt: Date, arrivesAt: Date): void {
  if (Number.isNaN(departsAt.getTime()) || Number.isNaN(arrivesAt.getTime())) {
    throw new AppError('validation', 'Некорректное время');
  }
  if (arrivesAt.getTime() <= departsAt.getTime()) throw new AppError('validation', 'Прибытие раньше отправления');
  // Прибытие раньше выезда по часам — следующий день; в пути — не больше суток.
  if (arrivesAt.getTime() - departsAt.getTime() > DAY_MS) throw new AppError('validation', 'В пути — не больше 24 часов');
  if (departsAt.getTime() % STEP_MS !== 0) {
    throw new AppError('invalid_time_step', 'Время отправления — кратно 30 минутам');
  }
  const now = Date.now();
  if (departsAt.getTime() < now) throw new AppError('validation', 'Отправление в прошлом');
  if (departsAt.getTime() > now + MAX_DAYS_AHEAD * DAY_MS) {
    throw new AppError('too_far_ahead', `Не дальше чем через ${MAX_DAYS_AHEAD} дня`);
  }
}
