/**
 * Завершённые поездки демо-водителей с отзывами (кадр «Базовые экраны - Поездки есть»): рейтинг и «N поездок»
 * в ленте — из настоящей истории, а не из подставленных чисел.
 *
 * Каждая поездка проходит путь приложения целиком: водитель публикует её на завтра
 * (`POST /trips`), пассажиры бронируют (`POST /trips/{id}/bookings`), водитель подтверждает
 * стандартную бронь, пассажир оплачивает. Затем — две записи мимо сервисов, потому что у
 * приложения для них пути нет:
 * 1. Сдвиг времени поездки и её броней на `daysAgo + 1` суток назад: опубликовать поездку в
 *    прошлом приложение не даёт (отправление не раньше `now()`), а «завершена» = отправление прошло.
 * Пока поездка не сдвинута, следующая на те же сутки упёрлась бы в суточный лимит.
 * 2. Отзывы: в приложении записи отзывов нет (`reviews.service.ts` — только чтение, интерфейса нет по
 *    `docs/task.md`). Отзыв — от пассажира оплаченной брони этой поездки, после прибытия.
 *
 * Рейтинги: …03 — 4,9 из 7 отзывов (плашка «Топ»: ≥ 4,8 и ≥ 5 отзывов), …02 — 4,2 из 5; у …01
 * поездок и отзывов нет («5 ★, нет отзывов»). У …03 рейтинг выше — в паре дублей завтрашнего дня
 * регистрация открыта на его поездке («Флаги поездки»). Водители своих линий (`CAR_LINES`): …06 — 4,9 из 7
 * («Топ»), …07 — 4,9 из 7, …08 — 4,0 из 3. У …06 и …07 среднее 34/7 = 4,857, после округления до 0,1 (`ratingOf`) —
 * как у …03: лента идёт по рейтингу ↓ (FR-09), и с равным рейтингом водители перемешиваются по времени выезда —
 * на первом экране не один водитель. Поездки истории — на маршрутах линий, в этой и прошлых неделях, но так, чтобы
 * остаток недельного лимита позволил публиковать поездки на ближайшие дни.
 */
import { eq, sql } from 'drizzle-orm';
import type { DbExecutor } from '../src/db/client';
import { BookingInput } from '../src/modules/bookings/internal/bookings.dto';
import { bookings } from '../src/modules/bookings/internal/schema';
import { reviews } from '../src/modules/reviews/internal/schema';
import { trips } from '../src/modules/trips/internal/schema';
import { TripInput } from '../src/modules/trips/internal/trips.dto';
import { addDays, appTz, CAR_LINES, dateInTz, forwardInput, lineInput, ROUTES, SLOTS, zonedTime, type DemoDriver, type Role } from './demo';
import { body, type Services } from './services';

/** Пассажиры истории: авторы отзывов (у входных пассажиров …11 и …12 истории нет). */
export const HISTORY_PASSENGERS: ReadonlyArray<readonly [string, string]> = [
  ['+79000000013', 'Светлана'],
  ['+79000000014', 'Павел'],
  ['+79000000015', 'Екатерина'],
  ['+79000000016', 'Андрей'],
  ['+79000000017', 'Наталья'],
  ['+79000000018', 'Сергей'],
];

interface Rider {
  phone: string;
  seats: number;
  fromIdx?: number;
  toIdx?: number;
  parcel?: 'S' | 'M';
  parcelOnly?: boolean;
  extras?: ('child_seat' | 'pets' | 'luggage')[];
  /** Оценка водителю; нет — пассажир отзыв не оставил. */
  rating?: number;
  text?: string | null;
}

interface PastTrip {
  role: Role;
  daysAgo: number;
  route: number;
  riders: Rider[];
}

