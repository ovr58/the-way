import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Значок перекрашивается в коде ([AppIcon] — `BlendMode.srcIn`): цвет берёт альфу из самого SVG.
/// Запечённая при выгрузке прозрачность 50 % (`fill-opacity:0.5`) делает значок бледнее кадра —
/// «−» серым рядом с чёрным «+» («Редактирование - Изменение кол-ва мест»), звезду бледно-жёлтой вместо #dbb109 («Профиль - Профиль пассажира», «Профиль - Профиль пассажира до оплаты»).
/// Прозрачность значка задаёт цвет в коде (`text.secondary`), а не файл. `fill-opacity:0` —
/// прозрачная подложка кадра значка, её не трогаем.
void main() {
  final files = Directory('assets/icons')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.svg'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    test('в значке $name нет запечённой частичной прозрачности', () {
      final partial = RegExp(r'(fill|stroke)-opacity:\s*0?\.\d+|opacity="0?\.\d+"')
          .allMatches(file.readAsStringSync())
          .map((m) => m.group(0))
          .toList();
      expect(partial, isEmpty);
    });
  }
}
