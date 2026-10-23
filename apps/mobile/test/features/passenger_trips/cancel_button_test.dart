import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/passenger_trips/details/booking_details_screen.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _booking(String status, {String tripStatus = 'active'}) {
  final json = bookingJson(status: status);
  return {
    ...json,
    'trip': {...(json['trip']! as Map<String, Object?>), 'effectiveStatus': tripStatus},
  };
}

FakeServer _server(String status, {String tripStatus = 'active'}) => FakeServer()
  ..on('GET /bookings/b1', (_) => FakeReply(200, _booking(status, tripStatus: tripStatus)))
  ..on('GET /trips/t1', (_) => FakeReply(200, tripDetailsJson()))
  ..on(
    'GET /bookings/b1/cancel-preview',
    (_) => FakeReply(200, {'cancellationsLast30': 0, 'willBlock': false, 'refundAmount': status == 'paid' ? 1200 : null}),
  )
  ..on(
    'POST /bookings/b1/cancel',
    (_) => FakeReply(200, {'status': 'cancelled', 'cancellationsLast30': 0, 'blockedUntil': null, 'refund': null}),
  );

Future<void> _open(WidgetTester tester, FakeServer server) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(fakeSession(server), const BookingDetailsScreen(bookingId: 'b1')));
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

void main() {
  for (final status in ['requested', 'paid']) {
    testWidgets('$status, поездка активна: ряд «Отменить бронь» | «Написать водителю» 50/50, «Оплатить» нет',
        (tester) async {
      await _open(tester, _server(status));

      final cancel = find.text('Отменить бронь');
      final write = find.text('Написать водителю');
      expect(cancel, findsOneWidget);
      expect(write, findsOneWidget);
      expect(find.text('Оплатить'), findsNothing);
      expect(tester.getCenter(cancel).dy, tester.getCenter(write).dy);
      expect(tester.getCenter(cancel).dx, lessThan(tester.getCenter(write).dx));
      final cancelButton = find.ancestor(of: cancel, matching: find.byKey(const Key('booking_cancel')));
      final writeButton = find.ancestor(of: write, matching: find.byKey(const Key('booking_write')));
      expect(tester.getSize(cancelButton).width, tester.getSize(writeButton).width);
    });
  }

  testWidgets('awaiting_payment: ряд «Оплатить» | «Написать водителю», под ним «Отменить бронь» во всю ширину',
      (tester) async {
    await _open(tester, _server('awaiting_payment'));

    final pay = find.text('Оплатить');
    final write = find.text('Написать водителю');
    final cancel = find.text('Отменить бронь');
    expect(pay, findsOneWidget);
    expect(tester.getCenter(pay).dy, tester.getCenter(write).dy);
    expect(tester.getCenter(cancel).dy, greaterThan(tester.getCenter(write).dy));
    final cancelButton = find.byKey(const Key('booking_cancel'));
    final writeButton = find.byKey(const Key('booking_write'));
    expect(tester.getSize(cancelButton).width, greaterThan(tester.getSize(writeButton).width * 1.9));
  });

  testWidgets('бронь отменена: кнопки «Отменить бронь» нет', (tester) async {
    await _open(tester, _server('cancelled'));
    expect(find.text('Отменить бронь'), findsNothing);
  });

  testWidgets('поездка завершена: кнопки «Отменить бронь» нет', (tester) async {
    await _open(tester, _server('paid', tripStatus: 'completed'));
    expect(find.text('Отменить бронь'), findsNothing);
  });

  testWidgets('«Отменить бронь» → окно отмены; «Не отменять» — бронь не тронута, не перечитывается', (tester) async {
    final server = _server('paid');
    await _open(tester, server);

    await tester.tap(find.text('Отменить бронь'));
    await tester.pumpAndSettle();
    expect(find.text('Возврат на карту'), findsOneWidget);

    await tester.tap(find.text('Не отменять'));
    await tester.pumpAndSettle();
    expect(server.of('POST /bookings/b1/cancel'), isEmpty);
    expect(server.of('GET /bookings/b1'), hasLength(1));
  });

  testWidgets('отмена заявки: POST cancel и перечитывание брони', (tester) async {
    final server = _server('requested');
    await _open(tester, server);

    await tester.tap(find.text('Отменить бронь'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отменить заявку'));
    await tester.pumpAndSettle();

    expect(server.of('POST /bookings/b1/cancel'), hasLength(1));
    expect(server.of('GET /bookings/b1'), hasLength(2));
  });
}
