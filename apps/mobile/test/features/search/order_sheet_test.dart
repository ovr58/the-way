import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/app_routes.dart';
import 'package:the_way/src/features/search/data/search_filter.dart';
import 'package:the_way/src/features/search/filter/location_service.dart';
import 'package:the_way/src/features/search/orders/order_sheet.dart';
import 'package:the_way/src/features/search/search_screen.dart';
import 'package:the_way/src/features/trip_new/trip_new_args.dart';
import 'package:the_way/src/widgets/app_button.dart';

import '../../support/fake_api.dart';
import 'order_fixtures.dart';

class _NoLocation implements LocationService {
  const _NoLocation();

  @override
  Future<Coords?> ifGranted() async => null;

  @override
  Future<Coords?> request() async => null;
}

FakeServer _server({List<String> matching = const ['t1', 't2'], List<String> middle = const []}) {
  final server = FakeServer();
  server.on('GET /trips', (_) => const FakeReply(200, []));
  server.on('GET /orders', (_) => FakeReply(200, [orderCardJson()]));
  server.on('GET /orders/o1', (_) => FakeReply(200, orderDetailsJson(matching: matching, middle: middle)));
  server.on('POST /orders/o1/respond', (_) => FakeReply(201, bookingJson(status: 'awaiting_payment')));
  return server;
}

/// Лента водителя → вкладка «Заказы пассажиров» → шторка заказа o1.
Future<void> _openSheet(WidgetTester tester, FakeServer server, {Map<String, List<Object?>>? opened}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final session = fakeSession(server)..pendingMode = UserMode.driver;
  await tester.pumpWidget(testApp(session, const SearchScreen(location: _NoLocation()), opened: opened));
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Заказы пассажиров'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Город 0, Улица Солнечная, дом 1'));
  await tester.pumpAndSettle();
}

/// Только внутри шторки: за ней — лента с той же карточкой заказа.
Finder _sheet(String text) => find.descendant(of: find.byType(OrderSheet), matching: find.text(text));

AppButton _button(WidgetTester tester, String key) => tester.widget<AppButton>(find.byKey(Key(key)));

