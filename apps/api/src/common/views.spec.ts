/** Общие формы чтения — флаги поездки, рейтинг, телефон второй стороны. */
import { randomUUID } from 'node:crypto';
import { eq } from 'drizzle-orm';
import { type Database, createDatabase, createPool, runMigrations } from '../db/client';
import { bookings } from '../modules/bookings/internal/schema';
import { cars } from '../modules/cars/internal/schema';
import { cities } from '../modules/cities/internal/schema';
import { reviews } from '../modules/reviews/internal/schema';
import { tripPrices, tripStops, trips } from '../modules/trips/internal/schema';
import { users } from '../modules/users/internal/schema';
import { bookingViews, ratingOf, tripCards, userBrief } from './views';

const pool = createPool();
const db: Database = createDatabase(pool);

/** Уникальные города на прогон: дубли считаются по городам концов и времени. */
const tag = randomUUID().slice(0, 8);
let cityA: number;
let cityB: number;
let cityC: number;
let cityD: number;

async function city(name: string, lat: number, lng: number): Promise<number> {
  const [row] = await db
    .insert(cities)
    .values({ name: `${name}-${tag}`, region: 'тест', lat, lng })
    .returning({ id: cities.id });
  return row.id;
}

async function user(name: string | null = 'Тест'): Promise<string> {
  const phone = `+7997${String(Math.floor(Math.random() * 1e7)).padStart(7, '0')}`;
  const [row] = await db.insert(users).values({ phone, name }).returning({ id: users.id });
  return row.id;
}

/** Госномер — свой на каждое авто: у владельца номер уникален. */
let plateSeq = 0;

async function car(ownerId: string): Promise<string> {
  plateSeq += 1;
  const [row] = await db
    .insert(cars)
    .values({ ownerId, brand: 'Lada', model: 'Vesta', kind: 'car', seats: 4, plate: `А${String(plateSeq).padStart(3, '0')}АА00` })
    .returning({ id: cars.id });
  return row.id;
}

interface TripFixture {
  driverId: string;
  departsAt: Date;
  cityIds?: number[];
  createdAt?: Date;
}

async function trip(f: TripFixture): Promise<string> {
  const cityIds = f.cityIds ?? [cityA, cityB];
  const carId = await car(f.driverId);
  const [row] = await db
    .insert(trips)
    .values({
      driverId: f.driverId,
      carId,
      kind: 'ride',
      vehicleKind: 'car',
      departsAt: f.departsAt,
      arrivesAt: new Date(f.departsAt.getTime() + 3 * 3600_000),
      seatsTotal: 3,
      priceFull: 1000,
      priceBoardingMin: 100,
      bookingMode: 'standard',
      createdAt: f.createdAt ?? new Date(),
    })
    .returning({ id: trips.id });
  await db.insert(tripStops).values(cityIds.map((cityId, idx) => ({ tripId: row.id, idx, cityId, address: `адрес ${idx}` })));
  return row.id;
}

/** Завтра в 10:00 по Москве, ровно — время дублей. */
function tomorrowAt10(): Date {
  const d = new Date(Date.now() + 86_400_000);
  d.setUTCHours(7, 0, 0, 0);
  return d;
}

beforeAll(async () => {
  await runMigrations(db);
  cityA = await city('А', 57.6, 39.9);
  cityB = await city('Б', 57.2, 39.4);
  cityC = await city('В', 57.4, 39.6);
  cityD = await city('Г', 57.3, 39.5);
});

afterAll(async () => {
  await pool.end();
});

