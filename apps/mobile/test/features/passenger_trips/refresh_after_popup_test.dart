import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/app_routes.dart';
import 'package:the_way/src/features/booking/answers/answer_popups.dart';
import 'package:the_way/src/features/passenger_trips/details/booking_details_screen.dart';
import 'package:the_way/src/features/passenger_trips/list/passenger_trips_screen.dart';

import '../driver_bookings/support.dart';
import 'order_support.dart';

/// Сценарий: после действия во всплывающем окне ответа («Пришёл ответ») или отмены («Пришёл ответ») «Мои заказы» и
/// детали брони перечитываются сразу — окно открывается поверх оболочки, а не из списка.
void main() {
  late MockAdapter adapter;

  setUp(() {
    adapter = MockAdapter({
      'GET /bookings/mine': [bookingJson(id: 'b1', number: 1300, status: 'awaiting_payment', orderId: 'o1', orderNumber: 24)],
      'GET /orders/mine': <Object?>[],
      'GET /bookings/b1': bookingJson(id: 'b1', number: 1300, status: 'awaiting_payment'),
      'GET /trips/t1': tripDetailsJson(),
      'GET /bookings/b1/cancel-preview': {'cancellationsLast30': 0, 'willBlock': false, 'counts': false},
      'POST /bookings/b1/cancel': {'status': 'cancelled', 'cancellationsLast30': 0},
      'POST /bookings/b1/pay': bookingJson(id: 'b1', number: 1300),
    });
  });

  int count(String key) => adapter.log.where((r) => r == key).length;

  Future<void> openPopup(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(session: makeSession(adapter), home: home));
    await settle(tester);
    tester.state<NavigatorState>(find.byType(Navigator)).push(answerPopupRoute(AppRoutes.bookingAccepted, 'b1'));
    await settle(tester);
  }

  testWidgets('список: «Отказаться от заявки» → «Отменить заявку» — брони и заказы перечитаны', (tester) async {
    await openPopup(tester, const PassengerTripsScreen());
    expect(count('GET /bookings/mine'), 1);
    await tester.tap(find.byKey(const Key('accepted_decline')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('cancel_confirm')));
    await settle(tester);
    expect(count('POST /bookings/b1/cancel'), 1);
    expect(count('GET /bookings/mine'), 2);
    expect(count('GET /orders/mine'), 2);
  });

  testWidgets('список: оплата из окна «Пришёл ответ» — брони перечитаны', (tester) async {
    await openPopup(tester, const PassengerTripsScreen());
    await tester.tap(find.byKey(const Key('accepted_pay')));
    await settle(tester);
    expect(count('POST /bookings/b1/pay'), 1);
    expect(count('GET /bookings/mine'), 2);
  });

  testWidgets('детали брони: оплата из окна «Пришёл ответ» поверх деталей — бронь перечитана', (tester) async {
    await openPopup(tester, const BookingDetailsScreen(bookingId: 'b1'));
    expect(count('GET /bookings/b1'), 1);
    await tester.tap(find.byKey(const Key('accepted_pay')));
    await settle(tester);
    expect(count('GET /bookings/b1'), 2);
  });
}