void main() {
  testWidgets('шторка: точки, дата, места, услуги, пассажир и мои поездки с суммой', (tester) async {
    await _openSheet(tester, _server());

    expect(find.text('Откликнуться на заказ'), findsOneWidget);
    expect(find.text('Точка отправления'), findsOneWidget);
    expect(find.text('Конечная точка'), findsOneWidget);
    expect(_sheet('Город 1, Улица Лунная, дом 2'), findsOneWidget);
    expect(_sheet('22 октября, 09:00'), findsOneWidget);
    expect(_sheet('2 места'), findsOneWidget);
    expect(find.text('Животные'), findsOneWidget);
    expect(_sheet('Павел С.'), findsOneWidget);
    expect(find.text('Ваши поездки в этот день'), findsOneWidget);
    expect(find.text('Поездка №7 · 09:00'), findsOneWidget);
    expect(find.text('Поездка №8 · 09:00'), findsOneWidget);
    expect(find.text('Итого 2\u00A0500 ₽'), findsOneWidget);
    expect(find.text('Итого 2\u00A0600 ₽'), findsOneWidget);
    expect(_button(tester, 'order_respond').onPressed, isNull, reason: 'поездка не выбрана');
  });

  testWidgets('«Откликнуться» выбранной поездкой: тело запроса, снэкбар, лента перечитана', (tester) async {
    final server = _server();
    await _openSheet(tester, server);
    expect(server.of('GET /orders'), hasLength(1));

    await tester.tap(find.byKey(const Key('order_trip_t2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('order_respond')));
    await tester.pumpAndSettle();

    final body = server.of('POST /orders/o1/respond').single.data;
    expect(body is String ? jsonDecode(body) : body, {'tripId': 't2'});
    expect(find.text('Откликнуться на заказ'), findsNothing);
    expect(find.text('Отклик отправлен. Пассажир получит предложение'), findsOneWidget);
    expect(server.of('GET /orders'), hasLength(2));
  });

  testWidgets('промежуточные остановки заказа — между точкой отправления и конечной', (tester) async {
    await _openSheet(tester, _server(middle: const ['Улица Ленина, дом 5']));

    expect(find.text('Промежуточные остановки'), findsOneWidget);
    double y(String t) => tester.getTopLeft(_sheet(t)).dy;
    expect(y('Город 0, Улица Солнечная, дом 1'), lessThan(y('Город 1, Улица Ленина, дом 5')));
    expect(y('Город 1, Улица Ленина, дом 5'), lessThan(y('Город 2, Улица Лунная, дом 2')));
  });

  testWidgets('без промежуточных остановок блока нет', (tester) async {
    await _openSheet(tester, _server());
    expect(find.text('Промежуточные остановки'), findsNothing);
  });

  testWidgets('единственная подходящая поездка выбрана сама: «Откликнуться» сразу активна', (tester) async {
    final server = _server(matching: const ['t1']);
    await _openSheet(tester, server);

    expect(_button(tester, 'order_respond').onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('order_respond')));
    await tester.pumpAndSettle();

    final body = server.of('POST /orders/o1/respond').single.data;
    expect(body is String ? jsonDecode(body) : body, {'tripId': 't1'});
  });

  testWidgets('«Создать поездку» открывает мастер с TripNewArgs.respond(заказ)', (tester) async {
    final opened = <String, List<Object?>>{};
    await _openSheet(tester, _server(), opened: opened);

    await tester.tap(find.byKey(const Key('order_create_trip')));
    await tester.pumpAndSettle();

    final args = opened[AppRoutes.tripNew]!.single;
    expect(args, isA<TripNewArgs>());
    expect((args as TripNewArgs).isPassengerOrder, isFalse);
    expect(args.order!.id, 'o1');
  });

  testWidgets('подходящих поездок нет: строка и только «Создать поездку»', (tester) async {
    await _openSheet(tester, _server(matching: const []));

    expect(find.text('Подходящих поездок в этот день нет'), findsOneWidget);
    expect(find.byKey(const Key('order_respond')), findsNothing);
    expect(find.byKey(const Key('order_create_trip')), findsOneWidget);
  });

  testWidgets('order_unavailable: текст «Заказ уже взят…», шторка закрыта, лента перечитана', (tester) async {
    final server = _server()
      ..on(
        'POST /orders/o1/respond',
        (_) => const FakeReply(409, {'code': 'order_unavailable', 'message': 'занят'}),
      );
    await _openSheet(tester, server);

    await tester.tap(find.byKey(const Key('order_trip_t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('order_respond')));
    await tester.pumpAndSettle();

    expect(find.text('Заказ уже взят другим водителем или отменён'), findsOneWidget);
    expect(find.text('Откликнуться на заказ'), findsNothing);
    expect(server.of('GET /orders'), hasLength(2));
  });

  testWidgets('order_mismatch: текст в шторке, шторка открыта', (tester) async {
    final server = _server()
      ..on(
        'POST /orders/o1/respond',
        (_) => const FakeReply(409, {'code': 'order_mismatch', 'message': 'не подходит'}),
      );
    await _openSheet(tester, server);

    await tester.tap(find.byKey(const Key('order_trip_t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('order_respond')));
    await tester.pumpAndSettle();

    expect(find.text('Поездка не подходит под заказ'), findsOneWidget);
    expect(find.text('Откликнуться на заказ'), findsOneWidget);
  });

  testWidgets('заказ-посылка: размер и комментарий в шторке', (tester) async {
    final server = _server()
      ..on(
        'GET /orders/o1',
        (_) => FakeReply(
          200,
          orderDetailsJson(kind: 'parcel', seats: 0, parcelSize: 'M', parcelComment: 'Документы', extras: []),
        ),
      );
    await _openSheet(tester, server);

    expect(_sheet('Посылка M'), findsOneWidget);
    expect(find.text('Документы'), findsOneWidget);
    expect(find.text('0 мест'), findsNothing);
    expect(find.text('Свободно 3 места'), findsNWidgets(2));
  });
}
