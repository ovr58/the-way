import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/app_routes.dart';
import 'package:the_way/src/features/search/data/search_filter.dart';
import 'package:the_way/src/features/search/filter/filter_sheet.dart';
import 'package:the_way/src/features/search/filter/location_service.dart';
import 'package:the_way/src/features/search/search_screen.dart';
import 'package:the_way/src/widgets/app_icon.dart';
import 'package:the_way/src/widgets/app_switch.dart';

import '../../support/fake_api.dart';

class _FakeLocation implements LocationService {
  _FakeLocation({this.coords, this.granted = false});

  final Coords? coords;
  final bool granted;
  int requests = 0;

  @override
  Future<Coords?> ifGranted() async => granted ? coords : null;

  @override
  Future<Coords?> request() async {
    requests++;
    return coords;
  }
}

/// Доступ выдан, но первое определение места не удалось (эмулятор без фикса, таймаут): дальше — координаты.
class _LateFix implements LocationService {
  int calls = 0;

  @override
  Future<Coords?> ifGranted() async => ++calls == 1 ? null : const Coords(57.6, 39.8);

  @override
  Future<Coords?> request() async => null;
}

Map<String, Object?> _card(String id, String address) =>
    {...tripCardJson(id: id), 'from': stopJson(0, address)};

FakeServer _server() {
  final server = FakeServer();
  server.on('GET /trips', (_) => FakeReply(200, [_card('t1', 'Первая улица'), _card('t2', 'Вторая улица')]));
  server.on(
    'GET /cities',
    (_) => const FakeReply(200, [
      {'id': 5, 'name': 'Ярославль', 'region': 'Ярославская обл', 'lat': 57.6, 'lng': 39.8},
    ]),
  );
  return server;
}

