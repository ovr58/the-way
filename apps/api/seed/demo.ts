/**
 * Демо-поездки водителей `+79000000002` и `+79000000003`: дополнение без очистки, одно
 * правило для заливки `db:seed` и ночного пополнения `db:seed:demo`. Поездки публикуются тем же
 * путём, что в приложении (`seed/services.ts`): `POST /trips`, «Добавить обратный маршрут»
 * (`POST /trips/{id}/reverse`) и правка (`PATCH /trips/{id}`) — с их проверками времени, цен,
 * авто и суточного лимита.
 *
 * «Сегодня» — `DEMO_TODAY` (YYYY-MM-DD), иначе текущая дата в `APP_TZ`. Для каждого дня
 * «сегодня … сегодня + 3», где у этих водителей нет ни одной поездки, создаётся набор из 4 поездок
 * в пределах лимита 1 + 1 на авто: у каждого водителя «туда» и обратная. Две «туда» — пара дублей
 * (одни города концов, одно время); у «туда» …02 — промежуточные остановки (одна или две) и цены
 * отрезков; «туда» …03 — быстрая, без остановок, с посылкой S и M и тремя местами для посылок;
 * обратная …03 после «Добавить обратный маршрут» правится в посылочную без мест. Обратные — на 4 ч
 * позже своей «туда», обратная …03 — ещё на 30 мин позже. Адреса — улицы и дома городов маршрута.
 * Недельный лимит (на водителя по всем его авто) — без исключений для демо-водителей:
 * водитель (легкового или автобуса), у которого на неделе дня осталось меньше двух публикаций («туда» и
 * обратная), в этот день пропускается (`withWeekRoom`); остальные публикуют свои поездки.
 * Набор дня создаётся, только если приложение его примет: «туда» позже `now()`, а последняя
 * поездка набора — не дальше `MAX_DAYS_AHEAD` суток (`too_far_ahead`); иначе день пропускается и
 * добавится следующей ночью.
 *
 * Автобусы (`BUS_LINES`): у каждого водителя автобуса на каждый такой день — «туда» на автобусе (быстрая
 * бронь) и обратная: `+79000000004` — 20 мест из 24 по маршруту дня
 * легковых, `+79000000005` — 26 мест из 30, Ярославль → Углич. День
 * проверяется у каждого водителя автобуса отдельно: есть хоть одна его поездка в этот день — не
 * добавляется. Водителя нет (база залита до него) — его автобус пропускается; нет ни одного — пометка в выводе.
 *
 * Водители легковых «своей линии» (`CAR_LINES` плана apk-acceptance-round2): `+79000000006…08` — у каждого свой
 * маршрут и своё время «туда» (рейтинг у …06 и …07 тот же, что у …03, — лента по рейтингу, с равным рейтингом идёт по времени, и на первом экране разные водители). На каждый
 * день набора — «туда» и обратная, если у водителя в этот день нет поездок, на неделе есть место (`withWeekRoom`) и
 * приложение примет набор; водителя нет (база залита до него) — линия пропускается.
 */
import { randomBytes } from 'node:crypto';
import { and, eq, inArray, sql } from 'drizzle-orm';
import { runWithContext } from '../src/common/logger';
import { type Database, type DbExecutor, createDatabase, createPool } from '../src/db/client';
import { cars } from '../src/modules/cars/internal/schema';
import { cities } from '../src/modules/cities/internal/schema';
import { OrderInput } from '../src/modules/orders/internal/orders.dto';
import { orders } from '../src/modules/orders/internal/schema';
import { WEEKLY_LIMIT, dayOf, usedInWeek } from '../src/modules/trips/internal/limits';
import { trips } from '../src/modules/trips/internal/schema';
import { MAX_DAYS_AHEAD } from '../src/common/trip-times';
import { ReverseInput, TripInput, TripPatch } from '../src/modules/trips/internal/trips.dto';
import { users } from '../src/modules/users/internal/schema';
import { body, services, type Services } from './services';

