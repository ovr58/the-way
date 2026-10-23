/**
 * `npm run db:seed` — синтетические данные стенда (NFR-05). Seed идёт тем же путём, что
 * приложение (кадр «Базовые экраны - Поездки есть»; `seed/services.ts`): вход по коду, профиль, фото, авто,
 * публикация поездок, брони и их переходы, шаблон маршрута — методы сервисов с проверками тел
 * контроллеров. Мимо сервисов — только то, для чего у приложения пути нет: очистка таблиц и
 * каталога файлов, справочник городов, сдвиг истории в прошлое и отзывы (`history.ts`),
 * жалоба (подачи жалобы в приложении нет).
 *
 * Состав: города; водители `+79000000001…03` с авто и фото (у `…01` — 2 авто, поездок нет — их
 * публикует I.2); водители автобусов `+79000000004` (Газель Next на 24 места) и `+79000000005`
 * (ПАЗ Vector Next на 30 мест), их поездки — в `demo.ts`; водители легковых своих линий
 * `+79000000006…08` (Игорь, Елена, Роман: у каждого свой город, маршрут и время «туда», Toyota Camry, Volkswagen
 * Polo, Skoda Rapid, фото Commons), их поездки — в `demo.ts`, завершённые с отзывами — `history.ts`; у каждого авто — образец СТС; пассажиры `+79000000011` (для живого прогона, броней нет), `+79000000012` (брони во
 * всех статусах и одна отмена) и авторы отзывов `…13…18`; завершённые поездки `…02` и `…03` с
 * отзывами; одна жалоба на `…02` от пассажира её завершённой поездки; демо-поездки `demo.ts`;
 * шаблон маршрута `…01`.
 */
import { and, eq, lt, sql } from 'drizzle-orm';
import { type DbExecutor, createDatabase, createPool, runMigrations } from '../src/db/client';
import { AUTH_CODE } from '../src/modules/auth/internal/phone';
import { VerifyBody } from '../src/modules/auth/internal/auth.dto';
import { BookingInput } from '../src/modules/bookings/internal/bookings.dto';
import { bookings } from '../src/modules/bookings/internal/schema';
import { CarDocumentInput, CarInput } from '../src/modules/cars/internal/cars.dto';
import { complaints } from '../src/modules/reviews/internal/schema';
import { trips } from '../src/modules/trips/internal/schema';
import { RouteTemplateInput } from '../src/modules/trips/internal/trips.dto';
import { PatchMeBody } from '../src/modules/users/internal/users.dto';
import { seedCities } from './cities';
import { addDays, appTz, dateInTz, inSeedContext, routeCityIds, seedDemo, type DemoDay, type DemoDriver } from './demo';
import { HISTORY_PASSENGERS, seedHistory } from './history';
import { AVATARS, CAR_PHOTOS, CAR_STS, clearFilesDir, uploadMedia } from './media';
import { body, services, type Services } from './services';

const TABLES = [
  'booking_extras',
  'bookings',
  'order_extras',
  'order_stops',
  'orders',
  'cancellations',
  'blocks',
  'reviews',
  'complaints',
  'route_templates',
  'trip_extras',
  'trip_prices',
  'trip_stops',
  'trips',
  'admin_checks',
  'car_documents',
  'cars',
  'sessions',
  'users',
  'files',
  'cities',
];

/** Водители легковых своих линий: телефон — как в `CAR_LINES`, город жительства — начало маршрута, авто из каталога. */
const LINE_DRIVERS = [
  { phone: '+79000000006', name: 'Игорь', home: 'Рыбинск', brand: 'Toyota', model: 'Camry', plate: 'С999СС76' },
  { phone: '+79000000007', name: 'Елена', home: 'Ростов', brand: 'Volkswagen', model: 'Polo', plate: 'Н888НН76' },
  { phone: '+79000000008', name: 'Роман', home: 'Углич', brand: 'Skoda', model: 'Rapid', plate: 'Т666ТТ76' },
] as const;

/** Вход по телефону и коду, затем профиль (`PATCH /me`): имя, город, режим, аватар. */
async function signUp(s: Services, phone: string, name: string, mode: 'passenger' | 'driver', cityId: number): Promise<string> {
  const { me } = await s.auth.verify(await body(VerifyBody, { phone, code: AUTH_CODE }));
  const avatar = AVATARS[phone];
  const photoFileId = avatar ? await uploadMedia(s.files, me.id, avatar) : null;
  await s.users.patchMe(me.id, await body(PatchMeBody, { name, cityId, mode, photoFileId }));
  return me.id;
}