const HISTORY: readonly PastTrip[] = [
  {
    role: '03',
    daysAgo: 2,
    route: 0,
    riders: [
      { phone: '+79000000013', seats: 1, rating: 5, text: 'Быстро доехали, машина чистая.' },
      { phone: '+79000000014', seats: 1, parcel: 'M', rating: 5, text: null },
    ],
  },
  {
    role: '03',
    daysAgo: 4,
    route: 1,
    riders: [
      { phone: '+79000000015', seats: 2, extras: ['pets'], rating: 5, text: 'Спокойная езда, разрешил взять собаку.' },
      { phone: '+79000000016', seats: 0, parcel: 'S', parcelOnly: true, rating: 4, text: 'Посылку довёз целой, но позвонил поздно.' },
    ],
  },
  {
    role: '03',
    daysAgo: 6,
    route: 2,
    riders: [
      { phone: '+79000000017', seats: 1, rating: 5, text: 'Вежливый водитель, всё чётко.' },
      { phone: '+79000000018', seats: 1, rating: 5, text: 'Рекомендую.' },
    ],
  },
  {
    role: '03',
    daysAgo: 9,
    route: 3,
    riders: [
      { phone: '+79000000013', seats: 1, rating: 5, text: null },
      { phone: '+79000000014', seats: 2 },
    ],
  },
  {
    role: '02',
    daysAgo: 1,
    route: 0,
    riders: [
      { phone: '+79000000016', seats: 1, fromIdx: 0, toIdx: 1, rating: 4, text: 'Нормально, но ждали на остановке минут десять.' },
      { phone: '+79000000017', seats: 1, extras: ['luggage'], rating: 5, text: 'Приятная поездка, помогла с чемоданом.' },
    ],
  },
  {
    role: '02',
    daysAgo: 3,
    route: 1,
    riders: [
      { phone: '+79000000018', seats: 1, rating: 3, text: 'Опоздала на двадцать минут.' },
      { phone: '+79000000015', seats: 2, fromIdx: 2, toIdx: 3, rating: 4, text: null },
    ],
  },
  {
    role: '02',
    daysAgo: 5,
    route: 2,
    riders: [
      { phone: '+79000000014', seats: 1, extras: ['child_seat'], rating: 5, text: 'Удобно, что есть детское кресло.' },
      { phone: '+79000000013', seats: 1 },
    ],
  },
];

/** История водителей своих линий: `line` — телефон из `CAR_LINES`; поездка — на маршруте линии. */
const LINE_HISTORY: ReadonlyArray<Pick<PastTrip, 'daysAgo' | 'riders'> & { line: string }> = [
  {
    line: '+79000000006',
    daysAgo: 2,
    riders: [
      { phone: '+79000000013', seats: 1, rating: 5, text: 'Выехали вовремя, ехал аккуратно.' },
      { phone: '+79000000014', seats: 1, fromIdx: 0, toIdx: 1, rating: 5, text: null },
    ],
  },
  {
    line: '+79000000006',
    daysAgo: 5,
    riders: [
      { phone: '+79000000015', seats: 2, rating: 5, text: 'Всё чётко, довёз до самого дома.' },
      { phone: '+79000000016', seats: 1, rating: 5, text: null },
    ],
  },
  {
    line: '+79000000006',
    daysAgo: 8,
    riders: [
      { phone: '+79000000017', seats: 1, rating: 5, text: null },
      { phone: '+79000000018', seats: 1, rating: 4, text: 'Хорошо, но в салоне было прохладно.' },
    ],
  },
  {
    line: '+79000000006',
    daysAgo: 11,
    riders: [
      { phone: '+79000000013', seats: 1, rating: 5, text: 'Как всегда вовремя.' },
      { phone: '+79000000014', seats: 1 },
    ],
  },
  {
    line: '+79000000007',
    daysAgo: 3,
    riders: [
      { phone: '+79000000013', seats: 1, rating: 5, text: 'Приехали раньше времени, спасибо!' },
      { phone: '+79000000015', seats: 1, rating: 5, text: 'Музыка тихая, ехать комфортно.' },
    ],
  },
  {
    line: '+79000000007',
    daysAgo: 7,
    riders: [
      { phone: '+79000000016', seats: 2, rating: 5, text: null },
      { phone: '+79000000017', seats: 1, extras: ['luggage'], rating: 4, text: 'Багажа много, места было впритык.' },
    ],
  },
  {
    line: '+79000000007',
    daysAgo: 10,
    riders: [
      { phone: '+79000000014', seats: 1, rating: 5, text: 'Аккуратная езда, всё понравилось.' },
      { phone: '+79000000018', seats: 1, rating: 5, text: null },
    ],
  },
  {
    line: '+79000000007',
    daysAgo: 13,
    riders: [{ phone: '+79000000015', seats: 1, rating: 5, text: 'Рекомендую.' }],
  },
  {
    line: '+79000000008',
    daysAgo: 1,
    riders: [
      { phone: '+79000000014', seats: 1, rating: 5, text: 'Спокойно и без спешки.' },
      { phone: '+79000000018', seats: 1, rating: 4, text: null },
    ],
  },
  {
    line: '+79000000008',
    daysAgo: 4,
    riders: [
      { phone: '+79000000015', seats: 1, rating: 3, text: 'Ждали отправления сорок минут.' },
      { phone: '+79000000013', seats: 1 },
    ],
  },
];