export const DEMO_DRIVER_PHONES = ['+79000000002', '+79000000003'] as const;
export const DEMO_DAYS = 4;
const YAR_REGION = 'Ярославская область';
const HOUR = 3600_000;
const DAY = 24 * HOUR;

/** Точка маршрута: город справочника и адрес в нём. */
export interface Point {
  city: string;
  address: string;
}


type Extra = { kind: 'child_seat' | 'pets' | 'luggage' | 'parcel_s' | 'parcel_m' | 'parcel_l'; price: number };

export interface Route {
  /** Посадка, остановки и высадка «туда» …02. */
  start: Point;
  mids: Point[];
  end: Point;
  /** Посадка и высадка «туда» …03 — те же города, другие адреса. */
  start03: Point;
  end03: Point;
  price02: number;
  /** Цены участков «туда» …02 между соседними точками: `mids.length + 1` чисел; `price02` — от самого дорогого до суммы. */
  legs02: number[];
  price03: number;
  extras02: Extra[];
  /** В пути, минут. */
  minutes: number;
}

/** Маршруты дня; чередуются по дате. Цены — от расстояния, все не ниже стоимости посадки 200 ₽. */
export const ROUTES: readonly Route[] = [
  {
    start: { city: 'Ярославль', address: 'Московский проспект, 80А' },
    mids: [{ city: 'Тутаев', address: 'проспект 50-летия Победы, 14' }],
    end: { city: 'Рыбинск', address: 'улица Крестовая, 40' },
    start03: { city: 'Ярославль', address: 'улица Свободы, 62' },
    end03: { city: 'Рыбинск', address: 'проспект Ленина, 151' },
    price02: 600,
    legs02: [300, 400],
    price03: 550,
    extras02: [
      { kind: 'child_seat', price: 150 },
      { kind: 'luggage', price: 150 },
    ],
    minutes: 100,
  },
  {
    start: { city: 'Ярославль', address: 'Ленинградский проспект, 54' },
    mids: [
      { city: 'Гаврилов-Ям', address: 'улица Советская, 21' },
      { city: 'Ростов', address: 'улица Ленинская, 32' },
    ],
    end: { city: 'Переславль-Залесский', address: 'улица Советская, 5' },
    start03: { city: 'Ярославль', address: 'проспект Ленина, 21' },
    end03: { city: 'Переславль-Залесский', address: 'Народная площадь, 1' },
    price02: 900,
    legs02: [300, 350, 500],
    price03: 850,
    extras02: [
      { kind: 'child_seat', price: 150 },
      { kind: 'luggage', price: 200 },
    ],
    minutes: 150,
  },
  {
    start: { city: 'Рыбинск', address: 'улица Луначарского, 8' },
    mids: [{ city: 'Мышкин', address: 'Успенская площадь, 3' }],
    end: { city: 'Углич', address: 'улица Ярославская, 52' },
    start03: { city: 'Рыбинск', address: 'улица Крестовая, 1' },
    end03: { city: 'Углич', address: 'Успенская площадь, 2' },
    price02: 600,
    legs02: [400, 300],
    price03: 650,
    extras02: [
      { kind: 'child_seat', price: 150 },
      { kind: 'pets', price: 100 },
    ],
    minutes: 120,
  },
  {
    start: { city: 'Ярославль', address: 'улица Кирова, 10' },
    mids: [
      { city: 'Тутаев', address: 'улица Ленина, 72' },
      { city: 'Рыбинск', address: 'улица Крестовая, 40' },
    ],
    end: { city: 'Пошехонье', address: 'улица Ленина, 15' },
    start03: { city: 'Ярославль', address: 'Московский проспект, 80А' },
    end03: { city: 'Пошехонье', address: 'улица Советская, 2' },
    price02: 950,
    legs02: [300, 300, 400],
    price03: 900,
    extras02: [
      { kind: 'child_seat', price: 150 },
      { kind: 'luggage', price: 150 },
      { kind: 'pets', price: 150 },
    ],
    minutes: 160,
  },
];
/** Время «туда» по дням (часы, минуты), в пределах 08:00…18:00 с шагом 30 мин. */
export const SLOTS: ReadonlyArray<readonly [number, number]> = [
  [9, 0],
  [10, 30],
  [8, 30],
  [12, 0],
];
/** Услуги и посылки «туда» …03 (посылка S и M). */
const EXTRAS_03: Extra[] = [
  { kind: 'pets', price: 150 },
  { kind: 'parcel_s', price: 150 },
  { kind: 'parcel_m', price: 250 },
];
const PARCEL_EXTRAS: Extra[] = [
  { kind: 'parcel_s', price: 150 },
  { kind: 'parcel_m', price: 250 },
];
/** Обратные — через столько после своей «туда». */
const REVERSE_02_AFTER = 4 * HOUR;
const REVERSE_03_AFTER = 4.5 * HOUR;
/** Обратная автобуса — через 5 ч после его «туда». */
const BUS_REVERSE_AFTER = 5 * HOUR;
/** Маршрут автобуса: концы без остановок, в пути и цена (`priceFull` — `price03` − 100). */
type BusRoute = Pick<Route, 'start' | 'end' | 'minutes' | 'price03'>;
/**
 * Водители автобусов: телефон, мест в продаже, маршрут (`null` — маршрут дня легковых) и сдвиг «туда»
 * от «туда» легковых. `…04` — Газель Next на 24 места, `…05` — ПАЗ Vector Next на 30.
 */
