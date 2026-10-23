#!/usr/bin/env node
// Собирает apps/mobile/assets/data/car_catalog.json из открытого набора blanzh/carsBase.
//
//   node tools/data/build-car-catalog.mjs            — скачивает cars.json нужной версии
//   node tools/data/build-car-catalog.mjs cars.json  — берёт локальную копию (офлайн, проверка)
//
// Марки без моделей с year_to >= 2000 отбрасываются; в марке остаются только такие модели, поколение
// из названия («Camry, VII (XV50) Рестайлинг» → «Camry») отрезается, повторы названия сливаются.
// Популярные марки идут первыми, дальше по алфавиту. Источник и условия — assets/data/README.md.
// Сверх набора — маршрутки и автобусы (`EXTRA`): дописываются к марке, марки нет — заводится.
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const COMMIT = '62b0427245dfb944caf03509d84391c5af20b1ae';
const SOURCE = `https://raw.githubusercontent.com/blanzh/carsBase/${COMMIT}/cars.json`;
const OUT = fileURLToPath(new URL('../../apps/mobile/assets/data/car_catalog.json', import.meta.url));
const MIN_YEAR_TO = 2000;

const base = (name) => name.split(',')[0].trim();

/** Маршрутки и автобусы, которых нет в carsBase: марка → модели [название, по-русски]. */
export const EXTRA = [
  { id: 'GAZ', name: 'ГАЗ', cyrillicName: 'ГАЗ', models: [['ГАЗель Next', 'Газель Некст'], ['ГАЗель Business', 'Газель Бизнес'], ['Соболь', 'Соболь']] },
  { id: 'PAZ', name: 'ПАЗ', cyrillicName: 'ПАЗ', models: [['3205', '3205'], ['Vector Next', 'Вектор Некст']] },
  { id: 'FORD', name: 'Ford', cyrillicName: 'Форд', models: [['Transit', 'Транзит']] },
  { id: 'MERCEDES', name: 'Mercedes-Benz', cyrillicName: 'Мерседес-Бенц', models: [['Sprinter', 'Спринтер']] },
  { id: 'PEUGEOT', name: 'Peugeot', cyrillicName: 'Пежо', models: [['Boxer', 'Боксер']] },
  { id: 'FIAT', name: 'Fiat', cyrillicName: 'Фиат', models: [['Ducato', 'Дукато']] },
  { id: 'IVECO', name: 'Iveco', cyrillicName: 'Ивеко', models: [['Daily', 'Дейли']] },
];

/** Дописывает `EXTRA`: модель с тем же названием не повторяется; id модели — `<марка>_<название>`. */
function withExtra(brands) {
  for (const extra of EXTRA) {
    let brand = brands.find((b) => b.id === extra.id);
    if (!brand) {
      brand = { id: extra.id, name: extra.name, cyrillicName: extra.cyrillicName, popular: false, models: [] };
      brands.push(brand);
    }
    for (const [name, cyrillicName] of extra.models) {
      if (!brand.models.some((m) => m.name === name)) brand.models.push({ id: `${extra.id}_${name}`, name, cyrillicName });
    }
  }
  return brands;
}

/** Модели марки без поколений: одна запись на название. */
function modelsOf(brand) {
  const seen = new Map();
  for (const m of brand.models ?? []) {
    if (Number(m.year_to) < MIN_YEAR_TO) continue;
    const name = base(m.name);
    if (!seen.has(name)) seen.set(name, { id: String(m.id), name, cyrillicName: base(m.cyrillic_name || m.name) });
  }
  return [...seen.values()];
}

/** Из набора carsBase — в формат каталога клиента. */
export function buildCatalog(source) {
  const brands = source
    .map((brand) => ({
      id: String(brand.id),
      name: brand.name,
      cyrillicName: brand.cyrillic_name || brand.name,
      popular: Boolean(brand.popular),
      models: modelsOf(brand),
    }))
    .filter((brand) => brand.models.length > 0);
  return withExtra(brands).sort((a, b) => Number(b.popular) - Number(a.popular) || a.name.localeCompare(b.name, 'en'));
}

async function main() {
  const local = process.argv[2];
  let text;
  if (local) {
    text = await readFile(local, 'utf8');
  } else {
    const response = await fetch(SOURCE);
    if (!response.ok) throw new Error(`${SOURCE}: ${response.status}`);
    text = await response.text();
  }
  const catalog = buildCatalog(JSON.parse(text));
  await writeFile(OUT, JSON.stringify(catalog) + '\n');
  console.log(`${OUT}: ${catalog.length} марок`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) await main();
