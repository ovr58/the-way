import { Inject, Injectable } from '@nestjs/common';
import { asc } from 'drizzle-orm';
import { matchesSearch, startsWithSearch } from '../../../common/search-key';
import { DATABASE, type Database } from '../../../db/client';
import { cities } from './schema';
import type { CitiesQuery, City } from './cities.dto';

/**
 * Справочник городов: без `q` — все по имени. С `q` — вхождение по вариантам ключа
 * `searchKeys` (кириллица, латиница, английские написания), сначала названия, начинающиеся с
 * запроса. Справочник — около тысячи строк, поэтому отбор в памяти, а не в SQL.
 */
@Injectable()
export class CitiesService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async list(query: CitiesQuery): Promise<City[]> {
    const columns = { id: cities.id, name: cities.name, region: cities.region, lat: cities.lat, lng: cities.lng };
    const all = await this.db.select(columns).from(cities).orderBy(asc(cities.name), asc(cities.id));
    const q = query.q?.trim() ?? '';
    if (!q) return all;
    const found = all.filter((city) => matchesSearch(q, city.name));
    return [...found.filter((c) => startsWithSearch(q, c.name)), ...found.filter((c) => !startsWithSearch(q, c.name))];
  }
}
