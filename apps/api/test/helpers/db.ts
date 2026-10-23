/**
 * База проверок — из `DATABASE_URL` окружения (у каждой строки своя `dev_<N>`; имя базы в коде
 * не пишется); миграции накатываются здесь. Фикстуры чужих модулей — прямой вставкой: HTTP —
 * только для действия под проверкой. Города каждого прогона уникальны (`TAG`): дубли поездок
 * считаются по городам, и прошлые прогоны в той же базе не мешают.
 */
import { randomUUID } from 'node:crypto';
import { type Database, createDatabase, createPool, runMigrations } from '../../src/db/client';
import { sessions } from '../../src/modules/auth/internal/schema';
import { hashSessionToken, newSessionToken } from '../../src/modules/auth/internal/session-token';
import { bookingExtras, bookings } from '../../src/modules/bookings/internal/schema';
import { cars } from '../../src/modules/cars/internal/schema';
import { orderExtras, orderStops, orders } from '../../src/modules/orders/internal/schema';
import { cities } from '../../src/modules/cities/internal/schema';
import { reviews } from '../../src/modules/reviews/internal/schema';
import { tripExtras, tripPrices, tripStops, trips } from '../../src/modules/trips/internal/schema';
import { cancellations, users } from '../../src/modules/users/internal/schema';
import type {
  BookingMode,
  BookingStatus,
  CancellationRole,
  ExtraKind,
  OrderStatusStored,
  ParcelSize,
  ServiceKind,
  TripKind,
  TripStatus,
  UserMode,
  VehicleKind,
} from '../../src/common/enums';
import { DAY } from './dates';

export const TAG = randomUUID().slice(0, 8);

const pool = createPool();
export const db: Database = createDatabase(pool);

export async function migrate(): Promise<void> {
  await runMigrations(db);
}

export async function closeDb(): Promise<void> {
  await pool.end();
}

export function randomPhone(): string {
  return `+7990${String(Math.floor(Math.random() * 1e7)).padStart(7, '0')}`;
}

export async function createCity(name: string, lat: number, lng: number): Promise<number> {
  const [row] = await db
    .insert(cities)
    .values({ name: `${name}-${TAG}`, region: `проверки ${TAG}`, lat, lng })
    .returning({ id: cities.id });
  return row.id;
}

export interface TestUser {
  id: string;
  phone: string;
  /** Bearer-токен живой сессии. */
  token: string;
}

export async function createUser(opts: { name?: string | null; mode?: UserMode; blockedUntil?: Date } = {}): Promise<TestUser> {
  const phone = randomPhone();
  const [row] = await db
    .insert(users)
    .values({
      phone,
      name: opts.name === undefined ? 'Проверка' : opts.name,
      currentMode: opts.mode ?? 'passenger',
      blockedUntil: opts.blockedUntil ?? null,
    })
    .returning({ id: users.id });
  const token = newSessionToken();
  await db.insert(sessions).values({ tokenHash: hashSessionToken(token), userId: row.id, expiresAt: new Date(Date.now() + 30 * DAY) });
  return { id: row.id, phone, token };
}

/**
 * Госномер фикстуры: у первого авто владельца — «А000АА76», у следующих — «А001АА76», «А002АА76»…
 * У владельца номер уникален.
 */
const carsByOwner = new Map<string, number>();

export async function createCar(ownerId: string, seats = 4, kind: VehicleKind = 'car'): Promise<string> {
  const n = carsByOwner.get(ownerId) ?? 0;
  carsByOwner.set(ownerId, n + 1);
  const plate = `А${String(n).padStart(3, '0')}АА76`;
  const [row] = await db
    .insert(cars)
    .values({ ownerId, brand: 'Lada', model: 'Vesta', kind, seats, plate, status: 'verified' })
    .returning({ id: cars.id });
  return row.id;
}

export interface TripFixture {
  driverId: string;
  carId?: string;
  cityIds: number[];
  departsAt: Date;
  arrivesAt?: Date;
  kind?: TripKind;
  seatsTotal?: number;
  seatsTaken?: number;
  priceFull?: number;
  priceBoardingMin?: number;
  prices?: { fromIdx: number; toIdx: number; price: number }[];
  extras?: { kind: ExtraKind; price: number }[];
  bookingMode?: BookingMode;
  status?: TripStatus;
  reverseOf?: string | null;
  parcelOnlyAllowed?: boolean;
  parcelSeatsTotal?: number;
  parcelSeatsTaken?: number;
  createdAt?: Date;
}

