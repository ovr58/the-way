import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/search/data/search_filter.dart';
import 'package:the_way/src/features/search/filter/filter_sheet.dart';
import 'package:the_way/src/features/search/filter/location_service.dart';
import 'package:the_way/src/features/search/search_screen.dart';

import '../../support/fake_api.dart';
import 'order_fixtures.dart';

class _Location implements LocationService {
  const _Location([this.coords]);

  final Coords? coords;

  @override
  Future<Coords?> ifGranted() async => coords;

  @override
  Future<Coords?> request() async => coords;
}

FakeServer _server() {
  final server = FakeServer();
  server.on('GET /trips', (_) => FakeReply(200, [tripCardJson(id: 't1')]));
  server.on('GET /orders', (_) => FakeReply(200, [orderCardJson(), orderCardJson(id: 'o2', from: 'Улица Каменная, дом 3')]));
  server.on('GET /orders/o1', (_) => FakeReply(200, orderDetailsJson()));
  server.on(
    'GET /cities',
    (_) => const FakeReply(200, [
      {'id': 5, 'name': 'Ярославль', 'region': 'Ярославская обл', 'lat': 57.6, 'lng': 39.8},
    ]),
  );
  return server;
}

Future<void> _open(WidgetTester tester, FakeServer server, {UserMode mode = UserMode.driver, Coords? coords}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final session = fakeSession(server)..pendingMode = mode;
  await tester.pumpWidget(testApp(session, SearchScreen(location: _Location(coords))));
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

Finder _filterTab(String label) => find.descendant(of: find.byType(FilterSheet), matching: find.text(label));

void main() {
  testWidgets('пассажир: вкладки «Автомобили · Автобусы», заказов пассажиров нет', (tester) async {
    final server = _server();
    await _open(tester, server, mode: UserMode.passenger);

    expect(find.text('Автомобили'), findsOneWidget);
    expect(find.text('Автобусы'), findsOneWidget);
    expect(find.text('Заказы пассажиров'), findsNothing);
    expect(server.of('GET /orders'), isEmpty);
  });

  testWidgets('водитель: «Поездки · Заказы пассажиров», первая — прежняя лента поездок', (tester) async {
    final server = _server();
    await _open(tester, server);

    expect(find.text('Автомобили'), findsNothing);
    expect(find.byKey(const Key('search_tabs_driver')), findsOneWidget);
    expect(find.text('Заказы пассажиров'), findsOneWidget);
    expect(server.of('GET /trips'), hasLength(1));
    expect(server.of('GET /orders'), isEmpty, reason: 'лента заказов грузится, когда открыта её вкладка');
    expect(find.text('Виктор О.'), findsOneWidget);
  });

  testWidgets('«Заказы пассажиров»: GET /orders, карточки заказа без цены', (tester) async {
    final server = _server();
    await _open(tester, server, coords: const Coords(55.7, 37.6));

    await tester.tap(find.text('Заказы пассажиров'));
    await tester.pumpAndSettle();

    final query = server.of('GET /orders').single.queryParameters;
    expect(query['lat'], 55.7);
    expect(query['lng'], 37.6);
    expect(query.containsKey('near'), isFalse);
    expect(find.text('Город 0, Улица Солнечная, дом 1'), findsOneWidget);
    expect(find.text('Город 0, Улица Каменная, дом 3'), findsOneWidget);
    expect(find.text('Павел С.'), findsNWidgets(2));
    expect(find.text('3.2 км'), findsNWidgets(2));
    expect(find.text('Прибытие ~14:00'), findsNWidgets(2));
    expect(find.text('2 места'), findsNWidgets(2));
    expect(find.text('С животными'), findsNWidgets(2));
    expect(find.text('22 октября, 09:00'), findsNWidgets(2));
    expect(find.textContaining('₽'), findsNothing, reason: 'цены у открытого заказа нет');
  });

  testWidgets('фильтр ленты уходит в GET /orders: откуда и вид', (tester) async {
    final server = _server();
    await _open(tester, server);
    await tester.tap(find.text('Заказы пассажиров'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search_filter_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_from')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ярославль, Ярославская обл'));
    await tester.pumpAndSettle();
    await tester.tap(_filterTab('Посылки'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter_apply')));
    await tester.pumpAndSettle();

    final query = server.of('GET /orders').last.queryParameters;
    expect(query['fromCityId'], 5);
    expect('${query['kind']}', 'parcel');
    expect(query.containsKey('vehicleKind'), isFalse);
  });

  testWidgets('заказ-посылка: «Посылка M» вместо мест', (tester) async {
    final server = _server()
      ..on('GET /orders', (_) => FakeReply(200, [orderCardJson(kind: 'parcel', seats: 0, parcelSize: 'M', extras: [])]));
    await _open(tester, server);
    await tester.tap(find.text('Заказы пассажиров'));
    await tester.pumpAndSettle();

    expect(find.text('Посылка M'), findsOneWidget);
    expect(find.textContaining('мест'), findsNothing);
  });

  testWidgets('пустая лента заказов: «Заказов пассажиров пока нет»', (tester) async {
    final server = _server()..on('GET /orders', (_) => const FakeReply(200, []));
    await _open(tester, server);
    await tester.tap(find.text('Заказы пассажиров'));
    await tester.pumpAndSettle();

    expect(find.text('Заказов пассажиров пока нет'), findsOneWidget);
    expect(find.text('Проверьте чуть позже'), findsOneWidget);
  });

  testWidgets('тап по заказу открывает шторку «Откликнуться на заказ»', (tester) async {
    final server = _server();
    await _open(tester, server);
    await tester.tap(find.text('Заказы пассажиров'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Город 0, Улица Солнечная, дом 1'));
    await tester.pumpAndSettle();

    expect(server.of('GET /orders/o1'), hasLength(1));
    expect(find.text('Откликнуться на заказ'), findsOneWidget);
  });
}
