import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/widgets/info_tile.dart';

import '../support/gilroy.dart';

/// Подпись одной плашки переносится (узкий экран) — соседняя тянется по ней: высоты равны (тема
/// equal-tiles, «Детали поездки созданной водителем - Без пассажиров» – «Редактирование - Нельзя выбрать кол-во мест меньше чем УЖЕ занято» до правки: правая выше левой, левая висит посередине).
void main() {
  setUpAll(loadGilroy);

  testWidgets('плашки в ряду — равной высоты, даже когда подпись переносится', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        // Как на экранах: ряд в столбце прокрутки — высота по содержимому, а не по экрану.
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 240,
              child: InfoTileRow(children: [
                InfoTile(label: 'Дата', value: '15 мая'),
                InfoTile(label: 'Мест для пассажиров', value: '10 из 24'),
              ]),
            ),
          ),
        ),
      ),
    ));
    final left = tester.getRect(find.byType(InfoTile).first);
    final right = tester.getRect(find.byType(InfoTile).last);
    expect(right.height, inInclusiveRange(59, 120), reason: 'подпись правой перенеслась, плашка — по содержимому');
    expect(left.height, right.height);
    expect(left.top, right.top);
  });
}
