import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/widgets/road_illustration.dart';

/// Иллюстрация дороги из кадров «Детали поездки - Места есть», «Бронирование», «Детали поездки - С пассажирами», «Редактирование - Пассажиры есть» — векторная группа `road` (98 путей).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final source = File('assets/images/road.svg').readAsStringSync();

  test('SVG очищен от обёрток Penpot: свой viewBox от нуля, без clip-path и fill-opacity:none', () {
    expect(source, contains('viewBox="0 0 292.661 169"'));
    expect(source, isNot(contains('clip-path')));
    expect(source, isNot(contains('fill-opacity:none')));
    expect(source, isNot(contains('shape-')));
    expect(RegExp(r'<path\b').allMatches(source).length, 98);
    // Координаты путей — от нуля, не абсолютные координаты холста Penpot (808, 1486).
    expect(source, isNot(contains('1486')));
  });

  test('SVG разбирается загрузчиком flutter_svg', () async {
    final info = await vg.loadPicture(const SvgAssetLoader('assets/images/road.svg'), null);
    expect(info.size.width, closeTo(292.661, 0.01));
    expect(info.size.height, 169);
    info.picture.dispose();
  });

  Widget app(Widget child) => MaterialApp(home: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)));

  testWidgets('размер по умолчанию 293×169 («Детали поездки - Места есть», «Редактирование - Пассажиры есть»), слева, без искажения подписей', (tester) async {
    await tester.pumpWidget(app(const RoadIllustration()));
    expect(tester.getSize(find.descendant(of: find.byType(RoadIllustration), matching: find.byType(SvgPicture))), const Size(293, 169));
    expect(tester.getTopLeft(find.descendant(of: find.byType(RoadIllustration), matching: find.byType(SvgPicture))), Offset.zero);
  });

  testWidgets('размер задаётся кадром: 284×164 («Бронирование»), 293×290 («Детали поездки - С пассажирами»)', (tester) async {
    await tester.pumpWidget(app(const RoadIllustration(width: 284, height: 164)));
    expect(tester.getSize(find.descendant(of: find.byType(RoadIllustration), matching: find.byType(SvgPicture))), const Size(284, 164));
    await tester.pumpWidget(app(const RoadIllustration(height: 290)));
    expect(tester.getSize(find.descendant(of: find.byType(RoadIllustration), matching: find.byType(SvgPicture))), const Size(293, 290));
  });
}
