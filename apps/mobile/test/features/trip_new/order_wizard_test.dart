import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/trip_new/steps/extras_step.dart';
import 'package:the_way/src/features/trip_new/steps/route_step.dart';
import 'package:the_way/src/features/trip_new/steps/type_step.dart';
import 'package:the_way/src/features/trip_new/wizard_controller.dart';
import 'package:the_way/src/widgets/app_button.dart';
import 'package:the_way/src/widgets/app_input.dart';
import 'package:the_way/src/widgets/app_switch.dart';

import '../../screens/shot.dart';
import '../../screens/world.dart' show ShotWorld;
import '../passenger_trips/order_support.dart';
import 'support.dart';

/// Мастер заказа пассажира (план `passenger-order_2026-10-22.md`, шаг Б2.1): тип → маршрут → услуги,
/// «Шаг N из 3», без цены и авто; публикация — `POST /orders`.
WizardController _order(FakeAdapter adapter, {TripKind kind = TripKind.ride}) {
  final c = WizardController(repositoryOf(adapter), passengerOrder: true)..setKind(kind);
  c.addStop();
  for (var i = 0; i < c.stops.length; i++) {
    c.setStopFromSuggestion(i, GeoSuggestion.fromJson(suggestion('Адрес $i')));
  }
  c
    ..setDate(DateTime(2026, 6, 4))
    ..setDepartTime(const TimeOfDay(hour: 8, minute: 0))
    ..setArriveTime(const TimeOfDay(hour: 10, minute: 0));
  if (kind == TripKind.ride) c.setSeats(2);
  return c;
}

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, label)).onPressed != null;

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(AppButton, 'Далее'));
  await tester.pumpAndSettle();
}

