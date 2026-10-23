import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/app_routes.dart';
import 'package:the_way/src/app/updates_watcher.dart';
import 'package:the_way/src/features/booking/answers/paid_screen.dart';
import 'package:the_way/src/features/booking/answers/updates_flow.dart';
import 'package:the_way/src/features/booking/data/booking_changes.dart';
import 'package:the_way/src/widgets/app_button.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _update(String id, String kind) =>
    {'bookingId': id, 'tripId': 't1', 'kind': kind, 'at': '2026-10-21T10:00:00.000Z'};

/// Экран, у которого кнопка «open» запускает проверку событий (как оболочка на старте).
Future<Map<String, List<Object?>>> _start(
  WidgetTester tester,
  FakeServer server,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <String, List<Object?>>{};
  await tester.pumpWidget(
    testApp(fakeSession(server), Builder(builder: (context) {
      return Scaffold(
        body: TextButton(
          key: const Key('check'),
          onPressed: () => checkUpdates(context),
          child: const Text('check'),
        ),
      );
    }), opened: opened),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('check')));
  await tester.pumpAndSettle();
  return opened;
}

FakeServer _server(List<Map<String, Object?>> updates) {
  final server = FakeServer();
  server.on('GET /updates', (_) => FakeReply(200, updates));
  server.on('POST /updates/b1/seen', (_) => const FakeReply(204, null));
  server.on('POST /updates/b2/seen', (_) => const FakeReply(204, null));
  server.on('POST /bookings/b1/pay', (_) => FakeReply(200, bookingJson(status: 'paid')));
  return server;
}

