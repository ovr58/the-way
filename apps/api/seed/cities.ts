/**
 * Справочник городов из открытого набора hflabs/city: `seed/data/city.csv`, 1117 городов
 * России. `name` — первое непустое из `settlement`, `city`, `area`, `region`; `region` —
 * `region_type` + `region` в виде Mapbox (`mapboxRegion`); координаты — `geo_lat`, `geo_lon`.
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import type { DbExecutor } from '../src/db/client';
import { cities } from '../src/modules/cities/internal/schema';

const CSV_PATH = join(__dirname, 'data', 'city.csv');

/** Разбор CSV по RFC 4180: поля в кавычках с запятыми и удвоенными кавычками внутри. */
export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let quoted = false;
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') {
        field += '"';
        i += 1;
      } else if (ch === '"') {
        quoted = false;
      } else {
        field += ch;
      }
    } else if (ch === '"') {
      quoted = true;
    } else if (ch === ',') {
      row.push(field);
      field = '';
    } else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i += 1;
      row.push(field);
      if (row.some((f) => f !== '')) rows.push(row);
      row = [];
      field = '';
    } else {
      field += ch;
    }
  }
  row.push(field);
  if (row.some((f) => f !== '')) rows.push(row);
  return rows;
}

/** Типы регионов hflabs, чей вид у Mapbox — «<регион> <слово>»: «обл Ярославская» → «Ярославская область». */
const REGION_SUFFIX: Record<string, string> = {
  обл: 'область',
  край: 'край',
  АО: 'автономный округ',
  Аобл: 'автономная область',
  г: '',
};

/**
 * Регионы, которые Mapbox пишет не по правилу суффикса (республики — где «Республика …», где одно
 * имя; регионы с вторым названием). Сверено с Mapbox v6 (`language=ru`) 2026-10-22.
 */
const REGION_MAPBOX: Record<string, string> = {
  'Кемеровская область - Кузбасс': 'Кемеровская область',
  'Ханты-Мансийский Автономный округ - Югра': 'Ханты-Мансийский автономный округ — Югра',
  'Чувашская Республика': 'Чувашия',
  Адыгея: 'Адыгея',
  Алтай: 'Республика Алтай',
  Башкортостан: 'Башкортостан',
  Бурятия: 'Бурятия',
  Дагестан: 'Дагестан',
  Ингушетия: 'Ингушетия',
  'Кабардино-Балкарская': 'Кабардино-Балкария',
  Калмыкия: 'Калмыкия',
  'Карачаево-Черкесская': 'Карачаево-Черкесия',
  Карелия: 'Карелия',
  Коми: 'Республика Коми',
  Крым: 'Автономная Республика Крым',
  'Марий Эл': 'Марий Эл',
  Мордовия: 'Мордовия',
  'Северная Осетия - Алания': 'Северная Осетия — Алания',
  Татарстан: 'Татарстан',
  Тыва: 'Тыва',
  Удмуртская: 'Удмуртия',
  Хакасия: 'Хакасия',
  Чеченская: 'Чечня',
  'Саха /Якутия/': 'Якутия',
};

/**
 * Регион hflabs (`region_type`, `region`) → вид Mapbox: у пункта из подсказки и у города
 * справочника один регион пишется одинаково. Незнакомый регион — ошибка: новый файл набора
 * требует дописать таблицу, а не молча вернуть старый вид.
 */
export function mapboxRegion(type: string, region: string): string {
  const exact = REGION_MAPBOX[region];
  if (exact !== undefined) return exact;
  const suffix = type === 'Респ' ? undefined : REGION_SUFFIX[type];
  if (suffix === undefined) throw new Error(`Регион «${type} ${region}» без вида Mapbox: дописать в seed/cities.ts`);
  return `${region} ${suffix}`.trim();
}

export interface CityRow {
  name: string;
  region: string;
  lat: number;
  lng: number;
}

export function readCityRows(): CityRow[] {
  const [header, ...rows] = parseCsv(readFileSync(CSV_PATH, 'utf8'));
  const col = (name: string): number => {
    const idx = header.indexOf(name);
    if (idx < 0) throw new Error(`В city.csv нет столбца ${name}`);
    return idx;
  };
  const [settlement, city, area, region, regionType, lat, lng] = [
    'settlement',
    'city',
    'area',
    'region',
    'region_type',
    'geo_lat',
    'geo_lon',
  ].map(col);
  return rows.map((r) => ({
    name: [r[settlement], r[city], r[area], r[region]].find((v) => v.trim() !== '')?.trim() ?? '',
    region: mapboxRegion(r[regionType], r[region]),
    lat: Number(r[lat]),
    lng: Number(r[lng]),
  }));
}

/** Заливает все города набора; возвращает число строк. */
export async function seedCities(tx: DbExecutor): Promise<number> {
  const rows = readCityRows();
  const CHUNK = 500;
  for (let i = 0; i < rows.length; i += CHUNK) {
    await tx.insert(cities).values(rows.slice(i, i + CHUNK).map((r) => ({ ...r, source: 'seed' as const })));
  }
  return rows.length;
}
