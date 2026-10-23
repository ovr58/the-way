/// Ключ поиска по названию: строчные буквы, кириллица — латиницей, латинские `j` → `y`,
/// `x` → `ks`. Запрос сводится этим ключом, поэтому «yar» находит «Ярославль», а «gaz» — «ГАЗ».
///
/// Название кодируется ещё двумя вариантами — привычными английскими написаниями ([searchKeys]):
/// «Yekaterinburg», «Nizhny Novgorod», «Habarovsk», «Iaroslavl». Запрос сравнивается с каждым.
///
/// Копия серверного `apps/api/src/common/search-key.ts`; общие случаи —
/// `apps/api/src/common/search-key.cases.json` и `search-key.matches.json` (их читают тесты обеих сторон).
const _latin = {
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e', 'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y',
  'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u', 'ф': 'f',
  'х': 'kh', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'shch', 'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
  'j': 'y', 'x': 'ks',
};

final _cyrillic = RegExp('[а-яё]');
const _vowelOrSign = 'аеёиоуыэюяьъ';

/// Вариант названия: правило переопределяет букву по её соседям, `null` — базовая таблица.
typedef _Rule = String? Function(String ch, String? prev, String? next, String? after);

/// Английское написание: «е» в начале слова и после гласной/ь/ъ — «ye»; окончание «ий/ый» — «y».
String? _english(String ch, String? prev, String? next, String? after) {
  if (ch == 'е' && (prev == null || !_cyrillic.hasMatch(prev) || _vowelOrSign.contains(prev))) return 'ye';
  if ((ch == 'и' || ch == 'ы') && next == 'й' && (after == null || !_cyrillic.hasMatch(after))) return '';
  return null;
}

/// Другие привычные написания: х — «h», щ — «sch», ю — «iu», я — «ia», й — «i».
const _alt = {'х': 'h', 'щ': 'sch', 'ю': 'iu', 'я': 'ia', 'й': 'i'};
String? _alternative(String ch, String? prev, String? next, String? after) => _alt[ch];

String _encode(String text, [_Rule? rule]) {
  final s = text.toLowerCase().split('');
  String? at(int i) => i >= 0 && i < s.length ? s[i] : null;
  return [
    for (var i = 0; i < s.length; i++) rule?.call(s[i], at(i - 1), at(i + 1), at(i + 2)) ?? _latin[s[i]] ?? s[i],
  ].join();
}

String searchKey(String text) => _encode(text);

/// Варианты ключа названия: базовый, английский, другой.
List<String> searchKeys(String name) => {_encode(name), _encode(name, _english), _encode(name, _alternative)}.toList();

/// Какой-нибудь вариант названия содержит запрос; пустой запрос — любое название.
bool matchesSearch(String query, String name) {
  final q = searchKey(query.trim());
  return searchKeys(name).any((k) => k.contains(q));
}

/// Какой-нибудь вариант названия начинается с запроса.
bool startsWithSearch(String query, String name) {
  final q = searchKey(query.trim());
  return searchKeys(name).any((k) => k.startsWith(q));
}

/// [items] в том же порядке, но сначала те, чьё название начинается с запроса.
List<T> prefixFirst<T>(String query, Iterable<T> items, String Function(T item) name) {
  bool starts(T item) => startsWithSearch(query, name(item));
  return [...items.where(starts), ...items.where((i) => !starts(i))];
}