void main() {
  shotInit();

  group('порядок шагов заказа', () {
    testWidgets('тип (Шаг 1 из 3) → маршрут (2 из 3, без шаблонов) → услуги (3 из 3, без цен) → «Опубликовать заказ»',
        (tester) async {
      tallView(tester);
      final adapter = FakeAdapter({
        'GET /route-templates': (o) => const FakeReply([
              {'id': 't1', 'stops': <Object?>[]},
            ]),
      });
      final c = _order(adapter);
      await tester.pumpWidget(app(TypeStep(controller: c)));
      expect(find.text('Шаг 1 из 3'), findsOneWidget);
      expect(find.text('Автомобиль'), findsOneWidget);
      expect(find.text('Найти водителя для себя'), findsOneWidget);
      await _next(tester);

      expect(find.byType(RouteStep), findsOneWidget);
      expect(find.text('Шаг 2 из 3'), findsOneWidget);
      expect(find.text('Примерное время прибытия'), findsOneWidget, reason: 'в мастере заказа есть примерное время прибытия');
      expect(find.text('Количество мест:'), findsOneWidget);
      expect(find.text('Мои сохранённые маршруты'), findsNothing, reason: 'в кадрах «Новый заказ - Маршрут», «Новый заказ - кол-во пассажиров» шаблонов нет');
      expect(adapter.callsTo('GET /route-templates'), isEmpty);
      await _next(tester);

      expect(find.byType(ExtrasStep), findsOneWidget);
      expect(find.text('Шаг 3 из 3'), findsOneWidget);
      for (final t in ['Детское кресло', 'Багаж', 'Животные', 'Посылка']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      await tester.tap(find.byType(AppSwitch).first);
      await tester.pump();
      expect(find.byType(AppInput), findsNothing, reason: 'у заказа цен нет — полей цены под услугой нет');
      expect(find.textContaining('₽'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Опубликовать заказ'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Далее'), findsNothing);
    });

    testWidgets('мест — не больше 8', (tester) async {
      tallView(tester);
      final c = _order(FakeAdapter({}))..setSeats(8);
      await tester.pumpWidget(app(RouteStep(controller: c)));
      await tester.tap(find.byKey(const Key('seats_plus')));
      await tester.pump();
      expect(c.seatsTotal, 8);
    });

    testWidgets('посылка: блока мест нет, на шаге услуг только «Посылка»; без размера публиковать нельзя', (tester) async {
      tallView(tester);
      final c = _order(FakeAdapter({}), kind: TripKind.parcel);
      await tester.pumpWidget(app(RouteStep(controller: c)));
      expect(find.text('Количество мест:'), findsNothing);
      await _next(tester);
      expect(find.text('Детское кресло'), findsNothing);
      expect(find.text('Посылка'), findsOneWidget);
      expect(_enabled(tester, 'Опубликовать заказ'), isFalse);
    });
  });

  group('публикация заказа', () {
    late FakeAdapter adapter;

    setUp(() {
      adapter = FakeAdapter({'POST /orders': (o) => FakeReply(orderDetailsJson())});
    });

    testWidgets('окно «Опубликовать заказ?» без цены и авто → POST /orders с введённым → «Заказ опубликован!»',
        (tester) async {
      tallView(tester);
      final c = _order(adapter)..setExtra(ExtraKind.childSeat, true);
      await tester.pumpWidget(app(ExtrasStep(controller: c)));
      await tester.tap(find.widgetWithText(AppButton, 'Опубликовать заказ'));
      await tester.pumpAndSettle();
      expect(find.text('Опубликовать заказ?'), findsOneWidget);
      expect(find.text('После публикации водители увидят заказ и смогут откликнуться'), findsOneWidget);
      expect(find.text('04.06.2026, 8:00'), findsOneWidget);
      expect(find.text('Количество мест'), findsOneWidget);
      expect(find.text('Стоимость поездки'), findsNothing);
      expect(find.text('Автомобиль'), findsNothing);
      expect(find.text('Тип бронирования'), findsNothing);
      await tester.tap(find.text('Да, опубликовать'));
      await tester.pumpAndSettle();

      final body = adapter.callsTo('POST /orders').single.data as Map<String, dynamic>;
      expect(body['kind'], 'ride');
      expect(body['seats'], 2);
      expect((body['stops'] as List), hasLength(3));
      expect(body['departsAt'], '2026-06-04T05:00:00.000Z');
      expect(body['arrivesAt'], '2026-06-04T07:00:00.000Z');
      expect(body['parcelSize'], 'none');
      expect(body['parcelComment'], isNull);
      expect(body['extras'], ['child_seat']);

      expect(find.text('Заказ опубликован!'), findsOneWidget);
      expect(find.text('Водители уже видят ваш заказ. Ждём отклик!'), findsOneWidget);
      expect(find.text('Добавить обратный маршрут'), findsNothing);
      expect(find.text('Лимит публикаций'), findsNothing);
      await tester.tap(find.text('Смотреть мои заказы'));
      await tester.pumpAndSettle();
      expect(find.text('route:shell'), findsOneWidget);
    });

    testWidgets('посылка: шторка размера — один размер, комментарий; тело seats 0, размер и комментарий',
        (tester) async {
      tallView(tester);
      final c = _order(adapter, kind: TripKind.parcel);
      await tester.pumpWidget(app(ExtrasStep(controller: c)));
      await tester.tap(find.text('Посылка'));
      await tester.pumpAndSettle();
      expect(find.text('Укажите размер вашей посылки'), findsOneWidget);
      expect(find.textContaining('₽'), findsNothing, reason: 'цен у заказа нет');
      expect(find.text('Без проезда пассажира'), findsNothing);
      await tester.tap(find.text('Маленькая'));
      await tester.tap(find.text('Средняя'));
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Добавить'));
      await tester.pumpAndSettle();
      expect(c.orderParcel, ParcelSize.m, reason: 'один размер — последний выбранный');
      await tester.enterText(find.byKey(const Key('order_parcel_comment')), 'Документы');
      await tester.pump();
      expect(_enabled(tester, 'Опубликовать заказ'), isTrue);
      await tester.tap(find.widgetWithText(AppButton, 'Опубликовать заказ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Да, опубликовать'));
      await tester.pumpAndSettle();
      final body = adapter.callsTo('POST /orders').single.data as Map<String, dynamic>;
      expect(body['kind'], 'parcel');
      expect(body['seats'], 0);
      expect(body['parcelSize'], 'M');
      expect(body['parcelComment'], 'Документы');
      expect(body['extras'], isEmpty);
    });

    testWidgets('ошибки — текст по коду; blocked — подсказки нет (экран блокировки открывает перехватчик)',
        (tester) async {
      tallView(tester);
      const cases = {
        'too_far_ahead': 'Заказ можно опубликовать не дальше чем на 3 дня вперёд',
        'invalid_time_step': 'Время выезда должно быть кратно 30 минутам',
        'validation': 'Проверьте данные заказа',
        'blocked': null,
        'internal': 'Не удалось выполнить действие. Попробуйте ещё раз',
      };
      for (final entry in cases.entries) {
        adapter.routes['POST /orders'] =
            (o) => FakeReply({'code': entry.key, 'message': 'x'}, entry.key == 'blocked' ? 403 : 400);
        await tester.pumpWidget(app(ExtrasStep(controller: _order(adapter))));
        await tester.tap(find.widgetWithText(AppButton, 'Опубликовать заказ'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Да, опубликовать'));
        await tester.pumpAndSettle();
        if (entry.value != null) {
          expect(find.text(entry.value!), findsOneWidget, reason: entry.key);
        } else {
          expect(find.byType(SnackBar), findsNothing, reason: entry.key);
        }
        expect(find.text('Опубликовать заказ?'), findsNothing, reason: 'окно закрыто');
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('«+» нижней панели', () {

    testWidgets('у пассажира — мастер заказа', (tester) async {
      shotSurface(tester);
      final world = ShotWorld();
      await world.open(tester);
      await world.tap(tester, find.byKey(const Key('tab_create')));
      expect(find.byType(TypeStep), findsOneWidget);
      expect(find.text('Шаг 1 из 3'), findsOneWidget);
      expect(find.text('Создавать поездки можно в режиме водителя'), findsNothing);
      debugDisableShadows = true;
    });

    testWidgets('у водителя — мастер поездки', (tester) async {
      shotSurface(tester);
      final world = ShotWorld(mode: UserMode.driver);
      await world.open(tester);
      await world.tap(tester, find.byKey(const Key('tab_create')));
      expect(find.byType(TypeStep), findsOneWidget);
      expect(find.text('Шаг 1 из 6'), findsOneWidget);
      debugDisableShadows = true;
    });
  });
}
