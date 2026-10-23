/**
 * Точки маршрута («Правила поездки и цены», строка «Точка»): расстояние по гаверсинусу
 * и превращение точки ввода в `city_id` справочника с его пополнением из подсказок Mapbox.
 */
import { and, eq, sql } from 'drizzle-orm';
import type { DbExecutor } from '../db/client';
import { cities } from '../modules/cities/internal/schema';
import { AppError } from './errors';

const EARTH_RADIUS_KM = 6371;
/** Радиус, в котором подсказка считается тем же населённым пунктом справочника. */
export const SAME_PLACE_KM = 30;

export interface LatLng {
  lat: number;
  lng: number;
}

export function haversineKm(a: LatLng, b: LatLng): number {
  const rad = (deg: number): number => (deg * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.min(1, Math.sqrt(h)));
}

export interface PlaceInput {
  cityId?: number | null;
  place?: { name: string; region: string } | null;
  lat?: number | null;
  lng?: number | null;
}

/**
 * Ровно одно из `cityId` / `place`, иначе `validation`. `cityId` — должен существовать. `place`
 * (требует `lat`, `lng`) — ближайший город с тем же именем без учёта регистра в 30 км (регион не
 * сравнивается: у подсказки без региона на его месте страна); нет — строка с тем же
 * `(name, region)`; нет и её — вставка `source = mapbox` с координатами точки.
 */
export async function resolveCityId(tx: DbExecutor, input: PlaceInput): Promise<number> {
  const hasCity = input.cityId !== undefined && input.cityId !== null;
  const hasPlace = input.place !== undefined && input.place !== null;
  if (hasCity === hasPlace) throw new AppError('validation', 'Точка: ровно одно из cityId или place');

  if (hasCity) {
    const [row] = await tx.select({ id: cities.id }).from(cities).where(eq(cities.id, input.cityId as number));
    if (!row) throw new AppError('validation', 'Город не найден');
    return row.id;
  }

  const place = input.place as { name: string; region: string };
  if (typeof input.lat !== 'number' || typeof input.lng !== 'number') {
    throw new AppError('validation', 'Точка из подсказки требует lat и lng');
  }
  const point = { lat: input.lat, lng: input.lng };

  const sameName = await tx
    .select({ id: cities.id, lat: cities.lat, lng: cities.lng })
    .from(cities)
    .where(sql`lower(${cities.name}) = lower(${place.name})`);
  let nearest: { id: number; km: number } | null = null;
  for (const city of sameName) {
    const km = haversineKm(point, city);
    if (km <= SAME_PLACE_KM && (nearest === null || km < nearest.km)) nearest = { id: city.id, km };
  }
  if (nearest) return nearest.id;

  // Та же пара (name, region) уже есть дальше 30 км — вставка упала бы на unique: берём её.
  await tx
    .insert(cities)
    .values({ name: place.name, region: place.region, lat: point.lat, lng: point.lng, source: 'mapbox' })
    .onConflictDoNothing();
  const [row] = await tx
    .select({ id: cities.id })
    .from(cities)
    .where(and(eq(cities.name, place.name), eq(cities.region, place.region)));
  return row.id;
}