/** Авто водителя с фото и СТС (`POST /files`, `POST /cars`, `POST /cars/{id}/documents`); по умолчанию легковое на 4 места. */
async function addCar(
  s: Services,
  ownerId: string,
  brand: string,
  model: string,
  plate: string,
  { kind, seats }: { kind: 'car' | 'bus'; seats: number } = { kind: 'car', seats: 4 },
): Promise<string> {
  const photoFileId = await uploadMedia(s.files, ownerId, CAR_PHOTOS[plate]);
  const car = await s.cars.create(ownerId, await body(CarInput, { brand, model, kind, seats, plate, photoFileId }));
  const stsFileId = await uploadMedia(s.files, ownerId, CAR_STS[plate]);
  await s.cars.addDocument(ownerId, car.id, await body(CarDocumentInput, { kind: 'sts', fileId: stsFileId }));
  return car.id;
}

/** Бронь пассажира тем же путём, что «Бронирование»: тело брони — как у клиента. */
async function book(s: Services, passengerId: string, tripId: string, input: object): Promise<string> {
  const booking = await s.bookings.create(passengerId, tripId, await body(BookingInput, input));
  return booking.id;
}

/** Набор дня с поездками обоих демо-водителей. */
function isFullDay(d: DemoDay | undefined): d is Required<DemoDay> {
  return !!d && !!d.forward02 && !!d.forward03 && !!d.reverse02 && !!d.reverse03;
}

/**
 * Брони `…12` — по одной в каждом статусе и одна отмена. Регистрация в паре дублей открыта на
 * «туда» `…03` (его рейтинг выше), «туда» `…02` забронировать нельзя — стандартные брони идут на
 * обратную `…02` (дублей у неё нет).
 */
async function seedPassengerBookings(
  s: Services,
  passengerId: string,
  drivers: { d02: string },
  tomorrow: Required<DemoDay>,
  dayAfter: Required<DemoDay>,
): Promise<void> {
  // paid — быстрая бронь с посылкой S: создаётся в awaiting_payment и тем же нажатием оплачивается.
  const paid = await book(s, passengerId, tomorrow.forward03, {
    fromIdx: 0,
    toIdx: 1,
    seats: 1,
    parcelSize: 'S',
    parcelOnly: false,
    parcelComment: 'Коробка с документами',
    extras: [],
  });
  await s.bookings.pay(passengerId, paid);
  // awaiting_payment — быстрая бронь, оплата не нажата.
  await book(s, passengerId, dayAfter.forward03, { fromIdx: 0, toIdx: 1, seats: 1, parcelSize: 'none', parcelOnly: false, extras: ['pets'] });
  // requested — заявка ждёт водителя.
  await book(s, passengerId, tomorrow.reverse02, {
    fromIdx: 0,
    toIdx: tomorrow.reverse02Last,
    seats: 2,
    parcelSize: 'none',
    parcelOnly: false,
    extras: ['child_seat'],
  });
  // rejected — водитель отклонил заявку.
  const rejected = await book(s, passengerId, dayAfter.reverse02, {
    fromIdx: 0,
    toIdx: dayAfter.reverse02Last,
    seats: 1,
    parcelSize: 'none',
    parcelOnly: false,
    extras: [],
  });
  await s.bookings.reject(drivers.d02, rejected);
  // cancelled — водитель принял заявку, пассажир отказался — отмена в счёте 2/30.
  const cancelled = await book(s, passengerId, dayAfter.reverse02, {
    fromIdx: 1,
    toIdx: dayAfter.reverse02Last,
    seats: 1,
    parcelSize: 'none',
    parcelOnly: false,
    extras: [],
  });
  await s.bookings.confirm(drivers.d02, cancelled);
  await s.bookings.cancel(passengerId, cancelled);
}

/** Отзыв оставлен через 3 ч после прибытия (`history.ts`), жалоба — через 4 ч. */
const COMPLAINT_AFTER_MS = 4 * 3600_000;

/**
 * Жалоба пассажира на водителя его завершённой поездки — прямой записью: подачи жалобы в
 * приложении нет, «Жалобы» водителя показывают полученные.
 */
async function seedComplaint(tx: DbExecutor, authorId: string, targetId: string): Promise<void> {
  const rides = await tx
    .select({ tripId: trips.id, arrivesAt: trips.arrivesAt })
    .from(bookings)
    .innerJoin(trips, eq(trips.id, bookings.tripId))
    .where(and(eq(bookings.passengerId, authorId), eq(trips.driverId, targetId), lt(trips.departsAt, sql`now()`)));
  if (rides.length !== 1) throw new Error(`Жалоба: ждали одну завершённую поездку пассажира с водителем, найдено ${rides.length}`);
  const [ride] = rides;
  await tx.insert(complaints).values({
    authorId,
    targetId,
    tripId: ride.tripId,
    reason: 'Опоздала к месту посадки на 20 минут',
    status: 'open',
    createdAt: new Date(ride.arrivesAt.getTime() + COMPLAINT_AFTER_MS),
  });
}

