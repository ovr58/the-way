import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/trip_new/steps/booking_mode_step.dart';
import 'package:the_way/src/features/trip_new/steps/price_step.dart';
import 'package:the_way/src/features/trip_new/steps/type_step.dart';
import 'package:the_way/src/features/trip_new/wizard_controller.dart';
import 'package:the_way/src/widgets/app_button.dart';

import '../passenger_trips/order_support.dart';
import 'support.dart';

/// Доправки (принятые решения 2026-10-22).
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
  group('«Новый заказ - Тип заказа»: подписи типа у водителя — «Везу пассажиров» / «Везу только посылки»', () {
    testWidgets('мастер поездки', (tester) async {
      await tester.pumpWidget(app(TypeStep(controller: WizardController(repositoryOf(FakeAdapter({}))))));
      expect(find.text('Везу пассажиров'), findsOneWidget);
      expect(find.text('Везу только посылки'), findsOneWidget);
      expect(find.text('Найти водителя для себя'), findsNothing);
      // Автобусом тоже везут пассажиров: карточка — «Пассажиры», а не «Автомобиль».
      expect(find.text('Пассажиры'), findsOneWidget);
      expect(find.text('Автомобиль'), findsNothing);
    });

    testWidgets('мастер заказа пассажира — тексты кадра', (tester) async {
      await tester.pumpWidget(
        app(TypeStep(controller: WizardController(repositoryOf(FakeAdapter({})), passengerOrder: true))),
      );
      expect(find.text('Найти водителя для себя'), findsOneWidget);
      expect(find.text('Отправить груз или посылку'), findsOneWidget);
      expect(find.text('Везу пассажиров'), findsNothing);
    });
  });

  group('«Стоимость посадки» 0 ₽ допустима', () {
    WizardController draft() {
      final c = WizardController(repositoryOf(FakeAdapter({})));
      for (var i = 0; i < c.stops.length; i++) {
        c.setStopFromSuggestion(i, GeoSuggestion.fromJson(suggestion('Адрес $i')));
      }
      return c..setPriceFull(1200);
    }

    test('0 — цены готовы; пустое поле — нет', () {
      final c = draft();
      expect(c.priceComplete, isFalse, reason: 'поле не заполнено');
      c.setPriceBoardingMin(0);
      expect(c.priceComplete, isTrue);
    });

    testWidgets('«Далее» активна при 0', (tester) async {
      tallView(tester);
      final c = draft();
      await tester.pumpWidget(app(PriceStep(controller: c)));
      await tester.enterText(
        find.descendant(of: find.byKey(const ValueKey('price-boarding')), matching: find.byType(TextField)),
        '0',
      );
      await tester.pump();
      expect(tester.widget<AppButton>(find.widgetWithText(AppButton, 'Далее')).onPressed, isNotNull);
    });
  });

  group('отклик новой поездкой: тексты окна публикации и итога', () {
    late FakeAdapter adapter;

    WizardController ready(WizardController c) {
      c
        ..setPriceFull(1200)
        ..setPriceBoardingMin(300)
        ..setCar(_car);
      for (final p in c.pricePairs) {
        c.setPairPrice(p.$1, p.$2, 600);
      }
      return c;
    }

    setUp(() {
      adapter = FakeAdapter({
        'POST /trips': (o) => FakeReply(tripJson()),
        'GET /trips/limits': (o) => const FakeReply({'forwardUsed': 1, 'reverseUsed': 0, 'weekUsed': 1, 'weekLimit': 10, 'maxDaysAhead': 3}),
      });
    });

    Future<void> publish(WidgetTester tester, WizardController c) async {
      tallView(tester);
      await tester.pumpWidget(app(BookingModeStep(controller: c)));
      await tester.tap(find.widgetWithText(AppButton, 'Опубликовать поездку'));
      await tester.pumpAndSettle();
    }

    testWidgets('отклик', (tester) async {
      final order = OrderDetails.fromJson(orderDetailsJson(isMine: false));
      await publish(tester, ready(WizardController.fromOrder(repositoryOf(adapter), order)));
      expect(
        find.text('Пассажир заказа сразу получит предложение и сможет оплатить. После этого изменить поездку будет нельзя.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Да, опубликовать'));
      await tester.pumpAndSettle();
      expect(find.text('Отклик отправлен. Пассажир получит предложение'), findsOneWidget);
      expect(find.text('Пассажиры уже видят ваш заказ. Ждём отклик!'), findsNothing);
    });

    testWidgets('обычная поездка — прежние тексты', (tester) async {
      final c = WizardController(repositoryOf(adapter))..addStop();
      for (var i = 0; i < c.stops.length; i++) {
        c.setStopFromSuggestion(i, GeoSuggestion.fromJson(suggestion('Адрес $i')));
      }
      c
        ..setDate(DateTime(2026, 6, 4))
        ..setDepartTime(const TimeOfDay(hour: 8, minute: 0))
        ..setArriveTime(const TimeOfDay(hour: 10, minute: 0))
        ..setSeats(3);
      await publish(tester, ready(c));
      expect(find.textContaining('Изменить поездку можно будет'), findsOneWidget);
      await tester.tap(find.text('Да, опубликовать'));
      await tester.pumpAndSettle();
      expect(find.text('Пассажиры уже видят ваш заказ. Ждём отклик!'), findsOneWidget);
    });
  });
}
