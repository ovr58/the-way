import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/trip_new/steps/route_step.dart';
import 'package:the_way/src/features/trip_new/wizard_controller.dart';

import '../../support/gilroy.dart';
import 'support.dart';

/// фокус и панель подсказок на шаге «Маршрут» — схема как у Яндекс Go / BlaBlaCar.
/// (1) после сохранённого маршрута фокуса нет; (2) курсор в заполненном поле — панели нет; (3) панель — только
/// после правки текста; (4) нажатие вне полей снимает фокус и панель; (5) прокрутка фокус не снимает.
void main() {
  setUpAll(loadGilroy);

  Map<String, Object?> stop(int idx, int cityId, String city, String address) =>
      {'idx': idx, 'cityId': cityId, 'cityName': city, 'address': address, 'shortAddress': address};

  FakeAdapter adapterWithTemplate() => FakeAdapter({
        'GET /geo/suggest': (o) => FakeReply([for (var i = 1; i <= 3; i++) suggestion('Подсказка $i, Ярославль')]),
        'GET /route-templates': (o) => FakeReply([
              {
                'id': 't1',
                'stops': [stop(0, 1, 'Ярославль', 'Победы 1'), stop(1, 3, 'Углич', 'Рынок')],
              },
            ]),
      });

  /// Контроллер с двумя заполненными точками: «Ярославль, Победы 1» и «Углич, Рынок».
  WizardController filled(FakeAdapter adapter) {
    final c = WizardController(repositoryOf(adapter));
    c.setStopFromSuggestion(0, GeoSuggestion.fromJson(suggestion('Ярославль, Победы 1')));
    c.setStopFromSuggestion(1, GeoSuggestion.fromJson(suggestion('Углич, Рынок', place: 'Углич')));
    return c;
  }

  Future<void> open(WidgetTester tester, WizardController c) async {
    tester.view.physicalSize = const Size(375 * 2, 812 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(RouteStep(controller: c)));
    await tester.pumpAndSettle();
  }

  bool anyFocus(WidgetTester tester) =>
      tester.widgetList<TextField>(find.byType(TextField)).any((f) => f.focusNode!.hasFocus);

  Future<void> typeAndWait(WidgetTester tester, Finder field, String text) async {
    await tester.enterText(field, text);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  }

  const pickCity = 'Выбрать город из списка';

  testWidgets('сохранённый маршрут: фокус снят со всех полей, панели нет (п. 1)', (tester) async {
    await open(tester, WizardController(repositoryOf(adapterWithTemplate())));
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    expect(anyFocus(tester), isTrue, reason: 'курсор в пустом поле — исходное состояние');

    await tester.tap(find.text('Ярославль → Углич'));
    await tester.pumpAndSettle();

    expect(tester.widgetList<TextField>(find.byType(TextField)).map((f) => f.controller!.text).take(2),
        ['Ярославль, Победы 1', 'Углич, Рынок']);
    expect(anyFocus(tester), isFalse);
    expect(find.text(pickCity), findsNothing);
    expect(find.text('Далее'), findsOneWidget, reason: 'клавиатура закрыта — «Далее» на месте');
  });

  testWidgets('курсор в заполненном поле — панели нет (п. 2)', (tester) async {
    await open(tester, filled(adapterWithTemplate()));
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    expect(anyFocus(tester), isTrue);
    expect(find.text(pickCity), findsNothing);
  });

  testWidgets('ввод символа — панель с «Выбрать город из списка» (п. 3)', (tester) async {
    await open(tester, filled(adapterWithTemplate()));
    final first = find.byType(TextField).first;
    await tester.tap(first);
    await tester.pumpAndSettle();
    await typeAndWait(tester, first, 'Ярославль, Победы 12');
    expect(find.text(pickCity), findsOneWidget);
    expect(find.text('Подсказка 1, Ярославль'), findsOneWidget);
  });

  testWidgets('нажатие вне полей снимает фокус и панель (п. 4)', (tester) async {
    await open(tester, filled(adapterWithTemplate()));
    final first = find.byType(TextField).first;
    await tester.tap(first);
    await typeAndWait(tester, first, 'Ярос');
    expect(find.text(pickCity), findsOneWidget);

    await tester.tap(find.text('Маршрут'));
    await tester.pumpAndSettle();

    expect(anyFocus(tester), isFalse);
    expect(find.text(pickCity), findsNothing);
  });

  testWidgets('нажатие на подсказку не считается «вне полей»: подсказка выбирается (п. 4, 6)', (tester) async {
    final c = filled(adapterWithTemplate());
    await open(tester, c);
    final first = find.byType(TextField).first;
    await tester.tap(first);
    await typeAndWait(tester, first, 'Ярос');

    await tester.tap(find.text('Подсказка 2, Ярославль'));
    await tester.pumpAndSettle();

    expect(c.stops.first.address, 'Подсказка 2, Ярославль');
    expect(anyFocus(tester), isFalse);
    expect(find.text(pickCity), findsNothing);
  });

  testWidgets('прокрутка пальцем фокус и панель не снимает (п. 5)', (tester) async {
    await open(tester, filled(adapterWithTemplate()));
    final first = find.byType(TextField).first;
    await tester.tap(first);
    await typeAndWait(tester, first, 'Ярос');
    expect(find.text(pickCity), findsOneWidget);

    // Палец ложится вне полей (на заголовок блока) — именно такое касание могло бы снять фокус.
    await tester.drag(find.text('Маршрут'), const Offset(0, -60));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(first).focusNode!.hasFocus, isTrue);
    expect(find.text(pickCity), findsOneWidget);
  });
}
