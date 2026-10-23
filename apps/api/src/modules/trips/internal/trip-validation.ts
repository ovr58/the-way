/**
 * Правила поездки и цены («Правила поездки и цены»): время, авто, места, цены
 * отрезков, услуги и места для посылок. Одна проверка на `POST /trips`, `PATCH /trips/{id}` и
 * `POST /trips/{id}/reverse`: правка и обратная проверяют результат слияния целиком.
 */
import type { Extra, Price, StopInput } from '../../../common/forms';
import type { BookingMode, TripKind, VehicleKind } from '../../../common/enums';
import { inArray } from 'drizzle-orm';
import { AppError } from '../../../common/errors';
import { resolveCityId } from '../../../common/places';
import { checkTimes } from '../../../common/trip-times';
import type { DbExecutor } from '../../../db/client';
import { cities } from '../../cities/internal/schema';
import { findOwnCar, type ResolvedStop } from './trips.repository';

/** Поездка целиком (тело `TripInput` после слияния с текущей). */
export interface TripData {
  kind: TripKind;
  vehicleKind: VehicleKind;
  stops: StopInput[];
  departsAt: Date;
  arrivesAt: Date;
  seatsTotal: number;
  priceFull: number;
  prices: Price[];
  priceBoardingMin: number;
  carId: string;
  extras: Extra[];
  parcelOnlyAllowed: boolean;
  parcelSeatsTotal: number;
  bookingMode: BookingMode;
}

/** Занятые места поездки: правка не опускает общее число ниже них. */
export interface TakenSeats {
  seats: number;
  parcelSeats: number;
}

export const PARCEL_EXTRA_KINDS: readonly string[] = ['parcel_s', 'parcel_m', 'parcel_l'];

/** Места по виду поездки: «ride» — от 1 до мест авто, «parcel» — 0. */
export function checkSeats(kind: TripKind, seatsTotal: number, carSeats: number): void {
  if (kind === 'parcel') {
    if (seatsTotal !== 0) throw new AppError('validation', 'У поездки-посылки мест для пассажиров нет');
  } else if (seatsTotal < 1 || seatsTotal > carSeats) {
    throw new AppError('validation', `Мест для пассажиров — от 1 до ${carSeats}`);
  }
}

/** Верхняя граница любой цены поездки и услуги, ₽. */
export const PRICE_MAX = 100_000;

/** «10 000 ₽» — разряды через пробел, как в приложении. */
function rub(n: number): string {
  return `${String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ' ')} ₽`;
}

/**
 * Цены по участкам: `prices` — ровно участки соседних точек `(k, k+1)`; при двух
 * остановках — пусто. Любая цена — от `priceBoardingMin` до `PRICE_MAX`; весь маршрут — не
 * меньше самого дорогого участка (пассажир всего маршрута едет и через него) и не больше суммы
 * участков. `stopName(k)` — имя точки для текста ошибки.
 */
