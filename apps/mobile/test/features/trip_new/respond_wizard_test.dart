import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/trip_new/steps/booking_mode_step.dart';
import 'package:the_way/src/features/trip_new/steps/route_step.dart';
import 'package:the_way/src/features/trip_new/trip_new_args.dart';
import 'package:the_way/src/features/trip_new/wizard_controller.dart';
import 'package:the_way/src/widgets/app_button.dart';

import '../../screens/shot.dart';
import '../../screens/world.dart' show ShotWorld;
import '../passenger_trips/order_support.dart';
import 'support.dart';

/// Отклик водителя новой поездкой: мастер поездки,
/// заполненный из заказа; публикация уходит с `orderId`.
OrderDetails _order({String kind = 'ride', int seats = 2, String parcelSize = 'S', List<String> extras = const ['pets', 'luggage']}) =>
    OrderDetails.fromJson(orderDetailsJson(kind: kind, seats: seats, parcelSize: parcelSize, extras: extras, isMine: false));

const _car = Car(
  id: 'car1',
  brand: 'Toyota',
  model: 'Camry',
  kind: VehicleKind.car,
  seats: 4,
  plate: '7841HX-7',
  status: CarStatus.verified,
  documents: [],
);

void main() {
  shotInit();

  group('заполнение из заказа', () {
    test('поездка: точки, дата и время по Москве, места, услуги и посылка с ценами по умолчанию', () {
      final c = WizardController.fromOrder(repositoryOf(FakeAdapter({})), _order());
      expect(c.passengerOrder, isFalse, reason: 'это мастер водителя — все 6 шагов');
      expect(c.orderId, 'o1');
      expect(c.kind, TripKind.ride);
      expect(c.stops.map((s) => s.address), ['Улица Солнечная, дом 1', 'Улица Ленина, дом 5', 'Улица Лунная, дом 2']);
      expect(c.stops.map((s) => s.cityId), [1, 2, 3]);
      expect(c.date, DateTime(2026, 5, 16));
      expect(c.departTime, const TimeOfDay(hour: 12, minute: 0));
      expect(c.arriveTime, const TimeOfDay(hour: 15, minute: 0));
      expect(c.seatsTotal, 2);
      expect(c.extras, {ExtraKind.pets: 150, ExtraKind.luggage: 150, ExtraKind.parcelS: 150});
      expect(c.parcelOnly, isFalse);
    });

    test('мест — не меньше мест заказа', () {
      final c = WizardController.fromOrder(repositoryOf(FakeAdapter({})), _order(seats: 3));
      c.setSeats(1);
      expect(c.seatsTotal, 3);
      c.setSeats(5);
      expect(c.seatsTotal, 5);
    });

    test('заказ-посылка: поездка-посылка «Без проезда пассажира», размер заказа включён', () {
      final c = WizardController.fromOrder(
        repositoryOf(FakeAdapter({})),
        _order(kind: 'parcel', seats: 0, parcelSize: 'M', extras: const []),
      );
      expect(c.kind, TripKind.parcel);
      expect(c.seatsTotal, 0);
      expect(c.parcelOnly, isTrue);
      expect(c.extras, {ExtraKind.parcelM: 250});
    });
  });

  group('публикация с orderId', () {
    late FakeAdapter adapter;
    late WizardController c;

    setUp(() {
      adapter = FakeAdapter({
        'POST /trips': (o) => FakeReply(tripJson()),
        'GET /trips/limits': (o) => const FakeReply({'forwardUsed': 1, 'reverseUsed': 0, 'weekUsed': 1, 'weekLimit': 10, 'maxDaysAhead': 3}),
      });
      c = WizardController.fromOrder(repositoryOf(adapter), _order())
        ..setPriceFull(1200)
        ..setPriceBoardingMin(300)
        ..setCar(_car);
      for (final p in c.pricePairs) {
        c.setPairPrice(p.$1, p.$2, 600);
      }
    });

    testWidgets('тело POST /trips несёт orderId заказа', (tester) async {
      tallView(tester);
      await tester.pumpWidget(app(BookingModeStep(controller: c)));
      await tester.tap(find.widgetWithText(AppButton, 'Опубликовать поездку'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Да, опубликовать'));
      await tester.pumpAndSettle();
      final body = adapter.callsTo('POST /trips').single.data as Map<String, dynamic>;
      expect(body['orderId'], 'o1');
      expect(body['seatsTotal'], 2);
      expect(find.text('Заказ опубликован!'), findsOneWidget);
    });

    testWidgets('order_unavailable и order_mismatch — свои тексты', (tester) async {
      tallView(tester);
      const cases = {
        'order_unavailable': 'Заказ уже взят другим водителем или отменён',
        'order_mismatch': 'Поездка не подходит под заказ: проверьте дату, маршрут, места и услуги',
      };
      for (final entry in cases.entries) {
        adapter.routes['POST /trips'] = (o) => FakeReply({'code': entry.key, 'message': 'x'}, 409);
        await tester.pumpWidget(app(BookingModeStep(controller: c)));
        await tester.tap(find.widgetWithText(AppButton, 'Опубликовать поездку'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Да, опубликовать'));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget, reason: entry.key);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  testWidgets('маршрут trip_new с TripNewArgs.respond — мастер поездки из 6 шагов с точками заказа', (tester) async {
    shotSurface(tester);
    final world = ShotWorld(mode: UserMode.driver)..routes['GET /route-templates'] = <Object?>[];
    await world.open(tester, route: 'trip_new', args: TripNewArgs.respond(_order()));
    expect(find.text('Шаг 1 из 6'), findsOneWidget);
    await world.tap(tester, find.widgetWithText(AppButton, 'Далее'));
    expect(find.byType(RouteStep), findsOneWidget);
    expect(find.text('Ярославль, Улица Солнечная, дом 1'), findsOneWidget);
    expect(find.text('Москва, Улица Лунная, дом 2'), findsOneWidget);
    debugDisableShadows = true;
  });
}