export const BUS_LINES: ReadonlyArray<{ phone: string; seatsTotal: number; route: BusRoute | null; after: number }> = [
  { phone: '+79000000004', seatsTotal: 20, route: null, after: HOUR },
  {
    phone: '+79000000005',
    seatsTotal: 26,
    route: {
      start: { city: 'Ярославль', address: 'Московский проспект, 80А' },
      end: { city: 'Углич', address: 'улица Ярославская, 52' },
      minutes: 120,
      price03: 650,
    },
    after: 2 * HOUR,
  },
];

/** Маршрут и условия «туда» водителя легкового своей линии; обратная — тем же маршрутом через `reverseAfter`. */
export interface CarLine {
  phone: string;
  /** Посадка, остановки и высадка. */
  stops: Point[];
  /** Цены участков между соседними точками (`stops.length - 1` чисел); при двух точках — пусто. */
  legs: number[];
  /** Весь маршрут: не меньше самого дорогого участка и не больше суммы участков. */
  priceFull: number;
  /** В пути, минут. */
  minutes: number;
  /** Время «туда» (часы, минуты), кратно 30 мин. */
  at: readonly [number, number];
  reverseAfter: number;
  seatsTotal: number;
  bookingMode: 'standard' | 'instant';
  extras: Extra[];
}

/**
 * Водители легковых, чьи поездки идут в ленте среди поездок …02 и …03: Игорь — Рыбинск → Тутаев → Ярославль,
 * Елена — Ростов → Переславль-Залесский, Роман — Углич → Ярославль. Время «туда» разное: между 07:30 и 14:00.
 */
export const CAR_LINES: readonly CarLine[] = [
  {
    phone: '+79000000006',
    stops: [
      { city: 'Рыбинск', address: 'улица Крестовая, 40' },
      { city: 'Тутаев', address: 'улица Ленина, 72' },
      { city: 'Ярославль', address: 'Ленинградский проспект, 54' },
    ],
    legs: [250, 300],
    priceFull: 450,
    minutes: 100,
    at: [7, 30],
    reverseAfter: 9 * HOUR,
    seatsTotal: 3,
    bookingMode: 'standard',
    extras: [
      { kind: 'luggage', price: 100 },
      { kind: 'pets', price: 100 },
    ],
  },
  {
    phone: '+79000000007',
    stops: [
      { city: 'Ростов', address: 'улица Ленинская, 32' },
      { city: 'Переславль-Залесский', address: 'улица Советская, 5' },
    ],
    legs: [],
    priceFull: 400,
    minutes: 70,
    at: [11, 0],
    reverseAfter: 5 * HOUR,
    seatsTotal: 4,
    bookingMode: 'instant',
    extras: [
      { kind: 'child_seat', price: 100 },
      { kind: 'luggage', price: 100 },
    ],
  },
  {
    phone: '+79000000008',
    stops: [
      { city: 'Углич', address: 'улица Ярославская, 52' },
      { city: 'Ярославль', address: 'проспект Ленина, 21' },
    ],
    legs: [],
    priceFull: 600,
    minutes: 130,
    at: [14, 0],
    reverseAfter: 4.5 * HOUR,
    seatsTotal: 3,
    bookingMode: 'standard',
    extras: [{ kind: 'pets', price: 100 }],
  },
];