/** Отзыв оставлен через столько после прибытия. */
const REVIEW_AFTER_MS = 3 * 3600_000;

/** Сдвиг поездки и её броней на `days` суток назад — единственная запись времени мимо сервисов. */
async function shiftBack(tx: DbExecutor, tripId: string, days: number): Promise<void> {
  const by = sql`make_interval(days => ${days})`;
  await tx
    .update(trips)
    .set({
      departsAt: sql`${trips.departsAt} - ${by}`,
      arrivesAt: sql`${trips.arrivesAt} - ${by}`,
      createdAt: sql`${trips.createdAt} - ${by}`,
    })
    .where(eq(trips.id, tripId));
  await tx
    .update(bookings)
    .set({
      createdAt: sql`${bookings.createdAt} - ${by}`,
      confirmedAt: sql`${bookings.confirmedAt} - ${by}`,
      paidAt: sql`${bookings.paidAt} - ${by}`,
    })
    .where(eq(bookings.tripId, tripId));
}

/** Публикует, бронирует, оплачивает и переносит в прошлое историю; возвращает число поездок и отзывов. */
export async function seedHistory(
  tx: DbExecutor,
  s: Services,
  drivers: Record<Role, DemoDriver>,
  lines: Map<string, DemoDriver>,
  passengerIds: Map<string, string>,
  ids: Map<string, number>,
): Promise<{ trips: number; reviews: number }> {
  const tz = appTz();
  const tomorrow = addDays(dateInTz(new Date(), tz), 1);
  let reviewCount = 0;
  const planned: { past: Pick<PastTrip, 'daysAgo' | 'riders'>; driver: DemoDriver; input: object }[] = [
    ...HISTORY.map((past) => {
      const driver = drivers[past.role];
      const [h, m] = SLOTS[past.route];
      return { past, driver, input: forwardInput(ROUTES[past.route], past.role, driver.carId, ids, zonedTime(tomorrow, h, m, tz)) };
    }),
    ...LINE_HISTORY.map((past) => {
      const driver = lines.get(past.line) as DemoDriver;
      const line = CAR_LINES.find((l) => l.phone === past.line) as (typeof CAR_LINES)[number];
      return { past, driver, input: lineInput(line, driver.carId, ids, zonedTime(tomorrow, line.at[0], line.at[1], tz)) };
    }),
  ];
  for (const { past, driver, input } of planned) {
    const trip = await s.trips.create(driver.id, await body(TripInput, input));
    const last = trip.stops.length - 1;

    const paid: { rider: Rider; bookingId: string; passengerId: string }[] = [];
    for (const rider of past.riders) {
      const passengerId = passengerIds.get(rider.phone) as string;
      const created = await s.bookings.create(
        passengerId,
        trip.id,
        await body(BookingInput, {
          fromIdx: rider.fromIdx ?? 0,
          toIdx: rider.toIdx ?? last,
          seats: rider.seats,
          parcelSize: rider.parcel ?? 'none',
          parcelOnly: rider.parcelOnly ?? false,
          extras: rider.extras ?? [],
        }),
      );
      if (created.status === 'requested') await s.bookings.confirm(driver.id, created.id);
      await s.bookings.pay(passengerId, created.id);
      paid.push({ rider, bookingId: created.id, passengerId });
    }

    await shiftBack(tx, trip.id, past.daysAgo + 1);
    const [moved] = await tx.select({ arrivesAt: trips.arrivesAt }).from(trips).where(eq(trips.id, trip.id));
    const rated = paid.filter((p) => p.rider.rating !== undefined);
    if (rated.length) {
      await tx.insert(reviews).values(
        rated.map((p, k) => ({
          authorId: p.passengerId,
          targetId: driver.id,
          tripId: trip.id,
          bookingId: p.bookingId,
          rating: p.rider.rating as number,
          body: p.rider.text ?? null,
          createdAt: new Date(moved.arrivesAt.getTime() + REVIEW_AFTER_MS + k * 3600_000),
        })),
      );
    }
    reviewCount += rated.length;
  }
  return { trips: planned.length, reviews: reviewCount };
}
