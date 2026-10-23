import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/search_key.dart';

/// Те же случаи, что у серверного `searchKey`: две копии правила читаются бок о бок.
void main() {
  final cases = jsonDecode(File('../api/src/common/search-key.cases.json').readAsStringSync()) as List<Object?>;

  for (final c in cases) {
    final pair = c! as List<Object?>;
    test('${pair[0]} → ${pair[1]}', () => expect(searchKey(pair[0]! as String), pair[1]));
  }

  final matches = jsonDecode(File('../api/src/common/search-key.matches.json').readAsStringSync()) as List<Object?>;
  for (final m in matches) {
    final pair = m! as List<Object?>;
    test('${pair[0]} находит «${pair[1]}»', () => expect(matchesSearch(pair[0]! as String, pair[1]! as String), isTrue));
  }

  test('startsWithSearch: начало по любому варианту', () {
    expect(startsWithSearch('Yekat', 'Екатеринбург'), isTrue);
    expect(startsWithSearch('slavl', 'Ярославль'), isFalse);
  });

  test('matchesSearch: вхождение по ключу; prefixFirst — сначала начинающиеся с запроса', () {
    expect(matchesSearch('Pereslavl', 'Переславль-Залесский'), isTrue);
    expect(matchesSearch('', 'Москва'), isTrue);
    expect(matchesSearch('qqq', 'Москва'), isFalse);
    expect(prefixFirst('яр', ['Красноярск', 'Ярославль', 'Ярцево'], (s) => s), ['Ярославль', 'Ярцево', 'Красноярск']);
  });
}