export function appTz(): string {
  return process.env.APP_TZ ?? 'Europe/Moscow';
}

/** Дата `YYYY-MM-DD` момента `at` в поясе `tz`. */
export function dateInTz(at: Date, tz: string): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' }).format(at);
}

/** Момент «дата + часы:минуты» по стенным часам пояса `tz`. */
export function zonedTime(date: string, hours: number, minutes: number, tz: string): Date {
  const [y, m, d] = date.split('-').map(Number);
  const guess = Date.UTC(y, m - 1, d, hours, minutes);
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: tz,
    hourCycle: 'h23',
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
    hour: 'numeric',
    minute: 'numeric',
  }).formatToParts(new Date(guess));
  const get = (type: string): number => Number(parts.find((p) => p.type === type)?.value);
  const asIfUtc = Date.UTC(get('year'), get('month') - 1, get('day'), get('hour'), get('minute'));
  return new Date(guess - (asIfUtc - guess));
}

export function addDays(date: string, days: number): string {
  const [y, m, d] = date.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d + days)).toISOString().slice(0, 10);
}

/** Номер дня для чередования маршрутов и времени. */
function dayOrdinal(date: string): number {
  return Math.floor(Date.parse(`${date}T00:00:00Z`) / 86_400_000);
}

/** id городов маршрутов в справочнике (Ярославская область). */
export async function routeCityIds(tx: DbExecutor): Promise<Map<string, number>> {
  const names = [
    ...new Set([
      ...ROUTES.flatMap((r) => [r.start, ...r.mids, r.end, r.start03, r.end03].map((p) => p.city)),
      ...BUS_LINES.flatMap((l) => (l.route ? [l.route.start.city, l.route.end.city] : [])),
      ...CAR_LINES.flatMap((l) => l.stops.map((p) => p.city)),
    ]),
  ];
  const rows = await tx
    .select({ id: cities.id, name: cities.name })
    .from(cities)
    .where(and(inArray(cities.name, names), eq(cities.region, YAR_REGION)));
  const map = new Map(rows.map((r) => [r.name, r.id]));
  for (const name of names) if (!map.has(name)) throw new Error(`В справочнике нет города ${name} (${YAR_REGION})`);
  return map;
}

export interface DemoDriver {
  id: string;
  carId: string;
}

export async function demoDrivers(tx: DbExecutor): Promise<[DemoDriver, DemoDriver]> {
  const found: DemoDriver[] = [];
  for (const phone of DEMO_DRIVER_PHONES) {
    const [row] = await tx
      .select({ id: users.id, carId: cars.id })
      .from(users)
      .innerJoin(cars, eq(cars.ownerId, users.id))
      .where(and(eq(users.phone, phone), sql`${cars.deletedAt} is null`))
      .limit(1);
    if (!row) throw new Error(`Нет демо-водителя ${phone} с авто — сначала npm run db:seed`);
    found.push(row);
  }
  return [found[0], found[1]];
}

/** Водитель с авто вида `kind` (автобус или легковое); `null` — водителя ещё нет (база залита до него). */
async function lineDriver(tx: DbExecutor, phone: string, kind: 'bus' | 'car'): Promise<DemoDriver | null> {
  const [row] = await tx
    .select({ id: users.id, carId: cars.id })
    .from(users)
    .innerJoin(cars, eq(cars.ownerId, users.id))
    .where(and(eq(users.phone, phone), eq(cars.kind, kind), sql`${cars.deletedAt} is null`))
    .limit(1);
  return row ?? null;
}

