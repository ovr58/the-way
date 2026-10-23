import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/trip_new/edit_trip_screen.dart';
import 'package:the_way/src/widgets/app_button.dart';

import 'support.dart';

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<InkWell>(find.widgetWithText(InkWell, label)).onTap != null;

Finder _price(String key) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));

/// Заменяет остановку [index] подсказкой «Площадь 1, Мышкин».
Future<void> _replaceStop(WidgetTester tester, int index) async {
  await tester.enterText(find.byType(TextField).at(index), 'Мышк');
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Площадь 1, Мышкин'));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) => tester.widget<TextField>(_price(key)).controller!.text;

void main() {
  group('EditTripScreen («Редактирование - Изменений нет», «Редактирование - Изменения есть», «Редактирование - Изменений нет», «Редактирование - Изменения есть»)', () {
    late FakeAdapter adapter;

    setUp(() {
      adapter = FakeAdapter({
        'GET /trips/trip1': (o) => FakeReply(tripJson()),
        'PATCH /trips/trip1': (o) => FakeReply(tripJson(seatsTotal: 4)),
        'GET /geo/suggest': (o) => FakeReply([suggestion('Площадь 1, Мышкин', place: 'Мышкин')]),
      });
    });

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(app(EditTripScreen(tripId: 'trip1', repository: repositoryOf(adapter))));
      await tester.pumpAndSettle();
    }

    testWidgets('без изменений «Сохранить» неактивна («Редактирование - Изменений нет»); «Далее» и шага нет', (tester) async {
      tallView(tester);
      await open(tester);
      expect(find.text('Изменение заказа'), findsOneWidget);
      expect(find.text('Ярославль, Победы 1'), findsOneWidget);
      expect(find.text('Далее'), findsNothing);
      expect(find.textContaining('Шаг'), findsNothing);
      expect(find.text('Изменить стоимость'), findsOneWidget);
      expect(_enabled(tester, 'Сохранить'), isFalse);
      // «Редактирование - Изменений нет», «Редактирование - Изменения есть»: «Изменить стоимость» и «Сохранить» — пара в один ряд внизу, как в кадре.
      final change = tester.getRect(find.widgetWithText(AppButton, 'Изменить стоимость'));
      final save = tester.getRect(find.widgetWithText(AppButton, 'Сохранить'));
      expect(change.top, save.top);
      expect(change.right, lessThan(save.left));
      expect(change.width, save.width);
    });

    testWidgets('изменили места → «Сохранить» → PATCH → driver_trips/details и снэкбар', (tester) async {
      tallView(tester);
      await open(tester);
      // «+» у мест — последняя кнопка в строке «Количество мест:».
      final row = find.ancestor(of: find.text('Количество мест:'), matching: find.byType(Row)).first;
      await tester.tap(find.descendant(of: row, matching: find.byType(InkWell)).last);
      await tester.pump();
      expect(_enabled(tester, 'Сохранить'), isTrue);
      await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
      await tester.pumpAndSettle();
      final body = adapter.callsTo('PATCH /trips/trip1').single.data as Map<String, dynamic>;
      expect(body['seatsTotal'], 4);
      expect(body['priceFull'], 1200);
      expect(adapter.callsTo('GET /trips/trip1'), hasLength(1));
      expect(find.text('route:driver_trips/details'), findsOneWidget);
      expect(find.text('Изменения сохранены'), findsOneWidget);
    });

    testWidgets('«Изменить стоимость» → экран цен в режиме правки → «Сохранить» → PATCH с новой ценой',
        (tester) async {
      tallView(tester);
      await open(tester);
      await tester.tap(find.text('Изменить стоимость'));
      await tester.pumpAndSettle();
      expect(find.text('Изменение стоимости'), findsOneWidget);
      await tester.enterText(_price('price-full'), '1100');
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('Изменение заказа'), findsOneWidget);
      expect(adapter.callsTo('PATCH /trips/trip1'), isEmpty, reason: 'поездку сохраняет экран правки');
      expect(_enabled(tester, 'Сохранить'), isTrue);
      await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
      await tester.pumpAndSettle();
      final body = adapter.callsTo('PATCH /trips/trip1').single.data as Map<String, dynamic>;
      expect(body['priceFull'], 1100);
    });

    testWidgets('изменились остановки → «Сохранить» сначала ведёт на экран цен, потом один PATCH со stops и prices',
        (tester) async {
      tallView(tester);
      await open(tester);
      final last = find.byType(TextField).at(2);
      await tester.enterText(last, 'Мышк');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Площадь 1, Мышкин'));
      await tester.pumpAndSettle();
      expect(_enabled(tester, 'Сохранить'), isTrue);
      await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
      await tester.pumpAndSettle();
      expect(adapter.callsTo('PATCH /trips/trip1'), isEmpty);
      expect(find.text('Изменение стоимости'), findsOneWidget);
      await tester.enterText(_price('price-0-1'), '600');
      await tester.enterText(_price('price-1-2'), '800');
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
      await tester.pumpAndSettle();
      final body = adapter.callsTo('PATCH /trips/trip1').single.data as Map<String, dynamic>;
      final stops = body['stops'] as List;
      expect(stops, hasLength(3));
      expect((stops.last as dynamic).place.name, 'Мышкин');
      final prices = (body['prices'] as List).map((p) => (p as dynamic).price).toList();
      expect(prices, [600, 800]);
    });

    testWidgets('замена остановки без смены их числа сбрасывает цены пар', (tester) async {
      tallView(tester);
      await open(tester);
      await _replaceStop(tester, 1);
      await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('Изменение стоимости'), findsOneWidget);
      expect(_text(tester, 'price-0-1'), isEmpty, reason: 'старая цена не переходит к новой паре');
      expect(_text(tester, 'price-1-2'), isEmpty);
      expect(_enabled(tester, 'Сохранить'), isFalse);
      expect(adapter.callsTo('PATCH /trips/trip1'), isEmpty);
    });

    testWidgets('«назад» с экрана цен возвращает исходные цены, «Сохранить» остаётся активной', (tester) async {
      tallView(tester);
      await open(tester);
      await _replaceStop(tester, 2);
      await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('Изменение стоимости'), findsOneWidget);
      await tester.tap(find.byType(AppIconButton));
      await tester.pumpAndSettle();
      expect(find.text('Изменение заказа'), findsOneWidget);
      expect(adapter.callsTo('PATCH /trips/trip1'), isEmpty);
      expect(_enabled(tester, 'Сохранить'), isTrue);
      await tester.tap(find.text('Изменить стоимость'));
      await tester.pumpAndSettle();
      expect(_text(tester, 'price-0-1'), '500');
      expect(_text(tester, 'price-1-2'), '700');
    });

    testWidgets('правка без смены маршрута шлёт адрес остановки-города как пришёл (пустой — пустой)',
        (tester) async {
      tallView(tester);
      adapter.routes['GET /trips/trip1'] = (o) => FakeReply(tripJson(middleAddress: ''));
      await open(tester);
      final row = find.ancestor(of: find.text('Количество мест:'), matching: find.byType(Row)).first;
      await tester.tap(find.descendant(of: row, matching: find.byType(InkWell)).last);
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
      await tester.pumpAndSettle();
      final body = adapter.callsTo('PATCH /trips/trip1').single.data as Map<String, dynamic>;
      final stops = body['stops'] as List;
      expect((stops[1] as dynamic).address, '');
      expect((stops[0] as dynamic).address, 'Победы 1');
    });

    testWidgets(
        'цены подтверждены для текущего маршрута («Изменить стоимость») → «Сохранить» сразу шлёт PATCH, экран цен не открывается',
        (tester) async {
      tallView(tester);
      await open(tester);
      await _replaceStop(tester, 2);
      await tester.tap(find.text('Изменить стоимость'));
      await tester.pumpAndSettle();
      await tester.enterText(_price('price-0-1'), '600');
      await tester.enterText(_price('price-1-2'), '800');
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('Изменение заказа'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
      await tester.pumpAndSettle();
      final body = adapter.callsTo('PATCH /trips/trip1').single.data as Map<String, dynamic>;
      final prices = (body['prices'] as List).map((p) => (p as dynamic).price).toList();
      expect(prices, [600, 800]);
      expect(find.text('Изменение стоимости'), findsNothing);
      expect(find.text('route:driver_trips/details'), findsOneWidget);
    });

    testWidgets('edit_locked → снэкбар, остаёмся на экране', (tester) async {
      tallView(tester);
      adapter.routes['PATCH /trips/trip1'] = (o) => const FakeReply({'code': 'edit_locked', 'message': 'x'}, 409);
      await open(tester);
      await tester.tap(find.text('Изменить стоимость'));
      await tester.pumpAndSettle();
      await tester.enterText(_price('price-full'), '1100');
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('Редактирование недоступно: к поездке уже присоединился пассажир'), findsOneWidget);
      expect(find.text('Изменение заказа'), findsOneWidget);
    });
  });
}
