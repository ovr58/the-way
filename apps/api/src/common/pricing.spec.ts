import { AppError } from './errors';
import { priceBooking, segPrice, type TripPricing } from './pricing';

/** A → B → C → D: участки AB, BC, CD, весь маршрут — 1000 (меньше суммы 1100 — скидка). */
const trip: TripPricing = {
  priceFull: 1000,
  stopsCount: 4,
  prices: [
    { fromIdx: 0, toIdx: 1, price: 300 },
    { fromIdx: 1, toIdx: 2, price: 400 },
    { fromIdx: 2, toIdx: 3, price: 400 },
  ],
  extras: [
    { kind: 'child_seat', price: 150 },
    { kind: 'parcel_s', price: 170 },
  ],
};

function codeOf(fn: () => unknown): string | undefined {
  try {
    fn();
  } catch (e) {
    return e instanceof AppError ? e.code : 'other';
  }
  return undefined;
}

describe('segPrice', () => {
  it('весь маршрут — priceFull, иначе — сумма участков на пути', () => {
    expect(segPrice(trip, 0, 3)).toBe(1000);
    expect(segPrice(trip, 0, 2)).toBe(700);
    expect(segPrice(trip, 1, 3)).toBe(800);
    expect(segPrice(trip, 1, 2)).toBe(400);
  });

  it('отрезок не дороже всего маршрута: min(сумма участков, priceFull)', () => {
    const cheapWhole: TripPricing = {
      ...trip,
      priceFull: 600,
      prices: [
        { fromIdx: 0, toIdx: 1, price: 500 },
        { fromIdx: 1, toIdx: 2, price: 500 },
        { fromIdx: 2, toIdx: 3, price: 500 },
      ],
    };
    expect(segPrice(cheapWhole, 0, 2)).toBe(600);
    expect(segPrice(cheapWhole, 1, 3)).toBe(600);
    expect(segPrice(cheapWhole, 1, 2)).toBe(500);
    expect(segPrice(cheapWhole, 0, 3)).toBe(600);
  });

  it('обратный, пустой и вне маршрута — цены нет', () => {
    expect(segPrice(trip, 2, 1)).toBeNull();
    expect(segPrice(trip, 1, 1)).toBeNull();
    expect(segPrice(trip, 0, 4)).toBeNull();
    expect(segPrice(trip, -1, 2)).toBeNull();
  });

  it('участка не хватает — цены нет', () => {
    expect(segPrice({ ...trip, prices: trip.prices.slice(1) }, 0, 2)).toBeNull();
  });
});

describe('priceBooking', () => {
  it('отрезок × мест + услуги + посылка', () => {
    const q = priceBooking(trip, { fromIdx: 0, toIdx: 2, seats: 2, parcelSize: 'S', services: ['child_seat'] });
    expect(q.segmentPrice).toBe(700);
    expect(q.priceTotal).toBe(700 * 2 + 150 + 170);
    expect(q.extras).toEqual([
      { kind: 'child_seat', price: 150 },
      { kind: 'parcel_s', price: 170 },
    ]);
  });

  it('отрезок без цены, невозимый размер, неразрешённая услуга — validation', () => {
    expect(codeOf(() => priceBooking(trip, { fromIdx: 2, toIdx: 1, seats: 1, parcelSize: 'none', services: [] }))).toBe('validation');
    expect(codeOf(() => priceBooking(trip, { fromIdx: 0, toIdx: 3, seats: 1, parcelSize: 'L', services: [] }))).toBe('validation');
    expect(codeOf(() => priceBooking(trip, { fromIdx: 0, toIdx: 3, seats: 1, parcelSize: 'none', services: ['pets'] }))).toBe('validation');
  });
});
