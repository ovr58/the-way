import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Каждый значок из `assets/icons` обязан разбираться загрузчиком flutter_svg:
/// недопустимое значение в `style` (например `fill-opacity:none`) роняет разбор,
/// и значок на экране не рисуется (пусто вместо стрелки или машины).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final files = Directory('assets/icons')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.svg'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('каталог значков не пуст', () {
    expect(files, isNotEmpty);
  });

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    test('значок $name разбирается', () async {
      final info = await vg.loadPicture(SvgAssetLoader('assets/icons/$name'), null);
      expect(info.size.width, greaterThan(0));
      info.picture.dispose();
    });
  }
}