/** Тело `POST /trips` «туда» автобуса: концы маршрута без остановок, быстрая бронь. */
function busInput(route: BusRoute, carId: string, ids: Map<string, number>, departsAt: Date, seatsTotal: number): object {
  return {
    kind: 'ride',
    vehicleKind: 'bus',
    stops: [route.start, route.end].map((p) => ({ cityId: ids.get(p.city), address: p.address })),
    departsAt: departsAt.toISOString(),
    arrivesAt: new Date(departsAt.getTime() + route.minutes * 60_000).toISOString(),
    seatsTotal,
    priceFull: route.price03 - 100,
    prices: [],
    priceBoardingMin: 200,
    carId,
    extras: [{ kind: 'luggage', price: 100 }],
    parcelOnlyAllowed: false,
    parcelSeatsTotal: 0,
    bookingMode: 'instant',
  };
}

/** «Туда» и обратная автобуса; возвращает id обеих. */
async function publishBusDay(
  s: Services,
  bus: DemoDriver,
  route: BusRoute,
  ids: Map<string, number>,
  departsAt: Date,
  seatsTotal: number,
): Promise<string[]> {
  const forward = await s.trips.create(bus.id, await body(TripInput, busInput(route, bus.carId, ids, departsAt, seatsTotal)));
  const reverse = await s.trips.reverse(bus.id, forward.id, await body(ReverseInput, reverseInput(route, departsAt, BUS_REVERSE_AFTER)));
  return [forward.id, reverse.id];
}

/** Тело `POST /trips` «туда» водителя своей линии `CAR_LINES`. */
export function lineInput(line: CarLine, carId: string, ids: Map<string, number>, departsAt: Date): object {
  return {
    kind: 'ride',
    vehicleKind: 'car',
    stops: line.stops.map((p) => ({ cityId: ids.get(p.city), address: p.address })),
    departsAt: departsAt.toISOString(),
    arrivesAt: new Date(departsAt.getTime() + line.minutes * 60_000).toISOString(),
    seatsTotal: line.seatsTotal,
    priceFull: line.priceFull,
    prices: line.legs.map((price, k) => ({ fromIdx: k, toIdx: k + 1, price })),
    priceBoardingMin: 200,
    carId,
    extras: line.extras,
    parcelOnlyAllowed: false,
    parcelSeatsTotal: 0,
    bookingMode: line.bookingMode,
  };
}

/** «Туда» и обратная водителя своей линии; возвращает id обеих. */
async function publishLineDay(
  s: Services,
  driver: DemoDriver,
  line: CarLine,
  ids: Map<string, number>,
  departsAt: Date,
): Promise<string[]> {
  const forward = await s.trips.create(driver.id, await body(TripInput, lineInput(line, driver.carId, ids, departsAt)));
  const reverse = await s.trips.reverse(driver.id, forward.id, await body(ReverseInput, reverseInput(line, departsAt, line.reverseAfter)));
  return [forward.id, reverse.id];
}

/** Роль демо-водителя: …02 — стандартная бронь и остановки, …03 — быстрая бронь и посылки. */
export type Role = '02' | '03';

/** Тело `POST /trips` «туда» водителя роли на маршруте. */
export function forwardInput(route: Route, role: Role, carId: string, ids: Map<string, number>, departsAt: Date): object {
  const stop = (p: Point): object => ({ cityId: ids.get(p.city), address: p.address });
  const common = {
    kind: 'ride',
    vehicleKind: 'car',
    departsAt: departsAt.toISOString(),
    arrivesAt: new Date(departsAt.getTime() + route.minutes * 60_000).toISOString(),
    priceBoardingMin: 200,
    carId,
  };
  if (role === '02') {
    return {
      ...common,
      stops: [route.start, ...route.mids, route.end].map(stop),
      seatsTotal: 3,
      priceFull: route.price02,
      prices: route.legs02.map((price, k) => ({ fromIdx: k, toIdx: k + 1, price })),
      extras: route.extras02,
      parcelOnlyAllowed: false,
      parcelSeatsTotal: 0,
      bookingMode: 'standard',
    };
  }
  return {
    ...common,
    stops: [route.start03, route.end03].map(stop),
    seatsTotal: 4,
    priceFull: route.price03,
    prices: [],
    extras: EXTRAS_03,
    parcelOnlyAllowed: true,
    parcelSeatsTotal: 3,
    bookingMode: 'instant',
  };
}