export async function createTrip(f: TripFixture): Promise<string> {
  const carId = f.carId ?? (await createCar(f.driverId));
  const [row] = await db
    .insert(trips)
    .values({
      driverId: f.driverId,
      carId,
      kind: f.kind ?? 'ride',
      vehicleKind: 'car',
      departsAt: f.departsAt,
      arrivesAt: f.arrivesAt ?? new Date(f.departsAt.getTime() + 2 * 3600_000),
      seatsTotal: f.seatsTotal ?? 3,
      seatsTaken: f.seatsTaken ?? 0,
      priceFull: f.priceFull ?? 1000,
      priceBoardingMin: f.priceBoardingMin ?? 100,
      bookingMode: f.bookingMode ?? 'standard',
      status: f.status ?? 'active',
      reverseOf: f.reverseOf ?? null,
      parcelOnlyAllowed: f.parcelOnlyAllowed ?? false,
      parcelSeatsTotal: f.parcelSeatsTotal ?? 0,
      parcelSeatsTaken: f.parcelSeatsTaken ?? 0,
      cancelledAt: f.status === 'cancelled' ? new Date() : null,
      ...(f.createdAt ? { createdAt: f.createdAt } : {}),
    })
    .returning({ id: trips.id });
  await db.insert(tripStops).values(f.cityIds.map((cityId, idx) => ({ tripId: row.id, idx, cityId, address: `Остановка ${idx}` })));
  if (f.prices?.length) await db.insert(tripPrices).values(f.prices.map((p) => ({ tripId: row.id, ...p })));
  if (f.extras?.length) await db.insert(tripExtras).values(f.extras.map((e) => ({ tripId: row.id, ...e })));
  return row.id;
}

export interface BookingFixture {
  tripId: string;
  passengerId: string;
  status: BookingStatus;
  fromIdx?: number;
  toIdx: number;
  seats?: number;
  parcelSize?: ParcelSize;
  parcelOnly?: boolean;
  priceTotal?: number;
  extras?: { kind: ExtraKind; price: number }[];
  /** Бронь из заказа пассажира (отклик водителя). */
  orderId?: string;
}

/** Бронь как после своего перехода: обе стороны уже видели текущий статус (событий нет). */
export async function createBooking(f: BookingFixture): Promise<string> {
  const [row] = await db
    .insert(bookings)
    .values({
      tripId: f.tripId,
      passengerId: f.passengerId,
      fromIdx: f.fromIdx ?? 0,
      toIdx: f.toIdx,
      seats: f.seats ?? 1,
      parcelSize: f.parcelSize ?? 'none',
      parcelOnly: f.parcelOnly ?? false,
      priceTotal: f.priceTotal ?? 1000,
      status: f.status,
      passengerSeenStatus: f.status,
      driverSeenStatus: f.status,
      confirmedAt: f.status === 'awaiting_payment' || f.status === 'paid' ? new Date() : null,
      paidAt: f.status === 'paid' ? new Date() : null,
      orderId: f.orderId ?? null,
    })
    .returning({ id: bookings.id });
  if (f.extras?.length) await db.insert(bookingExtras).values(f.extras.map((e) => ({ bookingId: row.id, ...e })));
  return row.id;
}

export interface OrderFixture {
  passengerId: string;
  cityIds: number[];
  departsAt: Date;
  arrivesAt?: Date;
  kind?: TripKind;
  seats?: number;
  parcelSize?: ParcelSize;
  extras?: ServiceKind[];
  status?: OrderStatusStored;
}

/** Заказ пассажира прямой вставкой: точки «Точка N», по умолчанию — поездка на 1 место, открыт. */
export async function createOrder(f: OrderFixture): Promise<{ id: string; number: number }> {
  const [row] = await db
    .insert(orders)
    .values({
      passengerId: f.passengerId,
      kind: f.kind ?? 'ride',
      departsAt: f.departsAt,
      arrivesAt: f.arrivesAt ?? new Date(f.departsAt.getTime() + 2 * 3600_000),
      seats: f.seats ?? (f.kind === 'parcel' ? 0 : 1),
      parcelSize: f.parcelSize ?? 'none',
      status: f.status ?? 'open',
      cancelledAt: f.status === 'cancelled' ? new Date() : null,
    })
    .returning({ id: orders.id, number: orders.number });
  await db.insert(orderStops).values(f.cityIds.map((cityId, idx) => ({ orderId: row.id, idx, cityId, address: `Точка ${idx}` })));
  if (f.extras?.length) await db.insert(orderExtras).values(f.extras.map((kind) => ({ orderId: row.id, kind })));
  return row;
}

export async function addReview(targetId: string, tripId: string, rating: number): Promise<void> {
  const author = await createUser();
  await db.insert(reviews).values({ authorId: author.id, targetId, tripId, rating });
}

export async function addCancellation(userId: string, role: CancellationRole): Promise<void> {
  await db.insert(cancellations).values({ userId, role });
}