Future<void> _open(
  WidgetTester tester,
  FakeServer server, {
  bool geoPromptShown = true,
  _FakeLocation? location,
  Map<String, List<Object?>>? opened,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testApp(
      fakeSession(server, geoPromptShown: geoPromptShown),
      SearchScreen(location: location ?? _FakeLocation()),
      opened: opened,
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

Finder _filterTab(String label) =>
    find.descendant(of: find.byType(FilterSheet), matching: find.text(label));

void main() {
  testWidgets('лента: карточки в порядке сервера, тап ведёт в детали поездки', (tester) async {
    final server = _server();
    final opened = <String, List<Object?>>{};
    await _open(tester, server, opened: opened);

    final first = tester.getTopLeft(find.text('Город 0, Первая улица')).dy;
    final second = tester.getTopLeft(find.text('Город 0, Вторая улица')).dy;
    expect(first, lessThan(second));
    final query = server.of('GET /trips').single.queryParameters;
    expect('${query['vehicleKind']}', 'car');
    expect(query.containsKey('fromCityId'), isFalse);
    expect(query.containsKey('kind'), isFalse, reason: 'по умолчанию лента несёт и поездки, и посылки');

    await tester.tap(find.text('Город 0, Вторая улица'));
    await tester.pumpAndSettle();
    expect(opened[AppRoutes.searchDetails], ['t2']);
  });

  testWidgets('вкладка «Автобусы» — лента с vehicleKind=bus; назад — снова легковые', (tester) async {
    final server = _server()
      ..on('GET /trips', (o) => FakeReply(200, [
            '${o.queryParameters['vehicleKind']}' == 'bus' ? _card('b1', 'Автобусная улица') : _card('t1', 'Первая улица'),
          ]));
    final opened = <String, List<Object?>>{};
    await _open(tester, server, opened: opened);
    expect(server.of('GET /trips'), hasLength(1));

    await tester.tap(find.text('Автобусы'));
    await tester.pumpAndSettle();

    expect('${server.of('GET /trips').last.queryParameters['vehicleKind']}', 'bus');
    expect(find.text('Город 0, Автобусная улица'), findsOneWidget);
    expect(find.text('Город 0, Первая улица'), findsNothing);
    await tester.tap(find.text('Город 0, Автобусная улица'));
    await tester.pumpAndSettle();
    expect(opened[AppRoutes.searchDetails], ['b1']);
  });

  testWidgets('вкладка «Автобусы» без поездок: «Здесь ещё нет заказов»', (tester) async {
    final server = _server()
      ..on('GET /trips', (o) => FakeReply(200, [
            if ('${o.queryParameters['vehicleKind']}' != 'bus') _card('t1', 'Первая улица'),
          ]));
    await _open(tester, server);
    await tester.tap(find.text('Автобусы'));
    await tester.pumpAndSettle();
    expect(find.text('Здесь ещё нет заказов'), findsOneWidget);
    expect(find.text('Город 0, Первая улица'), findsNothing);

    await tester.tap(find.text('Автомобили'));
    await tester.pumpAndSettle();
    expect('${server.of('GET /trips').last.queryParameters['vehicleKind']}', 'car');
    expect(find.text('Город 0, Первая улица'), findsOneWidget);
  });

  testWidgets('пустая лента: «Здесь ещё нет заказов»', (tester) async {
    final server = _server()..on('GET /trips', (_) => const FakeReply(200, []));
    await _open(tester, server);
    expect(find.text('Здесь ещё нет заказов'), findsOneWidget);
  });

  testWidgets('первое открытие: «Разрешить» кладёт координаты в запрос ленты', (tester) async {
    final server = _server();
    final location = _FakeLocation(coords: const Coords(55.7, 37.6));
    await _open(tester, server, geoPromptShown: false, location: location);

    expect(find.text('Доступ к геолокации'), findsOneWidget);
    await tester.tap(find.text('Разрешить'));
    await tester.pumpAndSettle();

    expect(location.requests, 1);
    final last = server.of('GET /trips').last.queryParameters;
    expect(last['lat'], 55.7);
    expect(last['lng'], 37.6);
  });

  testWidgets('«Пропустить»: окно больше не покажется, координат нет, «Поблизости» неактивен',
      (tester) async {
    final server = _server();
    final location = _FakeLocation(coords: const Coords(55.7, 37.6));
    await _open(tester, server, geoPromptShown: false, location: location);

    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();

    expect(location.requests, 0);
    expect(server.of('GET /trips').single.queryParameters.containsKey('lat'), isFalse);

    await tester.tap(find.byKey(const Key('search_filter_button')));
    await tester.pumpAndSettle();
    expect(tester.widget<AppSwitch>(find.byKey(const Key('filter_near'))).onChanged, isNull);
  });

  testWidgets('фильтр: город «Откуда» и «Посылки» уходят в запрос, на кнопке красная точка',
      (tester) async {
    final server = _server();
    await _open(tester, server);
    expect(find.byKey(const Key('search_filter_dot')), findsNothing);

    await tester.tap(find.byKey(const Key('search_filter_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_from')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ярославль, Ярославская обл'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Посылки'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_apply')));
    await tester.pumpAndSettle();

    final query = server.of('GET /trips').last.queryParameters;
    expect(query['fromCityId'], 5);
    expect('${query['kind']}', 'parcel');
    expect(find.byKey(const Key('search_filter_dot')), findsOneWidget);
  });

  testWidgets('«Очистить»: цвет текста — токены текста («Фильтр» — отключён, «Фильтр» — красный)', (tester) async {
    final server = _server();
    await _open(tester, server);

    await tester.tap(find.byKey(const Key('search_filter_button')));
    await tester.pumpAndSettle();
    Color? clearColor() => tester.widget<Text>(find.text('Очистить')).style?.color;
    // «Фильтр»: #cacbce у отключённой кнопки, «Фильтр»: #ff383c.
    expect(clearColor(), const Color(0xFFCACBCE));

    await tester.tap(_filterTab('Посылки'));
    await tester.pumpAndSettle();
    expect(clearColor(), const Color(0xFFFF383C));
  });

  testWidgets('«Очистить» сбрасывает фильтр', (tester) async {
    final server = _server();
    await _open(tester, server);

    await tester.tap(find.byKey(const Key('search_filter_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Посылки'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_apply')));
    await tester.pumpAndSettle();

    expect(server.of('GET /trips').last.queryParameters.containsKey('kind'), isFalse);
    expect(find.byKey(const Key('search_filter_dot')), findsNothing);
  });

  testWidgets('«Поездки / Посылки» — выбор: повторное нажатие снимает, без выбора kind не уходит',
      (tester) async {
    final server = _server();
    await _open(tester, server);

    await tester.tap(find.byKey(const Key('search_filter_button')));
    await tester.pumpAndSettle();
    await tester.tap(_filterTab('Поездки'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_apply')));
    await tester.pumpAndSettle();
    expect('${server.of('GET /trips').last.queryParameters['kind']}', 'ride');

    await tester.tap(find.byKey(const Key('search_filter_button')));
    await tester.pumpAndSettle();
    await tester.tap(_filterTab('Поездки'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_apply')));
    await tester.pumpAndSettle();
    expect(server.of('GET /trips').last.queryParameters.containsKey('kind'), isFalse);
    expect(find.byKey(const Key('search_filter_dot')), findsNothing);
  });

  testWidgets('координаты есть: «Поблизости» включается и уходит near=true', (tester) async {
    final server = _server();
    final location = _FakeLocation(coords: const Coords(55.7, 37.6), granted: true);
    await _open(tester, server, location: location);

    await tester.tap(find.byKey(const Key('search_filter_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_near')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_apply')));
    await tester.pumpAndSettle();

    final query = server.of('GET /trips').last.queryParameters;
    expect(query['near'], true);
    expect(query['lat'], 55.7);
  });
  testWidgets('место не определилось при открытии ленты — фильтр спрашивает снова; «Поблизости» без подписи и фильтрует', (tester) async {
    final server = _server();
    final location = _LateFix();
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(fakeSession(server, geoPromptShown: true), SearchScreen(location: location)));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(server.of('GET /trips').last.queryParameters.containsKey('lat'), isFalse);

    await tester.tap(find.byKey(const Key('search_filter_button')));
    await tester.pumpAndSettle();
    expect(find.text('Для поиска поблизости нужен доступ к геолокации'), findsNothing);
    await tester.tap(find.byKey(const Key('filter_near')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_apply')));
    await tester.pumpAndSettle();

    final query = server.of('GET /trips').last.queryParameters;
    expect(query['near'], true);
    expect(query['lat'], 57.6);
    expect(query['lng'], 39.8);
  });

  // Тема filter-indicator («Базовые экраны - Поездок нет» – «Базовые экраны - Поездки есть», «Базовые экраны - Идёт регистрация пассажиров»): воронка всегда чёрная 50% (`System / Filter` #0c0c0c 50%),
  // красный кружок 9×9 при фильтре («Фильтр- поездок нет») — на углу воронки: на 6 ниже и на 5 левее угла кнопки.
  testWidgets('кнопка фильтра: воронка text.secondary, кружок на 6 ниже и 5 левее угла кнопки', (tester) async {
    final server = _server();
    await _open(tester, server);
    final funnel = find.descendant(
      of: find.byKey(const Key('search_filter_button')),
      matching: find.byWidgetPredicate((w) => w is AppIcon && w.name == 'system_filter'),
    );
    expect(tester.widget<AppIcon>(funnel).color, const Color(0x800C0C0C));

    await tester.tap(find.byKey(const Key('search_filter_button')));
    await tester.pumpAndSettle();
    await tester.tap(_filterTab('Посылки'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_apply')));
    await tester.pumpAndSettle();

    expect(tester.widget<AppIcon>(funnel).color, const Color(0x800C0C0C));
    final button = tester.getRect(find.byKey(const Key('search_filter_button')));
    final dot = tester.getRect(find.byKey(const Key('search_filter_dot')));
    expect(dot.size, const Size(9, 9));
    expect(dot.top - button.top, 6);
    expect(button.right - dot.right, 5);
  });
}