/** Тело «Добавить обратный маршрут»: отправление через `after` после «туда», в пути столько же. */
function reverseInput(route: Pick<Route, 'minutes'>, forwardAt: Date, after: number): object {
  const departsAt = new Date(forwardAt.getTime() + after);
  return {
    departsAt: departsAt.toISOString(),
    arrivesAt: new Date(departsAt.getTime() + route.minutes * 60_000).toISOString(),
  };
}

/** Публикаций в день у демо-водителя: «туда» и обратная. */
const DAY_PUBLICATIONS = 2;

/**
 * Водители, у которых на неделе момента `at` осталось место на «туда» и обратную; водитель
 * без остатка пропускается — пополнение не превышает лимит и не оставляет «туда» без обратной.
 */
export async function withWeekRoom<T extends DemoDriver>(tx: DbExecutor, drivers: T[], at: Date): Promise<T[]> {
  const room: T[] = [];
  for (const d of drivers) {
    if ((await usedInWeek(tx, d.id, dayOf(at))) + DAY_PUBLICATIONS <= WEEKLY_LIMIT) room.push(d);
  }
  return room;
}

/** Поездки набора дня (для броней seed); водитель без недельного остатка — без своих поездок. */
export interface DemoDay {
  date: string;
  forward02?: string;
  forward03?: string;
  reverse02?: string;
  reverse03?: string;
  /** Последний индекс остановки обратной …02. */
  reverse02Last: number;
}

export interface DemoResult {
  created: DemoDay[];
  /** Дни без поездок, которые приложение не примет: «туда» уже прошла или дальше `MAX_DAYS_AHEAD`. */
  skipped: string[];
  /** Добавлено демо-заказов пассажиров. */
  orders: number;
  /** Добавлено поездок автобусов; `null` — ни одного водителя автобуса нет. */
  busTrips: number | null;
  /** Добавлено поездок водителей легковых из `CAR_LINES`. */
  carLineTrips: number;
}

/**
 * Демо-заказы пассажиров (план passenger-order, Б1.5): на завтра и послезавтра — поездка и посылка,
 * чтобы лента «Заказы пассажиров» у водителя не была пустой. Публикуются тем же путём, что в
 * приложении (`POST /orders`); заказ дня у пассажира уже есть — не повторяется.
 */
const DEMO_ORDERS = [
  {
    phone: '+79000000013',
    from: { city: 'Ярославль', address: 'улица Свободы, 62' },
    to: { city: 'Рыбинск', address: 'улица Крестовая, 40' },
    at: [15, 0],
    minutes: 100,
    input: { kind: 'ride', seats: 2, parcelSize: 'none', extras: ['child_seat'] },
  },
  {
    phone: '+79000000014',
    from: { city: 'Ярославль', address: 'Московский проспект, 80А' },
    to: { city: 'Ростов', address: 'улица Ленинская, 32' },
    at: [11, 30],
    minutes: 80,
    input: { kind: 'parcel', seats: 0, parcelSize: 'M', parcelComment: 'Документы в папке', extras: [] },
  },
] as const;

/** Дни демо-заказов от «сегодня». */
const DEMO_ORDER_DAYS = [1, 2];

