import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/trip_new/moscow_time.dart';
import 'package:the_way/src/features/trip_new/steps/booking_mode_step.dart';
import 'package:the_way/src/features/trip_new/steps/car_step.dart';
import 'package:the_way/src/features/trip_new/steps/datetime_step.dart';
import 'package:the_way/src/features/trip_new/steps/extras_step.dart';
import 'package:the_way/src/features/trip_new/steps/price_step.dart';
import 'package:the_way/src/features/trip_new/wizard_controller.dart';
import 'package:the_way/src/widgets/app_button.dart';
import 'package:the_way/src/widgets/parcel_size_image.dart';
import 'package:the_way/src/widgets/route_fields.dart';

import 'support.dart';

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

WizardController _draft(FakeAdapter adapter, {int stops = 3, TripKind kind = TripKind.ride, DateTime Function()? now}) {
  final c = WizardController(repositoryOf(adapter), now: now ?? DateTime.now)..setKind(kind);
  while (c.stops.length < stops) {
    c.addStop();
  }
  for (var i = 0; i < c.stops.length; i++) {
    c.setStopFromSuggestion(i, GeoSuggestion.fromJson(suggestion('Адрес $i', place: 'Город $i')));
  }
  if (kind == TripKind.ride) c.setSeats(3);
  return c;
}

Finder _field(String key) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<InkWell>(find.widgetWithText(InkWell, label)).onTap != null;