async function checkPrices(
  data: Pick<TripData, 'stops' | 'prices' | 'priceFull' | 'priceBoardingMin' | 'extras'>,
  stopName: (idx: number) => Promise<string>,
): Promise<void> {
  const { prices, priceFull, priceBoardingMin } = data;
  const last = data.stops.length - 1;
  const all = [priceFull, priceBoardingMin, ...prices.map((p) => p.price), ...data.extras.map((e) => e.price)];
  if (all.some((price) => price > PRICE_MAX)) throw new AppError('validation', `Цена не может быть больше ${rub(PRICE_MAX)}`);

  const legs = new Map<number, number>();
  for (const p of prices) {
    if (p.toIdx !== p.fromIdx + 1 || p.toIdx > last || legs.has(p.fromIdx)) {
      throw new AppError('validation', 'Цены задаются для участков между соседними точками маршрута');
    }
    legs.set(p.fromIdx, p.price);
  }
  if (last > 1 && legs.size !== last) throw new AppError('validation', 'Укажите цену каждого участка маршрута');
  if (last === 1 && legs.size !== 0) throw new AppError('validation', 'У маршрута без остановок цена одна — весь маршрут');

  if (priceFull < priceBoardingMin) {
    throw new AppError('validation', `Весь маршрут не может стоить меньше стоимости посадки (${rub(priceBoardingMin)})`);
  }
  if (legs.size === 0) return;
  let maxFrom = 0;
  let sum = 0;
  for (const [from, price] of legs) {
    if (price < priceBoardingMin) {
      throw new AppError(
        'validation',
        `Участок ${await stopName(from)} → ${await stopName(from + 1)} не может стоить меньше стоимости посадки (${rub(priceBoardingMin)})`,
      );
    }
    if (price > (legs.get(maxFrom) ?? 0)) maxFrom = from;
    sum += price;
  }
  const maxLeg = legs.get(maxFrom) ?? 0;
  if (priceFull < maxLeg) {
    throw new AppError(
      'validation',
      `Весь маршрут не может стоить меньше участка ${await stopName(maxFrom)} → ${await stopName(maxFrom + 1)} (${rub(maxLeg)}): пассажир всего маршрута тоже едет через эту точку`,
    );
  }
  if (priceFull > sum) throw new AppError('validation', `Весь маршрут не может стоить больше суммы участков (${rub(sum)})`);
}

/**
 * Проверяет поездку целиком и превращает точки в `city_id` (в той же транзакции; справочник
 * пополняется подсказками Mapbox). Тип поездки `data.vehicleKind` ставит по авто. Возвращает
 * разрешённые остановки.
 */
export async function validateTrip(
  tx: DbExecutor,
  driverId: string,
  data: TripData,
  taken: TakenSeats = { seats: 0, parcelSeats: 0 },
): Promise<ResolvedStop[]> {
  if (data.stops.length < 2) throw new AppError('validation', 'Остановок — не меньше двух');
  checkTimes(data.departsAt, data.arrivesAt);

  const car = await findOwnCar(tx, driverId, data.carId);
  if (!car || car.status !== 'verified') throw new AppError('car_invalid', 'Автомобиль недоступен');
  // Тип поездки — по самому авто, а не по телу запроса: автобус публикует поездку на автобусе.
  data.vehicleKind = car.kind;
  checkSeats(data.kind, data.seatsTotal, car.seats);
  if (data.seatsTotal < taken.seats) throw new AppError('seats_below_taken', 'Мест меньше, чем занято');

  const kinds = data.extras.map((e) => e.kind);
  if (new Set(kinds).size !== kinds.length) throw new AppError('validation', 'Услуга указана дважды');
  const hasParcel = kinds.some((k) => PARCEL_EXTRA_KINDS.includes(k));
  if (data.kind === 'parcel' && !hasParcel) throw new AppError('validation', 'Выберите размер посылки');
  if (hasParcel ? data.parcelSeatsTotal < 1 : data.parcelSeatsTotal !== 0) {
    throw new AppError('validation', 'Мест для посылок: не меньше 1, если возите посылки, иначе 0');
  }
  if (data.parcelSeatsTotal < taken.parcelSeats) throw new AppError('seats_below_taken', 'Мест для посылок меньше, чем занято');

  const resolved: ResolvedStop[] = [];
  for (const stop of data.stops) {
    resolved.push({
      cityId: await resolveCityId(tx, stop),
      address: stop.address,
      shortAddress: stop.shortAddress ?? null,
      lat: stop.lat ?? null,
      lng: stop.lng ?? null,
    });
  }
  // Имена точек — только для текста ошибки, одним запросом при первой надобности.
  let names: Map<number, string> | undefined;
  await checkPrices(data, async (idx) => {
    names ??= new Map(
      (await tx.select({ id: cities.id, name: cities.name }).from(cities).where(inArray(cities.id, resolved.map((r) => r.cityId)))).map(
        (c) => [c.id, c.name],
      ),
    );
    return names.get(resolved[idx].cityId) ?? `точка ${idx + 1}`;
  });
  return resolved;
}
