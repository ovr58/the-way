/** Шаблоны маршрутов пользователя («Новый заказ - Выбор доп услуг»/«Новый заказ - Выбор доп услуг», «Новый заказ - Маршрут сохранен»): список, сохранение, удаление. */
import { and, desc, eq, inArray } from 'drizzle-orm';
import type { Stop, StopInput } from '../../../common/forms';
import { AppError } from '../../../common/errors';
import { resolveCityId } from '../../../common/places';
import type { DbExecutor } from '../../../db/client';
import { cities } from '../../cities/internal/schema';
import { routeTemplates, type RouteTemplateStop } from './schema';
import type { RouteTemplate } from './trips.dto';

async function toTemplates(tx: DbExecutor, rows: (typeof routeTemplates.$inferSelect)[]): Promise<RouteTemplate[]> {
  const cityIds = [...new Set(rows.flatMap((r) => r.stops.map((s) => s.cityId)))];
  const names = cityIds.length
    ? await tx.select({ id: cities.id, name: cities.name }).from(cities).where(inArray(cities.id, cityIds))
    : [];
  const nameById = new Map(names.map((c) => [c.id, c.name]));
  return rows.map((r) => ({
    id: r.id,
    stops: r.stops.map(
      (s, idx): Stop => ({
        idx,
        cityId: s.cityId,
        cityName: nameById.get(s.cityId) ?? '',
        address: s.address,
        shortAddress: s.shortAddress ?? s.address,
        lat: s.lat,
        lng: s.lng,
      }),
    ),
  }));
}

export async function listTemplates(tx: DbExecutor, userId: string): Promise<RouteTemplate[]> {
  const rows = await tx
    .select()
    .from(routeTemplates)
    .where(eq(routeTemplates.userId, userId))
    .orderBy(desc(routeTemplates.createdAt), desc(routeTemplates.id));
  return toTemplates(tx, rows);
}

export async function createTemplate(tx: DbExecutor, userId: string, stops: StopInput[]): Promise<RouteTemplate> {
  if (stops.length < 2) throw new AppError('validation', 'Остановок — не меньше двух');
  const resolved: RouteTemplateStop[] = [];
  for (const stop of stops) {
    resolved.push({
      cityId: await resolveCityId(tx, stop),
      address: stop.address,
      shortAddress: stop.shortAddress ?? null,
      lat: stop.lat ?? null,
      lng: stop.lng ?? null,
    });
  }
  const [row] = await tx.insert(routeTemplates).values({ userId, stops: resolved }).returning();
  return (await toTemplates(tx, [row]))[0];
}

/** Чужой или несуществующий шаблон — `not_found`. */
export async function deleteTemplate(tx: DbExecutor, userId: string, templateId: string): Promise<void> {
  const deleted = await tx
    .delete(routeTemplates)
    .where(and(eq(routeTemplates.id, templateId), eq(routeTemplates.userId, userId)))
    .returning({ id: routeTemplates.id });
  if (deleted.length === 0) throw new AppError('not_found', 'Шаблон не найден');
}
