import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/trip_new/steps/route_step.dart';
import 'package:the_way/src/features/trip_new/wizard_controller.dart';

import 'support.dart';

WizardController _controller(FakeAdapter adapter) => WizardController(repositoryOf(adapter));

RouteTemplate _template() => RouteTemplate.fromJson({
      'id': 't1',
      'stops': [
        {'idx': 0, 'cityId': 1, 'cityName': 'Ярославль', 'address': 'Победы 1', 'shortAddress': 'Победы 1'},
        {'idx': 1, 'cityId': 2, 'cityName': 'Рыбинск', 'address': '', 'shortAddress': ''},
        {'idx': 2, 'cityId': 3, 'cityName': 'Углич', 'address': 'Рынок', 'shortAddress': 'Рынок'},
      ],
    });

const _uglich = City(id: 7, name: 'Углич', region: 'Ярославская область', lat: 1, lng: 2);

void main() {
  group('WizardController: остановки и шаблон', () {
    test('остановка добавляется перед финишем и удаляется', () {
      final c = _controller(FakeAdapter({}));
      expect(c.stops, hasLength(2));
      c.addStop();
      expect(c.stops, hasLength(3));
      c.removeStop(1);
      expect(c.stops, hasLength(2));
      c.removeStop(0);
      expect(c.stops, hasLength(2), reason: 'старт и финиш не удаляются');
    });

    test('шаблон подставляет остановки и сохраняет город', () {
      final c = _controller(FakeAdapter({}));
      c.applyTemplate(_template());
      expect(c.stops.map((s) => s.cityId), [1, 2, 3]);
      expect(c.stops[1].address, '', reason: 'адрес хранится как пришёл');
      expect(c.stops[1].displayAddress, 'Рыбинск', reason: 'пустой адрес показывается названием города');
      expect(c.routeComplete, isTrue);
    });

    test('правка сохранённой поездки: пустой адрес остановки-города уходит в PATCH пустым', () {
      final c = WizardController.fromTrip(
        repositoryOf(FakeAdapter({})),
        TripDetails.fromJson(tripJson(middleAddress: '')),
      );
      expect(c.stops[1].address, '');
      expect(c.stops[1].displayAddress, 'Рыбинск');
      expect(c.toPatch().stops[1].address, '');
      expect(c.toPatch().stops[0].address, 'Победы 1');
    });

    test('правка поездки: поле точки — «Город, адрес» без задвоения, адрес в PATCH прежний', () {
      final c = WizardController.fromTrip(repositoryOf(FakeAdapter({})), TripDetails.fromJson(tripJson()));
      expect(c.stops[0].displayAddress, 'Ярославль, Победы 1');
      expect(c.toPatch().stops[0].address, 'Победы 1');
      c.setStopFromSuggestion(0, GeoSuggestion.fromJson(suggestion('Ярославль, улица Свободы, 1')));
      expect(c.stops[0].displayAddress, 'Ярославль, улица Свободы, 1');
    });

    test('подсказка → StopInput с place, lat, lng и без cityId', () {
      final c = _controller(FakeAdapter({}));
      c.setStopFromSuggestion(0, GeoSuggestion.fromJson(suggestion('Победы 1, Ярославль')));
      final input = c.stops[0].toInput();
      expect(input.place?.name, 'Ярославль');
      expect(input.place?.region, 'Ярославская область');
      expect(input.lat, 57.62);
      expect(input.lng, 39.89);
      expect(input.cityId, isNull);
      expect(input.address, 'Победы 1, Ярославль');
    });

    test('подсказка → короткий адрес shortLabel уходит в StopInput; ввод текста его снимает (PN-2)', () {
      final c = _controller(FakeAdapter({}));
      c.setStopFromSuggestion(0, GeoSuggestion.fromJson({...suggestion('Россия, Ярославская область, Ярославль, Фрунзенский, 150001, Портовая набережная 10'), 'shortLabel': 'Портовая набережная, 10'}));
      expect(c.stops[0].toInput().shortAddress, 'Портовая набережная, 10');
      expect(c.stops[0].toInput().address, 'Россия, Ярославская область, Ярославль, Фрунзенский, 150001, Портовая набережная 10');
      c.setStopText(0, 'Другой адрес');
      expect(c.stops[0].toInput().shortAddress, isNull);
    });

    test('правка поездки: короткий адрес сохранённой остановки уходит обратно (PN-2)', () {
      const saved = Stop(idx: 0, cityId: 1, cityName: 'Ярославль', address: 'Полный адрес', shortAddress: 'Короткий, 1');
      expect(WizardStop.fromStop(saved).toInput().shortAddress, 'Короткий, 1');
    });

    test('город из списка → cityId без place и без координат, адрес — введённая строка', () {
      final c = _controller(FakeAdapter({}));
      c.setStopFromCity(1, _uglich, 'ул. Ленина');
      final input = c.stops[1].toInput();
      expect(input.cityId, 7);
      expect(input.place, isNull);
      expect(input.lat, isNull);
      expect(input.address, 'ул. Ленина');
    });

    test('точка без place и cityId — маршрут не готов; правка текста снимает выбор', () {
      final c = _controller(FakeAdapter({}));
      c.setStopFromSuggestion(0, GeoSuggestion.fromJson(suggestion('А')));
      c.setStopFromSuggestion(1, GeoSuggestion.fromJson(suggestion('Б')));
      expect(c.routeComplete, isTrue);
      c.setStopText(1, 'Бе');
      expect(c.stops[1].isSet, isFalse);
      expect(c.routeComplete, isFalse);
    });
  });

  group('RouteStep: подсказки и «Далее»', () {
    late FakeAdapter adapter;
    late WizardController c;

    setUp(() {
      adapter = FakeAdapter({
        'GET /geo/suggest': (o) => FakeReply([suggestion('Победы 1, Ярославль')]),
        'GET /route-templates': (o) => const FakeReply([]),
        'GET /cities': (o) => FakeReply([cityJson(7, 'Углич')]),
      });
      c = _controller(adapter);
    });

    testWidgets('запрос подсказок — после паузы 400 мс и от 3 символов', (tester) async {
      await tester.pumpWidget(app(RouteStep(controller: c)));
      await tester.pumpAndSettle();
      final from = find.byType(TextField).first;
      await tester.enterText(from, 'Яр');
      await tester.pump(const Duration(milliseconds: 500));
      expect(adapter.callsTo('GET /geo/suggest'), isEmpty);
      await tester.enterText(from, 'Ярос');
      await tester.pump(const Duration(milliseconds: 300));
      expect(adapter.callsTo('GET /geo/suggest'), isEmpty, reason: 'пауза ещё не прошла');
      await tester.pump(const Duration(milliseconds: 150));
      expect(adapter.callsTo('GET /geo/suggest'), hasLength(1));
      expect(adapter.callsTo('GET /geo/suggest').first.queryParameters['q'], 'Ярос');
    });

    testWidgets('выбор подсказки кладёт place и координаты; под списком — «Выбрать город из списка»',
        (tester) async {
      await tester.pumpWidget(app(RouteStep(controller: c)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Ярос');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('Выбрать город из списка'), findsOneWidget);
      await tester.tap(find.text('Победы 1, Ярославль'));
      await tester.pumpAndSettle();
      expect(c.stops[0].place?.name, 'Ярославль');
      expect(c.stops[0].cityId, isNull);
      expect(c.stops[0].lat, 57.62);
    });

    testWidgets('ошибка подсказок: остаётся один пункт «Выбрать город из списка»; город → cityId',
        (tester) async {
      adapter.routes['GET /geo/suggest'] = (o) => const FakeReply({'code': 'internal', 'message': 'x'}, 500);
      await tester.pumpWidget(app(RouteStep(controller: c)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Угл');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('Выбрать город из списка'), findsOneWidget);
      await tester.tap(find.text('Выбрать город из списка'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Углич'));
      await tester.pumpAndSettle();
      expect(c.stops[0].cityId, 7);
      expect(c.stops[0].place, isNull);
      expect(c.stops[0].address, 'Угл');
    });

    testWidgets('сохранённый маршрут показан списком и подставляется в поля', (tester) async {
      tallView(tester);
      adapter.routes['GET /route-templates'] = (o) => FakeReply([
        {
          'id': 't1',
          'stops': [
            {'idx': 0, 'cityId': 1, 'cityName': 'Ярославль', 'address': 'Победы 1', 'shortAddress': 'Победы 1'},
            {'idx': 1, 'cityId': 3, 'cityName': 'Углич', 'address': 'Рынок', 'shortAddress': 'Рынок'},
          ],
        },
      ]);
      await tester.pumpWidget(app(RouteStep(controller: c)));
      await tester.pumpAndSettle();
      expect(find.text('Мои сохранённые маршруты'), findsOneWidget);
      await tester.tap(find.text('Ярославль → Углич'));
      await tester.pumpAndSettle();
      expect(c.stops.map((s) => s.cityId), [1, 3]);
      expect(tester.widgetList<TextField>(find.byType(TextField)).first.controller!.text, 'Ярославль, Победы 1');
    });

    testWidgets('«Далее» неактивна, пока у точки нет place и cityId', (tester) async {
      c.setStopFromSuggestion(0, GeoSuggestion.fromJson(suggestion('А')));
      c.date = DateTime(2026, 6, 4);
      c.departTime = const TimeOfDay(hour: 8, minute: 0);
      c.arriveTime = const TimeOfDay(hour: 10, minute: 0);
      c.setSeats(3);
      await tester.pumpWidget(app(RouteStep(controller: c)));
      await tester.pumpAndSettle();
      final next = find.widgetWithText(InkWell, 'Далее');
      expect(tester.widget<InkWell>(next).onTap, isNull);
      c.setStopFromCity(1, _uglich, 'ул. Ленина');
      await tester.pumpAndSettle();
      expect(tester.widget<InkWell>(next).onTap, isNotNull);
    });
  });
}