describe('views', () => {
  it('ratingOf: 0 отзывов → {value: 5, count: 0}; два отзыва → среднее', async () => {
    const lonely = await user();
    const rated = await user();
    const author = await user();
    const tripId = await trip({ driverId: rated, departsAt: new Date(tomorrowAt10().getTime() + 2 * 86_400_000) });
    await db.insert(reviews).values([
      { authorId: author, targetId: rated, tripId, rating: 4 },
      { authorId: await user(), targetId: rated, tripId, rating: 5 },
    ]);
    const map = await ratingOf(db, [lonely, rated]);
    expect(map.get(lonely)).toEqual({ value: 5, count: 0 });
    expect(map.get(rated)).toEqual({ value: 4.5, count: 2 });
  });

  it('две поездки-дубля → registrationOpen только у первой, duplicates = 2', async () => {
    const at = tomorrowAt10();
    const first = await trip({ driverId: await user(), departsAt: at, createdAt: new Date(Date.now() - 60_000) });
    const second = await trip({ driverId: await user(), departsAt: at });
    const viewer = await user();
    const [a, b] = await tripCards(db, [first, second], { viewerId: viewer });
    expect(a.id).toBe(first);
    expect(a.duplicates).toBe(2);
    expect(b.duplicates).toBe(2);
    expect(a.registrationOpen).toBe(true);
    expect(b.registrationOpen).toBe(false);
    expect(a.bookable).toBe(true);
    expect(b.bookable).toBe(false);
  });

  it('в группе дублей первой идёт водитель с отзывами, даже с низким рейтингом, раньше безотзывного', async () => {
    const at = new Date(tomorrowAt10().getTime() + 3600_000);
    const unrated = await user();
    const older = await trip({ driverId: unrated, departsAt: at, createdAt: new Date(Date.now() - 60_000) });
    const low = await user();
    const tripForReview = await trip({ driverId: low, departsAt: new Date(at.getTime() + 86_400_000) });
    await db.insert(reviews).values({ authorId: await user(), targetId: low, tripId: tripForReview, rating: 1 });
    const newer = await trip({ driverId: low, departsAt: at });
    const [o, n] = await tripCards(db, [older, newer], { viewerId: await user() });
    expect(o.registrationOpen).toBe(false);
    expect(n.registrationOpen).toBe(true);
  });

  it('в группе дублей, когда у обоих водителей есть отзывы, первой идёт бо́льший рейтинг', async () => {
    const at = new Date(tomorrowAt10().getTime() + 10 * 3600_000);
    const low = await user();
    const high = await user();
    const older = await trip({ driverId: low, departsAt: at, createdAt: new Date(Date.now() - 60_000) });
    const newer = await trip({ driverId: high, departsAt: at });
    const forReviews = await trip({ driverId: await user(), departsAt: new Date(at.getTime() + 86_400_000) });
    await db.insert(reviews).values([
      { authorId: await user(), targetId: low, tripId: forReviews, rating: 3 },
      { authorId: await user(), targetId: high, tripId: forReviews, rating: 5 },
    ]);
    const [o, n] = await tripCards(db, [older, newer], { viewerId: await user() });
    expect(o.registrationOpen).toBe(false);
    expect(n.registrationOpen).toBe(true);
  });

  it('поездка с прошедшим departs_at → effectiveStatus = completed, регистрации нет', async () => {
    const id = await trip({ driverId: await user(), departsAt: new Date(Date.now() - 3600_000) });
    const [card] = await tripCards(db, [id], { viewerId: await user() });
    expect(card.effectiveStatus).toBe('completed');
    expect(card.registrationOpen).toBe(false);
    expect(card.duplicates).toBe(1);
  });

  it('поездка с 4 остановками → stopsCount = 2, концы — первая и последняя', async () => {
    const at = new Date(tomorrowAt10().getTime() + 2 * 3600_000);
    const id = await trip({ driverId: await user(), departsAt: at, cityIds: [cityA, cityC, cityD, cityB] });
    const [card] = await tripCards(db, [id], { viewerId: await user() });
    expect(card.stopsCount).toBe(2);
    expect(card.from.cityId).toBe(cityA);
    expect(card.to.cityId).toBe(cityB);
    expect(card.to.idx).toBe(3);
  });

  it('distanceKm — от координат клиента до старта, null без координат', async () => {
    const at = new Date(tomorrowAt10().getTime() + 4 * 3600_000);
    const id = await trip({ driverId: await user(), departsAt: at });
    const viewer = await user();
    const [far] = await tripCards(db, [id], { viewerId: viewer });
    expect(far.distanceKm ?? null).toBeNull();
    const [near] = await tripCards(db, [id], { viewerId: viewer, lat: 57.6, lng: 39.9 });
    expect(near.distanceKm).toBeCloseTo(0, 5);
  });

  it('телефон водителя скрыт при requested, виден при awaiting_payment; segmentPrice', async () => {
    const at = new Date(tomorrowAt10().getTime() + 5 * 3600_000);
    const driver = await user('Водитель');
    const passenger = await user('Пассажир');
    const id = await trip({ driverId: driver, departsAt: at, cityIds: [cityA, cityC, cityB] });
    await db.insert(tripPrices).values({ tripId: id, fromIdx: 0, toIdx: 1, price: 400 });
    const [booking] = await db
      .insert(bookings)
      .values({ tripId: id, passengerId: passenger, fromIdx: 0, toIdx: 1, seats: 2, priceTotal: 800, status: 'requested' })
      .returning({ id: bookings.id });

    const [requested] = await bookingViews(db, [booking.id], { viewerId: passenger });
    expect(requested.trip.driver.phone ?? null).toBeNull();
    expect(requested.segmentPrice).toBe(400);
    expect(requested.from.idx).toBe(0);
    expect(requested.to.idx).toBe(1);
    const [forDriver] = await bookingViews(db, [booking.id], { viewerId: driver });
    expect(forDriver.passenger.phone ?? null).toBeNull();

    await db.update(bookings).set({ status: 'awaiting_payment' }).where(eq(bookings.id, booking.id));
    const [accepted] = await bookingViews(db, [booking.id], { viewerId: passenger });
    expect(accepted.trip.driver.phone).toMatch(/^\+7997/);
    const [acceptedForDriver] = await bookingViews(db, [booking.id], { viewerId: driver });
    expect(acceptedForDriver.passenger.phone).toMatch(/^\+7997/);
    const [brief] = await userBrief(db, [driver], { viewerId: await user() });
    expect(brief.phone ?? null).toBeNull();
  });

  it('segmentPrice брони между промежуточными остановками — сумма участков', async () => {
    const at = new Date(tomorrowAt10().getTime() + 5 * 3600_000 + 60_000);
    const passenger = await user();
    const id = await trip({ driverId: await user(), departsAt: at, cityIds: [cityA, cityC, cityD, cityB] });
    await db.insert(tripPrices).values([
      { tripId: id, fromIdx: 0, toIdx: 1, price: 300 },
      { tripId: id, fromIdx: 1, toIdx: 2, price: 400 },
      { tripId: id, fromIdx: 2, toIdx: 3, price: 500 },
    ]);
    const [booking] = await db
      .insert(bookings)
      .values({ tripId: id, passengerId: passenger, fromIdx: 1, toIdx: 3, seats: 1, priceTotal: 900, status: 'requested' })
      .returning({ id: bookings.id });
    const [view] = await bookingViews(db, [booking.id], { viewerId: passenger });
    expect(view.segmentPrice).toBe(900);
  });

  it('своя поездка и моя активная бронь — не bookable', async () => {
    const at = new Date(tomorrowAt10().getTime() + 6 * 3600_000);
    const driver = await user();
    const passenger = await user();
    const id = await trip({ driverId: driver, departsAt: at });
    const [own] = await tripCards(db, [id], { viewerId: driver });
    expect(own.bookable).toBe(false);
    await db.insert(bookings).values({ tripId: id, passengerId: passenger, fromIdx: 0, toIdx: 1, seats: 1, priceTotal: 1000, status: 'requested' });
    const [mine] = await tripCards(db, [id], { viewerId: passenger });
    expect(mine.bookable).toBe(false);
    const [other] = await tripCards(db, [id], { viewerId: await user() });
    expect(other.bookable).toBe(true);
  });
  /** Водитель с отзывами заданных оценок (адресат — водитель, автор — новый пользователь). */
  async function ratedDriver(ratings: number[]): Promise<string> {
    const driver = await user();
    const tripForReview = await trip({ driverId: driver, departsAt: new Date(tomorrowAt10().getTime() + 3 * 86_400_000) });
    for (const rating of ratings) {
      await db.insert(reviews).values({ authorId: await user(), targetId: driver, tripId: tripForReview, rating });
    }
    return driver;
  }

  it('плашка «Топ»: рейтинг ≥ 4.8 и ≥ 5 отзывов; меньше отзывов или ниже рейтинг — плашки нет', async () => {
    const at = new Date(tomorrowAt10().getTime() + 7 * 3600_000);
    const top = await trip({ driverId: await ratedDriver([5, 5, 5, 5, 4]), departsAt: at });
    const few = await trip({ driverId: await ratedDriver([5, 5, 5, 5]), departsAt: new Date(at.getTime() + 60_000) });
    const low = await trip({ driverId: await ratedDriver([5, 5, 5, 4, 4]), departsAt: new Date(at.getTime() + 120_000) });
    const fresh = await trip({ driverId: await user(), departsAt: new Date(at.getTime() + 180_000) });
    const cards = await tripCards(db, [top, few, low, fresh], { viewerId: await user() });
    expect(cards.map((c) => c.badge ?? null)).toEqual(['top', null, null, null]);
  });

  it('плашка «Ближайший»: одна поездка выдачи с наименьшим distanceKm, без координат — нет', async () => {
    const at = new Date(tomorrowAt10().getTime() + 8 * 3600_000);
    const fromA = await trip({ driverId: await user(), departsAt: at, cityIds: [cityA, cityB] });
    const fromC = await trip({ driverId: await user(), departsAt: new Date(at.getTime() + 60_000), cityIds: [cityC, cityB] });
    const fromD = await trip({ driverId: await user(), departsAt: new Date(at.getTime() + 120_000), cityIds: [cityD, cityB] });
    const viewer = await user();
    const near = await tripCards(db, [fromA, fromC, fromD], { viewerId: viewer, lat: 57.41, lng: 39.61 });
    expect(near.map((c) => c.badge ?? null)).toEqual([null, 'nearest', null]);
    const plain = await tripCards(db, [fromA, fromC, fromD], { viewerId: viewer });
    expect(plain.map((c) => c.badge ?? null)).toEqual([null, null, null]);
  });

  it('поездка «Топ» и «Ближайший» сразу — на карточке одна плашка, «Ближайший»', async () => {
    const at = new Date(tomorrowAt10().getTime() + 9 * 3600_000);
    const topDriver = await ratedDriver([5, 5, 5, 5, 5]);
    const nearTop = await trip({ driverId: topDriver, departsAt: at, cityIds: [cityC, cityB] });
    const farTop = await trip({ driverId: topDriver, departsAt: new Date(at.getTime() + 60_000), cityIds: [cityA, cityB] });
    const cards = await tripCards(db, [farTop, nearTop], { viewerId: await user(), lat: 57.41, lng: 39.61 });
    expect(cards.map((c) => c.badge ?? null)).toEqual(['top', 'nearest']);
  });
});