void main() {
  group('PriceStep («Новый заказ - Выбор цены»)', () {
    testWidgets('три остановки: «Весь маршрут», две пары, «Стоимость посадки»; «Далее» — когда всё введено',
        (tester) async {
      tallView(tester);
      final c = _draft(FakeAdapter({}));
      await tester.pumpWidget(app(PriceStep(controller: c)));
      expect(find.text('Шаг 3 из 6'), findsOneWidget);
      expect(find.text('Весь маршрут'), findsOneWidget);
      expect(find.text('Между остановками'), findsOneWidget);
      expect(find.text('Стоимость посадки'), findsOneWidget);
      expect(_field('price-0-1'), findsOneWidget);
      expect(_field('price-1-2'), findsOneWidget);
      expect(_field('price-0-2'), findsNothing, reason: 'цены — только участки соседних точек');
      expect(_enabled(tester, 'Далее'), isFalse);
      await tester.enterText(_field('price-full'), '1200');
      await tester.enterText(_field('price-0-1'), '600');
      await tester.enterText(_field('price-1-2'), '700');
      expect(_enabled(tester, 'Далее'), isFalse, reason: 'нет стоимости посадки');
      await tester.enterText(_field('price-boarding'), '300');
      await tester.pump();
      expect(_enabled(tester, 'Далее'), isTrue);
      expect(c.priceFull, 1200);
      expect(c.pairPrice(0, 1), 600);
      expect(c.pairPrice(1, 2), 700);
      expect(c.priceBoardingMin, 300);
      expect(find.text('Стоимость поездки'), findsOneWidget, reason: 'образец «Экран для отключенной монетизации» — итог без комиссии');
    });

    testWidgets('ошибка цены называет города и у точки из справочника, и у точки сохранённого маршрута',
        (tester) async {
      tallView(tester);
      final c = WizardController(repositoryOf(FakeAdapter({})))..addStop();
      c
        ..setStopFromSuggestion(0, GeoSuggestion.fromJson(suggestion('Ярославль, Победы 1')))
        ..setStopFromCity(1, City.fromJson(cityJson(2, 'Рыбинск')), 'Центральная 5')
        ..stops[2] = WizardStop(address: 'Рынок', cityId: 3, cityName: 'Углич');
      await tester.pumpWidget(app(PriceStep(controller: c)));
      await tester.enterText(_field('price-0-1'), '6000');
      await tester.enterText(_field('price-1-2'), '12000');
      await tester.enterText(_field('price-full'), '1000');
      await tester.pump();
      expect(find.textContaining('участка Рыбинск → Углич (12 000 ₽)'), findsOneWidget);
    });

    testWidgets('«Весь маршрут» и участки: слева значки маршрута, как на шаге точек', (tester) async {
      tallView(tester);
      await tester.pumpWidget(app(PriceStep(controller: _draft(FakeAdapter({}), stops: 4))));
      final routes = tester.widgetList<RouteFields>(find.byType(RouteFields)).toList();
      expect(routes.map((r) => r.points), [
        [RoutePoint.start, RoutePoint.end],
        [RoutePoint.start, RoutePoint.stop],
        [RoutePoint.stop, RoutePoint.stop],
        [RoutePoint.stop, RoutePoint.end],
      ]);
      expect(find.descendant(of: find.byWidget(routes.first), matching: find.text('Адрес 0')), findsOneWidget);
      expect(find.descendant(of: find.byWidget(routes.first), matching: find.text('Адрес 3')), findsOneWidget);
    });

    testWidgets('«Стоимость поездки» на месте с начала; пустая посадка — подсказка; ошибки под полями',
        (tester) async {
      tallView(tester);
      final c = _draft(FakeAdapter({}));
      await tester.pumpWidget(app(PriceStep(controller: c)));
      expect(find.text('Стоимость поездки'), findsOneWidget);
      expect(find.text('0 ₽'), findsOneWidget, reason: 'карточка не появляется с первой цифрой и не сдвигает экран');
      expect(find.text('Укажите стоимость посадки (можно 0)'), findsNothing, reason: 'до ввода цен не ругаемся');

      await tester.enterText(_field('price-full'), '10000');
      await tester.pump();
      expect(tester.widget<TextField>(_field('price-full')).controller!.text, '10 000', reason: 'разряды неразрывным пробелом');
      expect(c.priceFull, 10000);
      expect(find.text('10\u00A0000 ₽'), findsOneWidget);
      expect(find.text('Укажите стоимость посадки (можно 0)'), findsOneWidget);

      await tester.enterText(_field('price-0-1'), '6000');
      await tester.enterText(_field('price-1-2'), '12000');
      await tester.pump();
      expect(
        find.text('Весь маршрут не может стоить меньше участка Город 1 → Город 2 (12\u00A0000 ₽): '
            'пассажир всего маршрута тоже едет через эту точку'),
        findsOneWidget,
        reason: 'в тексте ошибки — города точек, не полные адреса',
      );
      await tester.enterText(_field('price-full'), '19000');
      await tester.pump();
      expect(find.text('Весь маршрут не может стоить больше суммы участков (18\u00A0000 ₽)'), findsOneWidget);
      await tester.enterText(_field('price-full'), '1000000');
      await tester.pump();
      expect(find.text('Не больше 100\u00A0000 ₽'), findsOneWidget);
      await tester.enterText(_field('price-full'), '15000');
      await tester.enterText(_field('price-boarding'), '7000');
      await tester.pump();
      expect(find.text('Не меньше стоимости посадки (7\u00A0000 ₽)'), findsOneWidget);
      expect(_enabled(tester, 'Далее'), isFalse);
      await tester.enterText(_field('price-boarding'), '0');
      await tester.pump();
      expect(find.text('Укажите стоимость посадки (можно 0)'), findsNothing);
      expect(_enabled(tester, 'Далее'), isTrue);
    });

    testWidgets('режим правки: «Изменение стоимости», «Сохранить», закрывается с true', (tester) async {
      tallView(tester);
      final c = WizardController.fromTrip(repositoryOf(FakeAdapter({})), TripDetails.fromJson(tripJson()));
      bool? result;
      await tester.pumpWidget(app(Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(builder: (_) => PriceStep(controller: c, isEdit: true)),
          ),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Изменение стоимости'), findsOneWidget);
      expect(find.textContaining('Шаг'), findsNothing);
      expect(find.text('Далее'), findsNothing);
      expect(_field('price-full').evaluate().isNotEmpty, isTrue);
      expect(tester.widget<TextField>(_field('price-0-1')).controller!.text, '500');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('блоки даты и времени («Новый заказ - Маршрут», «Новый заказ - Заполнение даты», «Новый заказ - Выбор времени»)', () {
    testWidgets('дата — от сегодня до +3 дней по Москве; время выезда — только :00 и :30', (tester) async {
      tallView(tester);
      // «Сейчас» подменён: 22.10.2026 06:00 по Москве — время по умолчанию 8:00 допустимо в любые часы суток.
      final c = _draft(FakeAdapter({}), now: () => DateTime.utc(2026, 10, 22, 3));
      await tester.pumpWidget(app(Scaffold(
        body: ListenableBuilder(listenable: c, builder: (_, _) => DepartureBlock(controller: c)),
      )));
      await tapField(tester, 'Дата');
      await tester.pumpAndSettle();
      final calendar = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
      final today = moscowToday(c.now());
      expect(calendar.firstDate, today);
      expect(calendar.lastDate, DateTime(today.year, today.month, today.day + 3));
      await tester.tap(find.widgetWithText(AppButton, 'Выбрать дату'));
      await tester.pumpAndSettle();
      expect(c.date, today);
      expect(find.text(ruDate(today)), findsOneWidget);

      await tapField(tester, 'Время');
      await tester.pumpAndSettle();
      expect(find.text('30'), findsOneWidget);
      expect(find.text('15'), findsNothing);
      await tester.tap(find.widgetWithText(AppButton, 'Выбрать время'));
      await tester.pumpAndSettle();
      expect(c.departTime, const TimeOfDay(hour: 8, minute: 0));
      expect(find.text('8:00'), findsOneWidget);
    });

    testWidgets('прибытие раньше выезда по часам — под полем «Прибытие 25 октября (на следующий день)»',
        (tester) async {
      tallView(tester);
      final c = _draft(FakeAdapter({}))
        ..setDate(DateTime(2026, 10, 24))
        ..setDepartTime(const TimeOfDay(hour: 8, minute: 0))
        ..setArriveTime(const TimeOfDay(hour: 10, minute: 0));
      await tester.pumpWidget(app(Scaffold(
        body: ListenableBuilder(listenable: c, builder: (_, _) => ArrivalBlock(controller: c)),
      )));
      expect(find.textContaining('на следующий день'), findsNothing);
      c.setArriveTime(const TimeOfDay(hour: 7, minute: 0));
      await tester.pump();
      expect(find.text('Прибытие 25 октября (на следующий день)'), findsOneWidget);
    });

    testWidgets('места: «−» и «+»; у посылки блока «Пассажиры» нет', (tester) async {
      tallView(tester);
      final c = _draft(FakeAdapter({}));
      await tester.pumpWidget(app(Scaffold(
        body: ListenableBuilder(listenable: c, builder: (_, _) => SeatsBlock(controller: c)),
      )));
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.byType(InkWell).last);
      await tester.pump();
      expect(c.seatsTotal, 4);
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      expect(c.seatsTotal, 2);
    });
  });

  group('ExtrasStep («Новый заказ - Выбор доп услуг», «Новый заказ - Выбор веса посылки»)', () {
    testWidgets('услуга: включается с ценой 150, цена правится', (tester) async {
      tallView(tester);
      final c = _draft(FakeAdapter({}));
      await tester.pumpWidget(app(ExtrasStep(controller: c)));
      expect(find.text('Шаг 5 из 6'), findsOneWidget);
      expect(find.text('до 350 ₽'), findsOneWidget);
      await tester.tap(find.text('Детское кресло'));
      await tester.pump();
      expect(c.extras[ExtraKind.childSeat], 150);
      final price = _field('extra-child_seat');
      expect(tester.widget<TextField>(price).controller!.text, '150');
      await tester.enterText(price, '200');
      expect(c.extras[ExtraKind.childSeat], 200);
      await tester.tap(find.text('Детское кресло'));
      await tester.pump();
      expect(c.extras.containsKey(ExtraKind.childSeat), isFalse);
    });

    testWidgets('посылка: размеры с ценами 150/250/350, «Мест для посылок» 3; «Отмена» ничего не меняет',
        (tester) async {
      tallView(tester);
      final c = _draft(FakeAdapter({}));
      await tester.pumpWidget(app(ExtrasStep(controller: c)));
      await tester.tap(find.text('Посылка'));
      await tester.pumpAndSettle();
      // Шторка водителя — его словами, не словами отправителя.
      expect(find.text('Какие посылки возьмёте'), findsOneWidget);
      expect(find.text('Укажите размер вашей посылки'), findsNothing);
      expect(find.text('Мест для посылок'), findsNothing, reason: 'пока нет размеров');
      expect(_enabled(tester, 'Добавить'), isFalse);
      await tester.tap(find.text('Маленькая'));
      await tester.tap(find.text('Большая'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_field('parcel-parcel_s')).controller!.text, '150');
      expect(tester.widget<TextField>(_field('parcel-parcel_l')).controller!.text, '350');
      expect(find.text('Мест для посылок'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(c.hasParcel, isFalse);

      await tester.tap(find.text('Посылка'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Маленькая'));
      await tester.tap(find.text('Большая'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('parcel-parcel_l'), '400');
      await tester.tap(find.text('Без проезда пассажира'));
      await tester.pump();
      await tester.tap(find.text('Добавить'));
      await tester.pumpAndSettle();
      expect(c.extras[ExtraKind.parcelS], 150);
      expect(c.extras[ExtraKind.parcelL], 400);
      expect(c.parcelSeatsTotal, 3);
      expect(c.parcelOnly, isTrue);
      expect(find.text('до 400 ₽'), findsOneWidget);
    });

    testWidgets('маленькая и средняя → размеры S и M, итог «S, M»; «Возьму посылку без пассажира»',
        (tester) async {
      tallView(tester);
      final c = _draft(FakeAdapter({}));
      await tester.pumpWidget(app(ExtrasStep(controller: c)));
      await tester.tap(find.text('Посылка'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Маленькая'));
      await tester.tap(find.text('Средняя'));
      await tester.pumpAndSettle();
      expect(find.text('Возьму посылку без пассажира'), findsOneWidget);
      expect(find.textContaining('Можно отправить'), findsNothing);
      await tester.tap(find.text('Добавить'));
      await tester.pumpAndSettle();
      expect(c.extras.keys.where(isParcelKind), [ExtraKind.parcelS, ExtraKind.parcelM]);
    });

    testWidgets('«Новый заказ - Выбор веса посылки»: в строке размера — одна машина своего размера, как в шторке пассажира «Бронирование - С доп услугами»', (tester) async {
      tallView(tester);
      final c = _draft(FakeAdapter({}));
      await tester.pumpWidget(app(ExtrasStep(controller: c)));
      await tester.tap(find.text('Посылка'));
      await tester.pumpAndSettle();
      final images = tester.widgetList<ParcelSizeImage>(find.byType(ParcelSizeImage)).map((w) => w.size).toList();
      expect(images, [ParcelSize.s, ParcelSize.m, ParcelSize.l]);
    });

    testWidgets('посылка одного размера — его цена без «до» («Новый заказ - Выбор доп услуг»); несколько размеров — «до» наибольшей',
        (tester) async {
      tallView(tester);
      final c = _draft(FakeAdapter({}));
      await tester.pumpWidget(app(ExtrasStep(controller: c)));
      c.setExtra(ExtraKind.parcelS, true);
      await tester.pump();
      expect(find.text('150 ₽'), findsOneWidget);
      expect(find.textContaining('до '), findsNothing);
      c.setExtra(ExtraKind.parcelM, true);
      await tester.pump();
      expect(find.text('до 250 ₽'), findsOneWidget);
    });

    testWidgets('поездка-посылка: услуг для пассажиров нет, «Далее» — после выбора размера', (tester) async {
      tallView(tester);
      final c = _draft(FakeAdapter({}), kind: TripKind.parcel);
      await tester.pumpWidget(app(ExtrasStep(controller: c)));
      expect(find.text('Детское кресло'), findsNothing);
      expect(_enabled(tester, 'Далее'), isFalse);
      c.setExtra(ExtraKind.parcelM, true);
      await tester.pump();
      expect(_enabled(tester, 'Далее'), isTrue);
    });
  });

  group('CarStep («Новый заказ - Выбор авто - нет авто» – «Новый заказ - Выбор авто - выбрано авто»)', () {
    testWidgets('нет авто — тексты «Новый заказ - Выбор авто - нет авто» и «Добавить авто»', (tester) async {
      tallView(tester);
      final c = _draft(FakeAdapter({'GET /cars': (o) => const FakeReply([])}));
      await tester.pumpWidget(app(CarStep(controller: c)));
      await tester.pumpAndSettle();
      expect(find.text('Нет добавленных авто'), findsOneWidget);
      expect(find.text('Добавить авто'), findsOneWidget);
      expect(_enabled(tester, 'Далее'), isFalse);
    });

    testWidgets('авто с местами меньше, чем в поездке, неактивно с подписью', (tester) async {
      tallView(tester);
      final c = _draft(FakeAdapter({
        'GET /cars': (o) => FakeReply([carJson(id: 'small', seats: 2), carJson(id: 'big', seats: 4)]),
      }));
      await tester.pumpWidget(app(CarStep(controller: c)));
      await tester.pumpAndSettle();
      expect(find.text('Мест в авто меньше, чем в поездке'), findsOneWidget);
      expect(find.text('4 места'), findsOneWidget);
      await tester.tap(find.text('Мест в авто меньше, чем в поездке'));
      await tester.pump();
      expect(c.carId, isNull);
      await tester.tap(find.text('4 места'));
      await tester.pump();
      expect(c.carId, 'big');
      expect(_enabled(tester, 'Далее'), isTrue);
    });
  });

  group('публикация («Новый заказ - Выбор доп услуг» – «Новый заказ - Маршрут сохранен», «Новый заказ - Заказ создан»)', () {
    late FakeAdapter adapter;
    late WizardController c;

    setUp(() {
      adapter = FakeAdapter({
        'POST /trips': (o) => FakeReply(tripJson()),
        'GET /trips/limits': (o) => const FakeReply({'forwardUsed': 1, 'reverseUsed': 0, 'weekUsed': 1, 'weekLimit': 10, 'maxDaysAhead': 3}),
        'POST /route-templates': (o) => const FakeReply({'id': 't', 'stops': <Object?>[]}),
      });
      c = _draft(adapter)
        ..setDate(DateTime(2026, 6, 4))
        ..setDepartTime(const TimeOfDay(hour: 8, minute: 0))
        ..setArriveTime(const TimeOfDay(hour: 10, minute: 0))
        ..setPriceFull(1200)
        ..setPriceBoardingMin(300)
        ..setCar(_car);
      for (final p in c.pricePairs) {
        c.setPairPrice(p.$1, p.$2, 600);
      }
    });

    testWidgets('«Опубликовать» → окно с итогом → POST /trips → «Заказ опубликован!» и шкалы лимита',
        (tester) async {
      tallView(tester);
      await tester.pumpWidget(app(BookingModeStep(controller: c)));
      expect(find.text('Шаг 6 из 6'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Опубликовать поездку'));
      await tester.pumpAndSettle();
      expect(find.text('Опубликовать поездку?'), findsOneWidget);
      expect(find.text('04.06.2026, 8:00'), findsOneWidget);
      expect(find.text('Прибытие'), findsOneWidget);
      expect(find.text('04.06.2026, 10:00 · в пути 2 ч'), findsOneWidget);
      expect(find.text('Мест для пассажиров'), findsOneWidget, reason: 'места пассажиров — своей строкой');
      expect(find.text('1\u00A0200 ₽'), findsOneWidget);
      await tester.tap(find.text('Да, опубликовать'));
      await tester.pumpAndSettle();
      final body = adapter.callsTo('POST /trips').single.data as Map<String, dynamic>;
      expect(body['kind'], 'ride');
      expect(body['seatsTotal'], 3);
      expect(body['departsAt'], '2026-06-04T05:00:00.000Z');
      expect(body['bookingMode'], 'standard');
      expect(find.text('Заказ опубликован!'), findsOneWidget);
      expect(find.text('Добавить обратный маршрут'), findsOneWidget);
      expect(find.text('Смотреть мои заказы'), findsOneWidget);
      expect(find.text('Туда'), findsOneWidget);
      expect(find.text('1/1'), findsOneWidget);
      expect(find.text('0/1'), findsOneWidget);
    });

    testWidgets('итог: прибытие на следующий день — дата прибытия и «в пути 23 ч»; посылки — без мест пассажиров',
        (tester) async {
      tallView(tester);
      c
        ..setArriveTime(const TimeOfDay(hour: 7, minute: 0))
        ..setExtra(ExtraKind.parcelS, true)
        ..setExtra(ExtraKind.parcelM, true);
      await tester.pumpWidget(app(BookingModeStep(controller: c)));
      await tester.tap(find.widgetWithText(AppButton, 'Опубликовать поездку'));
      await tester.pumpAndSettle();
      expect(find.text('05.06.2026, 7:00 · в пути 23 ч'), findsOneWidget);
      expect(find.text('S, M · мест для посылок 3'), findsOneWidget);
    });

    testWidgets('limit_reached: окно «Новый заказ - Маршрут сохранен» со шкалами; «Сохранить как шаблон» → POST /route-templates → driver_trips',
        (tester) async {
      tallView(tester);
      adapter.routes['POST /trips'] = (o) => const FakeReply({'code': 'limit_reached', 'message': 'x'}, 409);
      adapter.routes['GET /trips/limits'] = (o) => const FakeReply({'forwardUsed': 1, 'reverseUsed': 1, 'weekUsed': 2, 'weekLimit': 10, 'maxDaysAhead': 3});
      await tester.pumpWidget(app(BookingModeStep(controller: c)));
      await tester.tap(find.widgetWithText(AppButton, 'Опубликовать поездку'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Да, опубликовать'));
      await tester.pumpAndSettle();
      expect(find.text('Достигнут лимит на сегодня'), findsOneWidget);
      expect(find.textContaining('Сегодня у вас уже 2 публикации'), findsOneWidget);
      // Лимит — на водителя, есть автобусы и недельный: без «На легковой автомобиль».
      expect(
        find.text('Можно опубликовать не более 1 поездки в сутки в каждом направлении и не более 10 в неделю. '
            'Сегодня у вас уже 2 публикации.'),
        findsOneWidget,
      );
      expect(find.textContaining('На легковой автомобиль'), findsNothing);
      expect(find.text('Обратно'), findsOneWidget);
      await tester.tap(find.text('Сохранить как шаблон'));
      await tester.pumpAndSettle();
      expect(adapter.callsTo('POST /route-templates'), hasLength(1));
      expect(find.text('route:shell'), findsOneWidget);
    });

    testWidgets('limit_reached при выбранной неделе — «Достигнут лимит на неделю», шкалы недели', (tester) async {
      tallView(tester);
      adapter.routes['POST /trips'] = (o) => const FakeReply({'code': 'limit_reached', 'message': 'x'}, 409);
      adapter.routes['GET /trips/limits'] =
          (o) => const FakeReply({'forwardUsed': 0, 'reverseUsed': 0, 'weekUsed': 10, 'weekLimit': 10, 'maxDaysAhead': 3});
      await tester.pumpWidget(app(BookingModeStep(controller: c)));
      await tester.tap(find.widgetWithText(AppButton, 'Опубликовать поездку'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Да, опубликовать'));
      await tester.pumpAndSettle();
      expect(find.text('Достигнут лимит на неделю'), findsOneWidget);
      expect(find.text('Следующая публикация — с понедельника'), findsOneWidget);
      expect(find.text('10/10'), findsOneWidget);
      // Выезд 4 июня, а не сегодня: суточная шкала подписана днём выезда.
      expect(find.text('4 июня'), findsOneWidget);
      expect(find.text('Сегодня'), findsNothing);
      expect(find.text('Достигнут лимит на сегодня'), findsNothing);
    });

    testWidgets('limit_reached → «Отмена» → driver_trips', (tester) async {
      tallView(tester);
      adapter.routes['POST /trips'] = (o) => const FakeReply({'code': 'limit_reached', 'message': 'x'}, 409);
      await tester.pumpWidget(app(BookingModeStep(controller: c)));
      await tester.tap(find.widgetWithText(AppButton, 'Опубликовать поездку'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Да, опубликовать'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Отмена'));
      await tester.pumpAndSettle();
      expect(adapter.callsTo('POST /route-templates'), isEmpty);
      expect(find.text('route:shell'), findsOneWidget);
    });

    testWidgets('коды too_far_ahead, invalid_time_step — снэкбар с текстом по коду; blocked — подсказки нет',
        (tester) async {
      tallView(tester);
      const cases = {
        'too_far_ahead': 'Поездку можно опубликовать не дальше чем на 3 дня вперёд',
        'invalid_time_step': 'Время выезда должно быть кратно 30 минутам',
        'blocked': null, // отказ показывает экран блокировки (перехватчик http.dart), своей подсказки нет
      };
      for (final entry in cases.entries) {
        adapter.routes['POST /trips'] = (o) => FakeReply({'code': entry.key, 'message': 'x'}, entry.key == 'blocked' ? 403 : 400);
        await tester.pumpWidget(app(BookingModeStep(controller: c)));
        await tester.tap(find.widgetWithText(AppButton, 'Опубликовать поездку'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Да, опубликовать'));
        await tester.pumpAndSettle();
        if (entry.value != null) {
          expect(find.text(entry.value!), findsOneWidget, reason: entry.key);
        } else {
          expect(find.byType(SnackBar), findsNothing, reason: entry.key);
        }
        expect(find.text('Опубликовать поездку?'), findsNothing, reason: 'окно закрыто');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('«Сохранить шаблон» шлёт остановки черновика и показывает «Шаблон сохранён»', (tester) async {
      tallView(tester);
      await tester.pumpWidget(app(BookingModeStep(controller: c)));
      await tester.tap(find.widgetWithText(AppButton, 'Сохранить шаблон'));
      await tester.pumpAndSettle();
      final body = adapter.callsTo('POST /route-templates').single.data as Map<String, dynamic>;
      expect((body['stops'] as List), hasLength(3));
      expect(find.text('Шаблон сохранён'), findsOneWidget);
    });
  });
}