async function seedDemoOrders(tx: DbExecutor, s: Services, ids: Map<string, number>, today: string, now: Date): Promise<number> {
  const tz = appTz();
  let count = 0;
  for (const spec of DEMO_ORDERS) {
    const [user] = await tx.select({ id: users.id }).from(users).where(eq(users.phone, spec.phone));
    if (!user) continue;
    for (const offset of DEMO_ORDER_DAYS) {
      const date = addDays(today, offset);
      const departsAt = zonedTime(date, spec.at[0], spec.at[1], tz);
      if (departsAt.getTime() <= now.getTime() || departsAt.getTime() > now.getTime() + MAX_DAYS_AHEAD * DAY) continue;
      const existing = await tx.$count(
        orders,
        and(eq(orders.passengerId, user.id), sql`(${orders.departsAt} at time zone ${tz})::date = ${date}::date`),
      );
      if (existing > 0) continue;
      await s.orders.create(
        user.id,
        await body(OrderInput, {
          ...spec.input,
          stops: [
            { cityId: ids.get(spec.from.city), address: spec.from.address },
            { cityId: ids.get(spec.to.city), address: spec.to.address },
          ],
          departsAt: departsAt.toISOString(),
          arrivesAt: new Date(departsAt.getTime() + spec.minutes * 60_000).toISOString(),
        }),
      );
      count += 1;
    }
  }
  return count;
}

/** Публикует набор дня от имени водителей, как это делает приложение; `null` — водитель пропущен. */
async function publishDay(
  s: Services,
  [d02, d03]: [DemoDriver | null, DemoDriver | null],
  route: Route,
  ids: Map<string, number>,
  date: string,
  forwardAt: Date,
): Promise<DemoDay> {
  const day: DemoDay = { date, reverse02Last: route.mids.length + 1 };
  if (d02) {
    const forward02 = await s.trips.create(d02.id, await body(TripInput, forwardInput(route, '02', d02.carId, ids, forwardAt)));
    const reverse02 = await s.trips.reverse(
      d02.id,
      forward02.id,
      await body(ReverseInput, reverseInput(route, forwardAt, REVERSE_02_AFTER)),
    );
    Object.assign(day, { forward02: forward02.id, reverse02: reverse02.id });
  }
  if (d03) {
    const forward03 = await s.trips.create(d03.id, await body(TripInput, forwardInput(route, '03', d03.carId, ids, forwardAt)));
    const reverse03 = await s.trips.reverse(
      d03.id,
      forward03.id,
      await body(ReverseInput, reverseInput(route, forwardAt, REVERSE_03_AFTER)),
    );
    // Обратная …03 — посылочная без мест: водитель правит тип поездки после «Добавить обратный маршрут».
    await s.trips.update(
      d03.id,
      reverse03.id,
      await body(TripPatch, { kind: 'parcel', seatsTotal: 0, extras: PARCEL_EXTRAS, parcelOnlyAllowed: true }),
    );
    Object.assign(day, { forward03: forward03.id, reverse03: reverse03.id });
  }
  return day;
}

