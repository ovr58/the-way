/**
 * Цена брони по «Правилам поездки и цены»: `segPrice` и `priceTotal`. Та же функция считает бронь,
 * `quote`, бронь из отклика на заказ пассажира (`order-response.ts`) и `segmentPrice` формы
 * `Booking` (`views.ts`).
 */
import { AppError } from './errors';
import type { ExtraKind, ParcelSize, ServiceKind } from './enums';

export interface TripPricing {
  priceFull: number;
  /** Число остановок `n`. */
  stopsCount: number;
  /** Цены участков между соседними точками `(k, k+1)`. */
  prices: { fromIdx: number; toIdx: number; price: number }[];
  /** `trip_extras`: разрешённые услуги и возимые размеры посылки с ценами водителя. */
  extras: { kind: ExtraKind; price: number }[];
}

export interface PriceInput {
  fromIdx: number;
  toIdx: number;
  seats: number;
  parcelSize: ParcelSize;
  services: ServiceKind[];
}

export interface PriceResult {
  segmentPrice: number;
  priceTotal: number;
  /** Строки `booking_extras`: выбранные услуги и размер посылки с ценой. */
  extras: { kind: ExtraKind; price: number }[];
}

const PARCEL_EXTRA: Record<Exclude<ParcelSize, 'none'>, ExtraKind> = { S: 'parcel_s', M: 'parcel_m', L: 'parcel_l' };

/**
 * Цена отрезка: весь маршрут — `priceFull`, иначе сумма участков `(k, k+1)` на пути, но не дороже
 * всего маршрута — `min(сумма, priceFull)`: «весь маршрут» — скидка, больше него никто не платит.
 * Обратный, пустой, вне маршрута или без цены участка — `null`.
 */
export function segPrice(trip: TripPricing, fromIdx: number, toIdx: number): number | null {
  const last = trip.stopsCount - 1;
  if (fromIdx < 0 || toIdx > last || fromIdx >= toIdx) return null;
  if (fromIdx === 0 && toIdx === last) return trip.priceFull;
  let sum = 0;
  for (let k = fromIdx; k < toIdx; k += 1) {
    const leg = trip.prices.find((p) => p.fromIdx === k && p.toIdx === k + 1);
    if (!leg) return null;
    sum += leg.price;
  }
  return Math.min(sum, trip.priceFull);
}

/** `segPrice × seats + Σ услуг + цена размера посылки`; правило нарушено — `validation`. */
export function priceBooking(trip: TripPricing, input: PriceInput): PriceResult {
  const segmentPrice = segPrice(trip, input.fromIdx, input.toIdx);
  if (segmentPrice === null) throw new AppError('validation', 'У этого отрезка нет цены');
  const priceOf = (kind: ExtraKind): number | undefined => trip.extras.find((e) => e.kind === kind)?.price;

  const extras: PriceResult['extras'] = [];
  for (const kind of [...new Set(input.services)]) {
    const price = priceOf(kind);
    if (price === undefined) throw new AppError('validation', `Услуга ${kind} не предлагается`);
    extras.push({ kind, price });
  }
  if (input.parcelSize !== 'none') {
    const kind = PARCEL_EXTRA[input.parcelSize];
    const price = priceOf(kind);
    if (price === undefined) throw new AppError('validation', `Посылку ${input.parcelSize} водитель не возит`);
    extras.push({ kind, price });
  }
  const priceTotal = segmentPrice * input.seats + extras.reduce((sum, e) => sum + e.price, 0);
  return { segmentPrice, priceTotal, extras };
}
