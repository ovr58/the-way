import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/city/city_screen.dart';
import 'package:the_way/src/features/city/data/city_repository.dart';

import '../auth/fake_api.dart';

Map<String, Object?> _city(int id, String name) => {'id': id, 'name': name, 'region': 'Регион', 'lat': 55.7, 'lng': 37.6};

FakeAdapter _adapter() => FakeAdapter({
      'GET /cities': (_) => FakeReply(200, [_city(1, 'Москва'), _city(2, 'Абакан'), _city(3, 'Архангельск')]),
    });

void main() {
  setUpAll(loadGilroy);

  testWidgets('список по буквам, поиск сужает, выбор города → «Далее» → auth', (tester) async {
    usePhone(tester);
    final session = fakeSession(_adapter());
    await tester.pumpWidget(fakeApp(session, const CityScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Выберите ваш город'), findsOneWidget);
    expect(find.text('А'), findsOneWidget);
    expect(find.text('М'), findsOneWidget);
    expect(find.byKey(const ValueKey('city_2')), findsOneWidget);
    expect(find.text('Далее'), findsNothing);
    expect(find.text('Моего города нет в списке'), findsNothing);

    await tester.enterText(find.byType(TextField), 'мос');
    await tester.pump();
    expect(find.byKey(const ValueKey('city_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('city_2')), findsNothing);
    expect(find.text('Моего города нет в списке'), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);
    expect(find.text('Далее'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('city_1')));
    await tester.pump();
    expect(find.text('Далее'), findsOneWidget);
    expect(find.text('Моего города нет в списке'), findsNothing);
    expect(session.pendingCityId, isNull);

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(session.pendingCityId, 1);
    expect(find.text('route:auth'), findsOneWidget);
  });

  testWidgets('латиница находит: «yar» → Ярославль раньше Красноярска; пусто — «Ничего не найдено»', (tester) async {
    usePhone(tester);
    final adapter = FakeAdapter({
      'GET /cities': (_) => FakeReply(200, [_city(1, 'Красноярск'), _city(2, 'Москва'), _city(3, 'Ярославль')]),
    });
    await tester.pumpWidget(fakeApp(fakeSession(adapter), const CityScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'yar');
    await tester.pump();
    expect(find.byKey(const ValueKey('city_2')), findsNothing);
    final yar = tester.getTopLeft(find.byKey(const ValueKey('city_3'))).dy;
    final kras = tester.getTopLeft(find.byKey(const ValueKey('city_1'))).dy;
    expect(yar, lessThan(kras));
    expect(find.text('Ничего не найдено'), findsNothing);

    await tester.enterText(find.byType(TextField), 'qqqzzz');
    await tester.pump();
    expect(find.text('Ничего не найдено'), findsOneWidget);
  });

  testWidgets('промежутки подсказка—поиск—список — 24, как в «Выбор города»', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(fakeApp(fakeSession(_adapter()), const CityScreen()));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is SizedBox && w.height == 24 && w.width == null && w.child == null), findsNWidgets(2));
  });

  testWidgets('правка текста после выбора снимает выбор; «Моего города нет в списке» → stub', (tester) async {
    usePhone(tester);
    final session = fakeSession(_adapter());
    await tester.pumpWidget(fakeApp(session, const CityScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Москва');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('city_1')));
    await tester.pump();
    expect(find.text('Далее'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Москв');
    await tester.pump();
    expect(find.text('Далее'), findsNothing);

    await tester.tap(find.text('Моего города нет в списке'));
    await tester.pumpAndSettle();
    expect(find.text('route:stub'), findsOneWidget);
    expect(session.pendingCityId, isNull);
  });

  testWidgets('ошибка загрузки: «Обновить» повторяет запрос', (tester) async {
    usePhone(tester);
    var calls = 0;
    final adapter = FakeAdapter({
      'GET /cities': (_) => ++calls == 1 ? const FakeReply(500, {'code': 'internal', 'message': 'x'}) : FakeReply(200, [_city(1, 'Москва')]),
    });
    await tester.pumpWidget(fakeApp(fakeSession(adapter), const CityScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Обновить'), findsOneWidget);

    await tester.tap(find.text('Обновить'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('city_1')), findsOneWidget);
  });

  test('справочник отдаёт города в порядке сервера, без клиентской пересортировки («Ё» после «Е»)', () async {
    final adapter = FakeAdapter({
      'GET /cities': (_) => FakeReply(200, [_city(1, 'Ейск'), _city(2, 'Ёлкино'), _city(3, 'Жуков')]),
    });
    final cities = await CityRepository(fakeSession(adapter).api).all();
    expect(cities.map((c) => c.name), ['Ейск', 'Ёлкино', 'Жуков']);
  });
}