/** Создаёт недостающие дневные наборы; возвращает созданные и пропущенные дни. */
export async function seedDemo(tx: DbExecutor, now: Date = new Date()): Promise<DemoResult> {
  const tz = appTz();
  const today = process.env.DEMO_TODAY ?? dateInTz(now, tz);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(today)) throw new Error(`DEMO_TODAY: ожидается YYYY-MM-DD, получено ${today}`);
  const drivers = await demoDrivers(tx);
  const ids = await routeCityIds(tx);
  const s = services(tx);
  const buses: { line: (typeof BUS_LINES)[number]; driver: DemoDriver }[] = [];
  for (const line of BUS_LINES) {
    const driver = await lineDriver(tx, line.phone, 'bus');
    if (driver) buses.push({ line, driver });
  }
  const carLines: { line: CarLine; driver: DemoDriver }[] = [];
  for (const line of CAR_LINES) {
    const driver = await lineDriver(tx, line.phone, 'car');
    if (driver) carLines.push({ line, driver });
  }
  let busTrips = 0;
  const result: DemoResult = { created: [], skipped: [], orders: 0, busTrips: null, carLineTrips: 0 };

  for (let i = 0; i < DEMO_DAYS; i += 1) {
    const date = addDays(today, i);
    const existing = await tx.$count(
      trips,
      and(
        inArray(
          trips.driverId,
          drivers.map((d) => d.id),
        ),
        sql`(${trips.departsAt} at time zone ${tz})::date = ${date}::date`,
      ),
    );
    const ordinal = dayOrdinal(date);
    const route = ROUTES[ordinal % ROUTES.length];
    const [h, m] = SLOTS[ordinal % SLOTS.length];
    const forwardAt = zonedTime(date, h, m, tz);
    const accepted = (first: number, last: number): boolean =>
      first > now.getTime() && last <= now.getTime() + MAX_DAYS_AHEAD * DAY;
    for (const { line, driver } of buses) {
      const busAt = new Date(forwardAt.getTime() + line.after);
      const busExisting = await tx.$count(
        trips,
        and(eq(trips.driverId, driver.id), sql`(${trips.departsAt} at time zone ${tz})::date = ${date}::date`),
      );
      const hasRoom = (await withWeekRoom(tx, [driver], busAt)).length > 0;
      if (busExisting === 0 && hasRoom && accepted(busAt.getTime(), busAt.getTime() + BUS_REVERSE_AFTER)) {
        busTrips += (await publishBusDay(s, driver, line.route ?? route, ids, busAt, line.seatsTotal)).length;
      }
    }
    for (const { line, driver } of carLines) {
      const lineAt = zonedTime(date, line.at[0], line.at[1], tz);
      const lineExisting = await tx.$count(
        trips,
        and(eq(trips.driverId, driver.id), sql`(${trips.departsAt} at time zone ${tz})::date = ${date}::date`),
      );
      const hasRoom = (await withWeekRoom(tx, [driver], lineAt)).length > 0;
      if (lineExisting === 0 && hasRoom && accepted(lineAt.getTime(), lineAt.getTime() + line.reverseAfter)) {
        result.carLineTrips += (await publishLineDay(s, driver, line, ids, lineAt)).length;
      }
    }
    if (existing > 0) continue;
    if (!accepted(forwardAt.getTime(), forwardAt.getTime() + REVERSE_03_AFTER)) {
      result.skipped.push(date);
      continue;
    }
    const room = await withWeekRoom(tx, drivers, forwardAt);
    if (room.length === 0) continue;
    const [d02, d03] = drivers;
    result.created.push(await publishDay(s, [room.includes(d02) ? d02 : null, room.includes(d03) ? d03 : null], route, ids, date, forwardAt));
  }
  result.orders = await seedDemoOrders(tx, s, ids, today, now);
  result.busTrips = buses.length ? busTrips : null;
  return result;
}

/** Контекст журнала событий для скриптов seed: строки лога сервисов несут один `trace_id`. */
export function inSeedContext<T>(fn: () => T): T {
  return runWithContext({ traceId: randomBytes(16).toString('hex') }, fn);
}

async function main(): Promise<void> {
  const pool = createPool();
  try {
    const db: Database = createDatabase(pool);
    const { created, skipped, orders: orderCount, busTrips, carLineTrips } = await inSeedContext(() => db.transaction((tx) => seedDemo(tx)));
    const later = skipped.length ? `; приложение пока не примет (прошло или дальше ${MAX_DAYS_AHEAD} суток): ${skipped.join(', ')}` : '';
    const busLine =
      busTrips === null
        ? `нет водителей автобусов ${BUS_LINES.map((l) => l.phone).join(', ')} — сначала npm run db:seed`
        : `поездок автобусов ${busTrips}`;
    process.stdout.write(
      `Демо-поездки: добавлено дней ${created.length}, поездок ${created.reduce((n, d) => n + (d.forward02 ? 2 : 0) + (d.forward03 ? 2 : 0), 0)}${later}; ${busLine}; поездок водителей легковых ${carLineTrips}; демо-заказов ${orderCount}.\n`,
    );
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  main().catch((error: unknown) => {
    process.stderr.write(`${error instanceof Error ? error.stack ?? error.message : String(error)}\n`);
    process.exitCode = 1;
  });
}
