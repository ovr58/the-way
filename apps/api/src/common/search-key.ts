/**
 * Ключ поиска по названию: строчные буквы, кириллица — латиницей (БГН/ГОСТ-подобно), латинские
 * `j` → `y`, `x` → `ks`. Запрос сводится этим ключом, поэтому «yar» находит «Ярославль». Правило
 * посимвольное: дописанная буква запроса не теряет уже найденное.
 *
 * Название кодируется ещё двумя вариантами — привычными английскими написаниями (`searchKeys`):
 * «Yekaterinburg», «Nizhny Novgorod», «Pereslavl-Zalessky», «Habarovsk», «Iaroslavl». Запрос
 * сравнивается с каждым вариантом.
 *
 * Клиентская копия — `apps/mobile/lib/src/app/search_key.dart`; общие случаи —
 * `search-key.cases.json` (ключ) и `search-key.matches.json` (запрос → название), их читают тесты обеих сторон.
 */
const LATIN: Record<string, string> = {
  а: 'a', б: 'b', в: 'v', г: 'g', д: 'd', е: 'e', ё: 'e', ж: 'zh', з: 'z', и: 'i', й: 'y',
  к: 'k', л: 'l', м: 'm', н: 'n', о: 'o', п: 'p', р: 'r', с: 's', т: 't', у: 'u', ф: 'f',
  х: 'kh', ц: 'ts', ч: 'ch', ш: 'sh', щ: 'shch', ъ: '', ы: 'y', ь: '', э: 'e', ю: 'yu', я: 'ya',
  j: 'y', x: 'ks',
};

const CYRILLIC = /[а-яё]/;
const VOWEL_OR_SIGN = 'аеёиоуыэюяьъ';

/** Вариант названия: [rule] переопределяет букву по её соседям, иначе — базовая таблица. */
type Rule = (ch: string, prev: string | undefined, next: string | undefined, after: string | undefined) => string | undefined;

/** Английское написание: «е» в начале слова и после гласной/ь/ъ — «ye»; окончание «ий/ый» — «y». */
const english: Rule = (ch, prev, next, after) => {
  if (ch === 'е' && (!prev || !CYRILLIC.test(prev) || VOWEL_OR_SIGN.includes(prev))) return 'ye';
  if ((ch === 'и' || ch === 'ы') && next === 'й' && (!after || !CYRILLIC.test(after))) return '';
  return undefined;
};

/** Другие привычные написания: х — «h», щ — «sch», ю — «iu», я — «ia», й — «i». */
const ALT: Record<string, string> = { х: 'h', щ: 'sch', ю: 'iu', я: 'ia', й: 'i' };
const alternative: Rule = (ch) => ALT[ch];

function encode(text: string, rule?: Rule): string {
  const s = Array.from(text.toLowerCase());
  return s.map((ch, i) => rule?.(ch, s[i - 1], s[i + 1], s[i + 2]) ?? LATIN[ch] ?? ch).join('');
}

export function searchKey(text: string): string {
  return encode(text);
}

/** Варианты ключа названия: базовый, английский, другой. */
export function searchKeys(name: string): string[] {
  return [...new Set([encode(name), encode(name, english), encode(name, alternative)])];
}

/** Какой-нибудь вариант названия содержит запрос; пустой запрос — любое название. */
export function matchesSearch(query: string, name: string): boolean {
  const q = searchKey(query.trim());
  return searchKeys(name).some((k) => k.includes(q));
}

/** Какой-нибудь вариант названия начинается с запроса. */
export function startsWithSearch(query: string, name: string): boolean {
  const q = searchKey(query.trim());
  return searchKeys(name).some((k) => k.startsWith(q));
}