void main() {
  tearDown(resetUpdatesCheck);

  // Автообновление (принятое решение 2026-10-22): вторая проверка, пока идёт первая (окно ещё открыто), присоединяется
  // к ней — один запрос, одно окно; после событий видимые списки перечитываются (`bookingChanges`).
  testWidgets('повторная проверка во время идущей: один GET /updates, одно окно; после событий — сигнал спискам',
      (tester) async {
    final server = _server([_update('b2', 'driver_rejected')]);
    final before = bookingChanges.value;
    await _start(tester, server);
    expect(find.text('Водитель отклонил заявку'), findsOneWidget);
    // Окно поверх кнопки — проверку зовём напрямую, как таймер оболочки.
    checkUpdates(tester.element(find.byKey(const Key('check'))));
    await tester.pumpAndSettle();
    expect(server.of('GET /updates'), hasLength(1));
    expect(find.text('Водитель отклонил заявку'), findsOneWidget);
    await tester.tap(find.byKey(const Key('declined_ok')));
    await tester.pumpAndSettle();
    expect(bookingChanges.value, greaterThan(before));
  });

  testWidgets('события по одному: «Пришёл ответ» → оплата → «Заказ - Оплата прошла», затем «Пришёл отказ»; seen после показа каждого',
      (tester) async {
    final server = _server([_update('b1', 'driver_accepted'), _update('b2', 'driver_rejected')]);
    final opened = await _start(tester, server);

    // Первое окно открыто, второе ещё нет, seen не уходил.
    expect(find.text('Водитель принял заявку'), findsOneWidget);
    expect(find.text('Водитель отклонил заявку'), findsNothing);
    expect(server.of('POST /updates/b1/seen'), isEmpty);
    expect(find.text('Отказаться от заявки'), findsOneWidget);

    await tester.tap(find.byKey(const Key('accepted_pay')));
    await tester.pumpAndSettle();

    expect(server.of('POST /bookings/b1/pay'), hasLength(1));
    expect(opened[AppRoutes.bookingPaid], ['b1']);

    // Окно «Пришёл ответ» заменено экраном «Заказ - Оплата прошла»; пока он открыт, «Пришёл отказ» не показывается и seen не уходит.
    expect(find.text('Водитель отклонил заявку'), findsNothing);
    expect(server.of('POST /updates/b1/seen'), isEmpty);

    Navigator.of(tester.element(find.text('route:booking/paid'))).pop();
    await tester.pumpAndSettle();

    // «Заказ - Оплата прошла» закрыт — первое событие показано, следующее идёт после него.
    expect(server.of('POST /updates/b1/seen'), hasLength(1));
    expect(find.text('Водитель отклонил заявку'), findsOneWidget);
    expect(server.of('POST /updates/b2/seen'), isEmpty);

    await tester.tap(find.text('Ок'));
    await tester.pumpAndSettle();
    expect(server.of('POST /updates/b2/seen'), hasLength(1));
  });

  testWidgets('«Пришёл ответ»: «Отказаться от заявки» под «Перейти к оплате»; отмена закрывает окно без «Заказ - Оплата прошла» и без оплаты',
      (tester) async {
    final server = _server([_update('b1', 'driver_accepted')])
      ..on('GET /bookings/b1/cancel-preview',
          (_) => const FakeReply(200, {'cancellationsLast30': 0, 'willBlock': false, 'refundAmount': null}))
      ..on('POST /bookings/b1/cancel',
          (_) => const FakeReply(200, {'status': 'cancelled', 'cancellationsLast30': 0, 'blockedUntil': null}));
    final opened = await _start(tester, server);

    expect(
      tester.getCenter(find.byKey(const Key('accepted_decline'))).dy,
      greaterThan(tester.getCenter(find.byKey(const Key('accepted_pay'))).dy),
    );

    await tester.tap(find.byKey(const Key('accepted_decline')));
    await tester.pumpAndSettle();
    expect(find.text('Две отмены в течение 30 дней приведут к автоматической блокировке аккаунта на 30 дней.'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel_confirm')));
    await tester.pumpAndSettle();

    expect(server.of('POST /bookings/b1/cancel'), hasLength(1));
    expect(server.of('POST /bookings/b1/pay'), isEmpty);
    expect(opened.containsKey(AppRoutes.bookingPaid), isFalse);
    expect(find.text('Водитель принял заявку'), findsNothing);
    expect(server.of('POST /updates/b1/seen'), hasLength(1));
  });

  testWidgets('«Пришёл ответ»: «Не отменять» в окне отмены — окно ответа остаётся', (tester) async {
    final server = _server([_update('b1', 'driver_accepted')])
      ..on('GET /bookings/b1/cancel-preview',
          (_) => const FakeReply(200, {'cancellationsLast30': 0, 'willBlock': false, 'refundAmount': null}));
    await _start(tester, server);

    await tester.tap(find.byKey(const Key('accepted_decline')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel_keep')));
    await tester.pumpAndSettle();

    expect(server.of('POST /bookings/b1/cancel'), isEmpty);
    expect(find.text('Водитель принял заявку'), findsOneWidget);
    expect(server.of('POST /updates/b1/seen'), isEmpty);
  });

  testWidgets('оплата не прошла: снэкбар по коду, окно остаётся', (tester) async {
    final server = _server([_update('b1', 'driver_accepted')])
      ..on('POST /bookings/b1/pay', (_) => const FakeReply(409, {'code': 'invalid_transition', 'message': 'x'}));
    final opened = await _start(tester, server);

    await tester.tap(find.byKey(const Key('accepted_pay')));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось выполнить действие. Попробуйте ещё раз'), findsWidgets);
    expect(find.text('Водитель принял заявку'), findsOneWidget);
    expect(opened.containsKey(AppRoutes.bookingPaid), isFalse);
    expect(server.of('POST /updates/b1/seen'), isEmpty);
  });

  testWidgets('события водителя ведут на экраны U5 с bookingId', (tester) async {
    final server = _server([_update('b1', 'new_request'), _update('b2', 'passenger_paid')]);
    final opened = await _start(tester, server);

    expect(opened[AppRoutes.driverBookingsNewResponse], ['b1']);
    Navigator.of(tester.element(find.text('route:driver_bookings/new_response'))).pop();
    await tester.pumpAndSettle();

    expect(server.of('POST /updates/b1/seen'), hasLength(1));
    expect(opened[AppRoutes.driverBookingsPassengerPaid], ['b2']);
    Navigator.of(tester.element(find.text('route:driver_bookings/passenger_paid'))).pop();
    await tester.pumpAndSettle();
    expect(server.of('POST /updates/b2/seen'), hasLength(1));
  });

  testWidgets('«Заказ - Оплата прошла»: «Мои заказы» — текст и кнопка (вкладка так называется) ведут в список, а не в детали брони', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <String, List<Object?>>{};
    await tester.pumpWidget(
      testApp(fakeSession(FakeServer()), const BookingPaidScreen(bookingId: 'b9'), opened: opened),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    expect(find.text('Место забронировано'), findsOneWidget);
    expect(find.textContaining('доступны в разделе «Мои заказы»'), findsOneWidget);
    expect(find.textContaining('Мои поездки'), findsNothing);
    await tester.tap(find.widgetWithText(AppButton, 'Мои заказы'));
    await tester.pumpAndSettle();
    expect(opened[AppRoutes.shell], [1]);
    expect(opened.containsKey(AppRoutes.passengerTripsDetails), isFalse);
  });

  testWidgets('«Заказ - Оплата прошла»: вокруг галочки — искры', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(fakeSession(FakeServer()), const BookingPaidScreen(bookingId: 'b9')),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('success_sparks')), findsOneWidget);
  });
}
