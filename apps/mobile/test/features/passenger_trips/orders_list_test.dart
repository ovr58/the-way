import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/app_routes.dart';
import 'package:the_way/src/features/passenger_trips/list/booking_status.dart';
import 'package:the_way/src/features/passenger_trips/list/passenger_trips_screen.dart';
import 'package:the_way/src/widgets/app_error_view.dart';

import '../driver_bookings/support.dart' hide stop;
import 'order_support.dart';

/// «Мои заказы» пассажира с заказами (план `passenger-order_2026-10-22.md`, шаг Б2.3): брони и заказы
/// одним списком, новые сверху; взятый заказ показан своей бронью, её номер — номер заказа.
OrderCard _card(String status) => OrderCard.fromJson(orderCardJson(status: status));

void main() {
  test('фильтры заказов: открытый — «Созданные», отменённый и истёкший — «Завершенные», взятый — не в списке', () {
    expect(orderFilterOf(_card('open')), BookingFilter.created);
    expect(orderFilterOf(_card('cancelled')), BookingFilter.completed);
    expect(orderFilterOf(_card('expired')), BookingFilter.completed);
    expect(orderFilterOf(_card('matched')), isNull);
  });

  group('список', () {
    late MockAdapter adapter;
    late List<(String, Object?)> pushed;

    setUp(() {
      pushed = [];
      adapter = MockAdapter({
        'GET /bookings/mine': [
          bookingJson(
            id: 'b2',
            number: 1300,
            status: 'awaiting_payment',
            createdAt: '2026-05-13T09:00:00.000Z',
            orderId: 'o2',
            orderNumber: 1250,
          ),
          bookingJson(id: 'b1', number: 1231),
        ],
        'GET /orders/mine': [
          orderCardJson(id: 'o2', number: 1250, status: 'matched', createdAt: '2026-05-12T10:00:00.000Z', bookingId: 'b2'),
          orderCardJson(id: 'o1', number: 1240, createdAt: '2026-05-12T09:00:00.000Z'),
          orderCardJson(id: 'o3', number: 1235, status: 'expired', createdAt: '2026-05-11T09:00:00.000Z'),
          orderCardJson(id: 'o4', number: 1220, status: 'cancelled', createdAt: '2026-05-01T09:00:00.000Z'),
        ],
      });
    });

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(session: makeSession(adapter), home: const PassengerTripsScreen(), pushed: pushed));
      await settle(tester);
    }

    double y(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

    testWidgets('брони и заказы одним списком, новые сверху; взятый заказ не дублируется; номер брони заказа — номер заказа',
        (tester) async {
      await open(tester);
      expect(find.text('Заказ №1250'), findsOneWidget, reason: 'взятый заказ — только своей бронью');
      expect(find.text('Заказ №1300'), findsNothing, reason: 'у брони из заказа номер заказа');
      expect(find.textContaining('Найден водитель'), findsOneWidget);
      expect(y(tester, 'Заказ №1250'), lessThan(y(tester, 'Заказ №1240')));
      expect(y(tester, 'Заказ №1240'), lessThan(y(tester, 'Заказ №1235')));
      expect(y(tester, 'Заказ №1235'), lessThan(y(tester, 'Заказ №1231')));
      expect(y(tester, 'Заказ №1231'), lessThan(y(tester, 'Заказ №1220')));
    });

    testWidgets('карточка заказа по «Мои заказы - Есть заказы»: плашка статуса, маршрут, прибытие, места, услуги, дата — без цены', (tester) async {
      await open(tester);
      final card = find.byKey(const Key('order_card_o1'));
      Finder inCard(Finder f) => find.descendant(of: card, matching: f);
      expect(inCard(find.text('Ищем водителя')), findsOneWidget);
      expect(inCard(find.text('Ярославль, Улица Солнечная, дом 1')), findsOneWidget);
      expect(inCard(find.text('Москва, Улица Лунная, дом 2')), findsOneWidget);
      expect(inCard(find.text('Прибытие ~15:00')), findsOneWidget);
      expect(inCard(find.text('2 места')), findsOneWidget);
      expect(inCard(find.text('С животными')), findsOneWidget);
      expect(inCard(find.text('16 мая, 12:00–15:00')), findsOneWidget);
      expect(inCard(find.textContaining('₽')), findsNothing, reason: 'цену назначает водитель откликом');
      expect(find.descendant(of: find.byKey(const Key('order_card_o3')), matching: find.text('Водитель не найден')),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('order_card_o4')), matching: find.text('Отменён')), findsOneWidget);
    });

    testWidgets('«Созданные» — открытый заказ; «Завершенные» — истёкший и отменённый', (tester) async {
      await open(tester);
      await tester.tap(find.text('Созданные'));
      await tester.pump();
      expect(find.text('Заказ №1240'), findsOneWidget);
      expect(find.text('Заказ №1235'), findsNothing);
      expect(find.text('Заказ №1231'), findsNothing);
      await tester.tap(find.text('Завершенные'));
      await tester.pump();
      expect(find.text('Заказ №1235'), findsOneWidget);
      expect(find.text('Заказ №1220'), findsOneWidget);
      expect(find.text('Заказ №1240'), findsNothing);
    });

    testWidgets('тап по заказу — детали заказа', (tester) async {
      await open(tester);
      await tester.tap(find.text('Заказ №1240'));
      await settle(tester);
      expect(pushed, contains((AppRoutes.passengerTripsOrder, 'o1')));
    });

    // Сценарий: отказ от отклика до оплаты вернул заказ в «open» — отменённая бронь отклика
    // (отклонённое предложение) в списке не показывается нигде; отменённая оплаченная бронь заказа — как обычно.
    testWidgets('отменённая неоплаченная бронь из заказа скрыта, оплаченная отменённая — видна', (tester) async {
      adapter.routes['GET /bookings/mine'] = [
        bookingJson(id: 'b5', number: 1301, status: 'cancelled', orderId: 'o5', orderNumber: 24),
        bookingJson(
          id: 'b6',
          number: 1302,
          status: 'cancelled',
          orderId: 'o6',
          orderNumber: 25,
          paidAt: '2026-05-10T10:00:00.000Z',
        ),
      ];
      adapter.routes['GET /orders/mine'] = [orderCardJson(id: 'o5', number: 24)];
      await open(tester);
      expect(find.text('Заказ №24'), findsOneWidget, reason: 'только открытый заказ');
      expect(find.text('Ищем водителя'), findsOneWidget);
      expect(find.text('Заказ №25'), findsOneWidget);
      await tester.tap(find.text('Завершенные'));
      await tester.pump();
      expect(find.text('Заказ №24'), findsNothing);
      expect(find.text('Заказ №25'), findsOneWidget);
    });

    testWidgets('заказы не загрузились — экран ошибки, а не список без заказов', (tester) async {
      adapter.routes['GET /orders/mine'] = (500, {'code': 'internal', 'message': 'x'});
      await open(tester);
      expect(find.byType(AppErrorView), findsOneWidget);
    });
  });
}
