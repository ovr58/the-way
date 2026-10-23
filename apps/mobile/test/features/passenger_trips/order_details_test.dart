import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/app_routes.dart';
import 'package:the_way/src/features/passenger_trips/order/order_details_screen.dart';
import 'package:the_way/src/features/passenger_trips/routes.dart';
import 'package:the_way/src/widgets/app_header.dart';

import '../driver_bookings/support.dart';
import 'order_support.dart';

/// Детали заказа пассажира и его отмена (план `passenger-order_2026-10-22.md`): раскладка «Детали поездки - Бронь есть»
/// без блока водителя и без цены; «Отменить заказ» — окно по «Детали поездки - Отмена брони» без счётчика отмен.
void main() {
  late MockAdapter adapter;
  late String status;

  setUp(() {
    status = 'open';
    adapter = MockAdapter({
      'GET /orders/o1': (_) => orderDetailsJson(status: status),
      'POST /orders/o1/cancel': (_) {
        status = 'cancelled';
        return orderDetailsJson(status: status);
      },
    });
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      session: makeSession(adapter),
      home: Builder(builder: (context) => passengerTripsRoutes[AppRoutes.passengerTripsOrder]!(context, 'o1')),
    ));
    await settle(tester);
  }

  testWidgets('маршрут passenger_trips/order — экран деталей заказа по id', (tester) async {
    await open(tester);
    expect(find.byType(OrderDetailsScreen), findsOneWidget);
    expect(adapter.log, contains('GET /orders/o1'));
  });

  testWidgets('открытый заказ: номер, «Ищем водителя», точки, дата, прибытие, места, услуги; без водителя и цены',
      (tester) async {
    await open(tester);
    expect(tester.widget<AppHeader>(find.byType(AppHeader)).title, 'Заказ');
    expect(find.text('Заказ №1240'), findsOneWidget);
    expect(find.text('Ищем водителя'), findsOneWidget);
    expect(find.text('Маршрут'), findsOneWidget);
    expect(find.text('Ярославль, Улица Солнечная, дом 1'), findsOneWidget);
    expect(find.text('Москва, Улица Лунная, дом 2'), findsOneWidget);
    expect(find.text('Дата и время'), findsOneWidget);
    expect(find.text('16 мая, 12:00'), findsOneWidget);
    expect(find.text('Примерное время прибытия'), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
    expect(find.text('Количество мест'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('С животными'), findsOneWidget);
    expect(find.text('Водитель'), findsNothing);
    expect(find.textContaining('₽'), findsNothing);
    expect(find.text('Отменить заказ'), findsOneWidget);
  });

  testWidgets('заказ-посылка: размер и комментарий, мест нет', (tester) async {
    adapter.routes['GET /orders/o1'] =
        orderDetailsJson(kind: 'parcel', seats: 0, parcelSize: 'M', parcelComment: 'Документы', extras: const []);
    await open(tester);
    expect(find.text('Посылка'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('Комментарий — Вид посылки'), findsOneWidget);
    expect(find.text('Документы'), findsOneWidget);
    expect(find.text('Количество мест'), findsNothing);
  });

  testWidgets('«Отменить заказ» → окно без счётчика → POST cancel → «Заказ отменён», статус «Отменён», кнопки нет',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('Отменить заказ'));
    await tester.pumpAndSettle();
    expect(find.text('Отменить заказ?'), findsOneWidget);
    expect(find.text('Водители больше не увидят заказ. Отмена не повлияет на ваш аккаунт.'), findsOneWidget);
    expect(find.text('Отмен за 30 дней'), findsNothing);
    await tester.tap(find.byKey(const Key('cancel_confirm')));
    await settle(tester);
    expect(adapter.log.where((r) => r == 'POST /orders/o1/cancel'), hasLength(1));
    expect(find.text('Заказ отменён'), findsOneWidget);
    expect(find.text('Отменён'), findsOneWidget);
    expect(find.text('Отменить заказ'), findsNothing);
  });

  testWidgets('«Не отменять» — заказ не трогается', (tester) async {
    await open(tester);
    await tester.tap(find.text('Отменить заказ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel_keep')));
    await settle(tester);
    expect(adapter.log, isNot(contains('POST /orders/o1/cancel')));
    expect(find.text('Отменить заказ'), findsOneWidget);
  });

  testWidgets('отменённый и истёкший заказ отменить нельзя', (tester) async {
    for (final s in ['cancelled', 'expired']) {
      status = s;
      await open(tester);
      expect(find.text('Отменить заказ'), findsNothing, reason: s);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('invalid_transition при отмене — свой текст, экран перечитывается', (tester) async {
    adapter.routes['POST /orders/o1/cancel'] = (409, {'code': 'invalid_transition', 'message': 'x'});
    await open(tester);
    await tester.tap(find.text('Отменить заказ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel_confirm')));
    await settle(tester);
    expect(find.text('Статус заказа уже изменился. Обновите экран'), findsOneWidget);
    expect(adapter.log.where((r) => r == 'GET /orders/o1'), hasLength(2));
  });
}
