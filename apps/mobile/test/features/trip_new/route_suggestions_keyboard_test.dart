import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/trip_new/steps/route_step.dart';
import 'package:the_way/src/features/trip_new/wizard_controller.dart';
import 'package:the_way/src/theme/app_colors.dart';

import '../../support/gilroy.dart';
import 'support.dart';

/// «Новый заказ - Маршрут»: список подсказок адреса не закрывается кнопкой «Далее» над клавиатурой.
void main() {
  setUpAll(loadGilroy);

  const keyboard = 300.0;
  const screen = 812.0;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375 * 2, screen * 2);
    tester.view.devicePixelRatio = 2;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 2);
    addTearDown(tester.view.reset);
    final adapter = FakeAdapter({
      'GET /geo/suggest': (o) => FakeReply([for (var i = 1; i <= 5; i++) suggestion('Подсказка $i, Ярославль')]),
      'GET /route-templates': (o) => const FakeReply([]),
    });
    await tester.pumpWidget(app(RouteStep(controller: WizardController(repositoryOf(adapter)))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Ярос');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  }

  testWidgets('пока поле адреса в фокусе, «Далее» не поднимается над клавиатурой', (tester) async {
    await open(tester);
    expect(find.text('Подсказка 1, Ярославль'), findsOneWidget);
    expect(find.text('Далее'), findsNothing);
  });

  testWidgets('подсказки и «Выбрать город из списка» видны целиком над клавиатурой', (tester) async {
    await open(tester);
    for (final t in ['Подсказка 1, Ярославль', 'Подсказка 5, Ярославль', 'Выбрать город из списка']) {
      final rect = tester.getRect(find.text(t));
      expect(rect.bottom, lessThanOrEqualTo(screen - keyboard), reason: t);
      expect(rect.top, greaterThanOrEqualTo(0), reason: t);
    }
  });

  testWidgets('строка подсказки: адрес, второй строкой серым — область', (tester) async {
    await open(tester);
    final region = find.text('Ярославская область');
    expect(region, findsNWidgets(5));
    expect(tester.widget<Text>(region.first).style?.color, AppColors.textSecondary);
  });

  testWidgets('промежуточная точка подписана «Остановка», а не «Точка посадки»', (tester) async {
    tester.view.physicalSize = const Size(375 * 2, screen * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final adapter = FakeAdapter({'GET /route-templates': (o) => const FakeReply([])});
    await tester.pumpWidget(app(RouteStep(controller: WizardController(repositoryOf(adapter))..addStop())));
    await tester.pumpAndSettle();
    expect(find.text('Остановка'), findsOneWidget);
    expect(find.text('Точка посадки'), findsNothing);
  });

  testWidgets('подсказка-город с областью в названии: второй строки нет — область не дважды', (tester) async {
    tester.view.physicalSize = const Size(375 * 2, screen * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final adapter = FakeAdapter({
      'GET /geo/suggest': (o) => FakeReply([suggestion('Ярославль, Ярославская область'), suggestion('Улица Свободы, 1, Ярославль')]),
      'GET /route-templates': (o) => const FakeReply([]),
    });
    await tester.pumpWidget(app(RouteStep(controller: WizardController(repositoryOf(adapter)))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Ярос');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('Ярославская область'), findsOneWidget, reason: 'только у улицы');
  });

  testWidgets('подсказки с одинаковой подписью склеиваются, первая остаётся', (tester) async {
    tester.view.physicalSize = const Size(375 * 2, screen * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final adapter = FakeAdapter({
      'GET /geo/suggest': (o) => FakeReply([
            suggestion('Ярославль, Лесная улица, 7'),
            suggestion('Ярославль, Лесная улица, 7'),
            suggestion('Ярославль, Лесная улица, 70'),
          ]),
      'GET /route-templates': (o) => const FakeReply([]),
    });
    await tester.pumpWidget(app(RouteStep(controller: WizardController(repositoryOf(adapter)))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Лесная');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('Ярославль, Лесная улица, 7'), findsOneWidget);
    expect(find.text('Ярославль, Лесная улица, 70'), findsOneWidget, reason: 'разные подписи не склеиваются');
  });

  testWidgets('третье поле: подсказки прямо под ним, поле видно над клавиатурой, прокрутка не снимает фокус',
      (tester) async {
    tester.view.physicalSize = const Size(375 * 2, screen * 2);
    tester.view.devicePixelRatio = 2;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 2);
    addTearDown(tester.view.reset);
    final adapter = FakeAdapter({
      'GET /geo/suggest': (o) => FakeReply([for (var i = 1; i <= 5; i++) suggestion('Подсказка $i, Ярославль')]),
      'GET /route-templates': (o) => const FakeReply([]),
    });
    final controller = WizardController(repositoryOf(adapter))..addStop();
    await tester.pumpWidget(app(RouteStep(controller: controller)));
    await tester.pumpAndSettle();
    final third = find.byType(TextField).at(2);
    await tester.tap(third);
    await tester.enterText(third, 'Ярос');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    final field = tester.getRect(third);
    expect(field.top, greaterThanOrEqualTo(0));
    expect(field.bottom, lessThanOrEqualTo(screen - keyboard));
    final first = tester.getRect(find.text('Подсказка 1, Ярославль'));
    expect(first.top, greaterThan(field.bottom));
    expect(first.top - field.bottom, lessThan(40), reason: 'подсказки — сразу под активным полем');

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(third).focusNode!.hasFocus, isTrue);
    expect(find.text('Подсказка 1, Ярославль'), findsOneWidget);
  });

  testWidgets('после выбора подсказки «Далее» возвращается на место', (tester) async {
    await open(tester);
    await tester.tap(find.text('Подсказка 1, Ярославль'));
    await tester.pumpAndSettle();
    expect(find.text('Далее'), findsOneWidget);
  });
}
