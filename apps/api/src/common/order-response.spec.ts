import { matchOrderToTrip, type OrderFacts, type TripFacts } from './order-response';

/** Поездка A(1) → B(2) → C(3) завтра 08:00: цены A→B 400, B→C 500, весь маршрут 800; кресло 150, посылка S 100. */
const day = new Date('2026-10-23T05:00:00Z'); // 08:00 по Москве
const trip: TripFacts = {
  id: 't1',
  driverId: 'd1',
  effectiveStatus: 'active',
  departsAt: day,
  seatsFree: 2,
  parcelSeatsFree: 1,
  parcelOnlyAllowed: false,
  cityIds: [1, 2, 3],
  pricing: {
    priceFull: 800,
    stopsCount: 3,
    prices: [
      { fromIdx: 0, toIdx: 1, price: 400 },
      { fromIdx: 1, toIdx: 2, price: 500 },
    ],
    extras: [
      { kind: 'child_seat', price: 150 },
      { kind: 'parcel_s', price: 100 },
    ],
  },
};

const order: OrderFacts = {
  id: 'o1',
  passengerId: 'p1',
  kind: 'ride',
  departsAt: new Date('2026-10-23T07:00:00Z'), // 10:00 по Москве, те же сутки
  seats: 1,
  parcelSize: 'none',
  services: [],
  fromCityId: 1,
  toCityId: 3,
};

describe('matchOrderToTrip — поездка подходит под заказ', () => {
  it('весь маршрут: отрезок 0 → 2, цена всего маршрута × мест + услуги', () => {
    const r = matchOrderToTrip({ ...order, seats: 2, services: ['child_seat'] }, trip);
    expect(r).toEqual({ ok: true, fromIdx: 0, toIdx: 2, priceTotal: 800 * 2 + 150 });
  });

  it('от промежуточной до финиша и между промежуточными — сумма участков; участка без цены — не подходит', () => {
    expect(matchOrderToTrip({ ...order, fromCityId: 2, toCityId: 3 }, trip)).toEqual({ ok: true, fromIdx: 1, toIdx: 2, priceTotal: 500 });
    const legs = [
      { fromIdx: 0, toIdx: 1, price: 400 },
      { fromIdx: 1, toIdx: 2, price: 200 },
      { fromIdx: 2, toIdx: 3, price: 300 },
    ];
    const four: TripFacts = { ...trip, cityIds: [1, 2, 4, 3], pricing: { ...trip.pricing, stopsCount: 4, prices: legs } };
    expect(matchOrderToTrip({ ...order, fromCityId: 2, toCityId: 4 }, four)).toEqual({ ok: true, fromIdx: 1, toIdx: 2, priceTotal: 200 });
    expect(matchOrderToTrip({ ...order, fromCityId: 1, toCityId: 4 }, four)).toEqual({ ok: true, fromIdx: 0, toIdx: 2, priceTotal: 600 });
    const holey: TripFacts = { ...four, pricing: { ...four.pricing, prices: legs.slice(0, 2) } };
    expect(matchOrderToTrip({ ...order, fromCityId: 4, toCityId: 3 }, holey)).toMatchObject({ ok: false });
  });

  it('другие сутки, обратный порядок городов, нет мест, поездка не активна — не подходит', () => {
    expect(matchOrderToTrip({ ...order, departsAt: new Date('2026-10-24T07:00:00Z') }, trip)).toMatchObject({ ok: false });
    expect(matchOrderToTrip({ ...order, fromCityId: 3, toCityId: 1 }, trip)).toMatchObject({ ok: false });
    expect(matchOrderToTrip({ ...order, seats: 3 }, trip)).toMatchObject({ ok: false });
    expect(matchOrderToTrip(order, { ...trip, effectiveStatus: 'intake_closed' })).toMatchObject({ ok: false });
  });

  it('услуга, которой водитель не предлагает, и размер посылки, который он не возит, — не подходит', () => {
    expect(matchOrderToTrip({ ...order, services: ['pets'] }, trip)).toMatchObject({ ok: false });
    expect(matchOrderToTrip({ ...order, parcelSize: 'L' }, trip)).toMatchObject({ ok: false });
    expect(matchOrderToTrip({ ...order, parcelSize: 'S' }, trip)).toEqual({ ok: true, fromIdx: 0, toIdx: 2, priceTotal: 800 + 100 });
  });

  it('заказ-посылка: только если водитель разрешил посылку без проезда и есть место для посылки', () => {
    const parcel: OrderFacts = { ...order, kind: 'parcel', seats: 0, parcelSize: 'S' };
    expect(matchOrderToTrip(parcel, trip)).toMatchObject({ ok: false });
    expect(matchOrderToTrip(parcel, { ...trip, parcelOnlyAllowed: true })).toEqual({ ok: true, fromIdx: 0, toIdx: 2, priceTotal: 100 });
    expect(matchOrderToTrip(parcel, { ...trip, parcelOnlyAllowed: true, parcelSeatsFree: 0 })).toMatchObject({ ok: false });
  });
});