export async function seed(db: DbExecutor): Promise<void> {
  await db.transaction(async (tx) => {
    await tx.execute(sql.raw(`truncate table ${TABLES.join(', ')} restart identity cascade`));
    await clearFilesDir();
    const cityCount = await seedCities(tx);
    const ids = await routeCityIds(tx);
    const yar = ids.get('Ярославль') as number;
    const s = services(tx);

    const driver1 = await signUp(s, '+79000000001', 'Алексей', 'driver', yar);
    const driver2 = await signUp(s, '+79000000002', 'Мария', 'driver', yar);
    const driver3 = await signUp(s, '+79000000003', 'Дмитрий', 'driver', yar);
    const busDriver = await signUp(s, '+79000000004', 'Сергей', 'driver', yar);
    const busDriver05 = await signUp(s, '+79000000005', 'Николай', 'driver', yar);
    const lineIds = new Map<string, string>();
    for (const d of LINE_DRIVERS) lineIds.set(d.phone, await signUp(s, d.phone, d.name, 'driver', ids.get(d.home) as number));
    await signUp(s, '+79000000011', 'Иван', 'passenger', yar);
    const passenger12 = await signUp(s, '+79000000012', 'Ольга', 'passenger', yar);
    const passengerIds = new Map<string, string>();
    for (const [phone, name] of HISTORY_PASSENGERS) passengerIds.set(phone, await signUp(s, phone, name, 'passenger', yar));

    await addCar(s, driver1, 'Lada', 'Vesta', 'А111АА76');
    await addCar(s, driver1, 'Hyundai', 'Solaris', 'В222ВВ76');
    const car2 = await addCar(s, driver2, 'Kia', 'Rio', 'Е333ЕЕ76');
    const car3 = await addCar(s, driver3, 'Skoda', 'Octavia', 'К444КК76');
    await addCar(s, busDriver, 'ГАЗ', 'Газель Next', 'М555ММ76', { kind: 'bus', seats: 24 });
    await addCar(s, busDriver05, 'ПАЗ', 'Vector Next', 'Р777РР76', { kind: 'bus', seats: 30 });

    const lineCars = new Map<string, DemoDriver>();
    for (const d of LINE_DRIVERS) {
      const id = lineIds.get(d.phone) as string;
      lineCars.set(d.phone, { id, carId: await addCar(s, id, d.brand, d.model, d.plate) });
    }

    const history = await seedHistory(
      tx,
      s,
      { '02': { id: driver2, carId: car2 }, '03': { id: driver3, carId: car3 } },
      lineCars,
      passengerIds,
      ids,
    );
    await seedComplaint(tx, passengerIds.get('+79000000018') as string, driver2);

    const { created } = await seedDemo(tx);
    const today = process.env.DEMO_TODAY ?? dateInTz(new Date(), appTz());
    const tomorrow = created.find((d) => d.date === addDays(today, 1));
    const dayAfter = created.find((d) => d.date === addDays(today, 2));
    // Свежая база: недельный лимит на завтра и послезавтра не выбран — наборы полные.
    if (!isFullDay(tomorrow) || !isFullDay(dayAfter)) throw new Error('Нет полных демо-наборов на завтра и послезавтра');
    await seedPassengerBookings(s, passenger12, { d02: driver2 }, tomorrow, dayAfter);

    // Seed — обе стороны просмотрели (план, «События»): иначе при первом входе — окна о старых бронях.
    const seen = await tx
      .select({ id: bookings.id, passengerId: bookings.passengerId, driverId: trips.driverId })
      .from(bookings)
      .innerJoin(trips, eq(trips.id, bookings.tripId));
    for (const b of seen) {
      await s.bookings.markSeen(b.passengerId, b.id);
      await s.bookings.markSeen(b.driverId, b.id);
    }

    await s.trips.createTemplate(
      driver1,
      await body(RouteTemplateInput, {
        stops: [
          { cityId: yar, address: 'Московский проспект, 80А' },
          { cityId: ids.get('Ростов'), address: 'улица Ленинская, 32' },
        ],
      }),
    );

    const tripCount = await tx.$count(trips);
    const bookingCount = await tx.$count(bookings);
    process.stdout.write(
      `Seed: городов ${cityCount}, поездок ${tripCount} (завершённых ${history.trips}), броней ${bookingCount}, отзывов ${history.reviews}.\n`,
    );
  });
}

async function main(): Promise<void> {
  const pool = createPool();
  try {
    const db = createDatabase(pool);
    await runMigrations(db);
    await inSeedContext(() => seed(db));
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
