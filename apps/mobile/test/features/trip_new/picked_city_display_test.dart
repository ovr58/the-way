import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/l10n/app_localizations.dart';
import 'package:the_way/src/features/trip_new/steps/price_step.dart';
import 'package:the_way/src/features/trip_new/steps/publish_dialog.dart';
import 'package:the_way/src/features/trip_new/steps/route_step.dart';
import 'package:the_way/src/features/trip_new/wizard_controller.dart';

import 'support.dart';

/// точка, заданная текстом + «Выбрать город из списка», в мастере показана как после публикации —
/// «Город, текст»; на сервер уходит прежний адрес (город сервер приписывает сам).
void main() {
  final rostov = City.fromJson(cityJson(7, 'Ростов'));

  WizardController draft() => WizardController(repositoryOf(FakeAdapter({})))
    ..setStopFromCity(0, rostov, 'лесная7')
    ..setStopFromSuggestion(1, GeoSuggestion.fromJson(suggestion('Рынок, Углич', place: 'Углич')));

  group('WizardStop: показ точки из списка городов', () {
    test('«Город, текст»; адрес для сервера — введённая строка', () {
      final s = (draft()).stops[0];
      expect(s.displayAddress, 'Ростов, лесная7');
      expect(s.address, 'лесная7');
      expect(s.toInput().address, 'лесная7');
    });

    test('пустой ввод: адрес — название города, без задвоения', () {
      final c = draft()..setStopFromCity(0, rostov, '  ');
      expect(c.stops[0].displayAddress, 'Ростов');
      expect(c.stops[0].address, 'Ростов');
    });

    test('текст уже начинается с города — город не дописывается второй раз', () {
      final c = draft()..setStopFromCity(0, rostov, 'Ростов, лесная7');
      expect(c.stops[0].displayAddress, 'Ростов, лесная7');
    });

    test('правка текста снимает выбранный город: показ — набранный текст, без приписки', () {
      final c = draft()..setStopText(0, 'Ростов, лесная75');
      expect(c.stops[0].displayAddress, 'Ростов, лесная75');
      expect(c.stops[0].pickedCity, isEmpty);
    });
  });

  testWidgets('поле точки в шаге маршрута: после выбора города — «Ростов, лесная7»; правка не задваивает город',
      (tester) async {
    final adapter = FakeAdapter({
      'GET /geo/suggest': (o) => const FakeReply([]),
      'GET /route-templates': (o) => const FakeReply([]),
      'GET /cities': (o) => FakeReply([cityJson(7, 'Ростов')]),
    });
    final c = WizardController(repositoryOf(adapter));
    await tester.pumpWidget(app(RouteStep(controller: c)));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'лесная7');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выбрать город из списка'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ростов'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, 'Ростов, лесная7');
    expect(c.stops[0].address, 'лесная7', reason: 'на сервер — прежний адрес');
    expect(c.stops[0].cityId, 7);

    await tester.enterText(field, 'Ростов, лесная75');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, 'Ростов, лесная75');
  });

  testWidgets('шаг цен: точка из списка городов показана «Город, текст»', (tester) async {
    tallView(tester);
    await tester.pumpWidget(app(PriceStep(controller: draft())));
    expect(find.text('Ростов, лесная7'), findsWidgets);
    expect(find.text('лесная7'), findsNothing);
  });

  testWidgets('окно публикации: точка из списка городов показана «Город, текст»', (tester) async {
    tallView(tester);
    final c = draft()
      ..date = DateTime(2026, 6, 4)
      ..departTime = const TimeOfDay(hour: 8, minute: 0)
      ..arriveTime = const TimeOfDay(hour: 10, minute: 0)
      ..setPriceFull(1000);
    await tester.pumpWidget(app(Builder(
      builder: (context) => TextButton(
        onPressed: () => showPublishDialog(
          context,
          onConfirm: () async {},
          summary: PublishSummary.fromController(AppLocalizations.of(context), c),
        ),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Ростов, лесная7'), findsOneWidget);
  });
}
