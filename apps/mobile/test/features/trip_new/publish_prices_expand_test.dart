import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/trip_new/steps/publish_dialog.dart';

import '../../support/expand_checks.dart';
import 'support.dart';

/// в окне «Опубликовать поездку?» «Смотреть стоимость» раскрывается той же анимацией, что остановки.
void main() {
  testWidgets('окно публикации — цены участков выплывают 350 мс, повторное нажатие прячет', (tester) async {
    tallView(tester);
    await tester.pumpWidget(app(Builder(
      builder: (context) => TextButton(
        key: const Key('open'),
        onPressed: () => showPublishDialog(
          context,
          onConfirm: () async {},
          summary: const PublishSummary(
            fromAddress: 'Ярославль, Победы 1',
            toAddress: 'Углич, Рынок',
            extraStops: 1,
            dateTime: '05.06.2026, 7:00',
            priceFull: 1200,
            segments: [('Ярославль, Победы 1 - Рыбинск, Центр', 500), ('Рыбинск, Центр - Углич, Рынок', 700)],
          ),
        ),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    await expectExpandCycle(
      tester,
      chip: const Key('publish_prices_chip'),
      collapse: const Key('publish_prices_collapse'),
      item: find.text('Ярославль, Победы 1 - Рыбинск, Центр'),
    );
  });
}
