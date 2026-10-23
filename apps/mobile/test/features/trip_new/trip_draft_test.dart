import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/l10n/app_localizations.dart';
import 'package:the_way/src/features/trip_new/moscow_time.dart';
import 'package:the_way/src/features/trip_new/steps/publish_dialog.dart';
import 'package:the_way/src/features/trip_new/wizard_controller.dart';

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

WizardController _ready({TripKind kind = TripKind.ride, int stops = 3}) {
  final c = WizardController(repositoryOf(FakeAdapter({})))..setKind(kind);
  while (c.stops.length < stops) {
    c.addStop();
  }
  for (var i = 0; i < c.stops.length; i++) {
    c.setStopFromSuggestion(i, GeoSuggestion.fromJson(suggestion('Адрес $i')));
  }
  c
    ..setDate(DateTime(2026, 6, 4))
    ..setDepartTime(const TimeOfDay(hour: 8, minute: 0))
    ..setArriveTime(const TimeOfDay(hour: 10, minute: 0))
    ..setPriceFull(1200)
    ..setPriceBoardingMin(300)
    ..setCar(_car);
  if (kind == TripKind.ride) c.setSeats(3);
  for (final p in c.pricePairs) {
    c.setPairPrice(p.$1, p.$2, 600);
  }
  return c;
}

void main() {
  group('время в поясе Москвы', () {
    test('08:00 по Москве — это 05:00 UTC', () {
      final at = fromMoscow(DateTime(2026, 6, 4), const TimeOfDay(hour: 8, minute: 0));
      expect(at, DateTime.utc(2026, 6, 4, 5));
    });

    test('прибытие позже отправления — в тот же день', () {
      final at = arrivalFrom(DateTime(2026, 6, 4), const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 10, minute: 30));
      expect(at, DateTime.utc(2026, 6, 4, 7, 30));
    });

    test('прибытие не позже отправления — на следующие сутки', () {
      final same = arrivalFrom(DateTime(2026, 6, 4), const TimeOfDay(hour: 22, minute: 0), const TimeOfDay(hour: 22, minute: 0));
      final earlier = arrivalFrom(DateTime(2026, 6, 4), const TimeOfDay(hour: 22, minute: 0), const TimeOfDay(hour: 1, minute: 15));
      expect(same, DateTime.utc(2026, 6, 5, 19));
      expect(earlier, DateTime.utc(2026, 6, 4, 22, 15));
    });

    test('сегодня по Москве в полночь UTC уже следующий день', () {
      expect(moscowToday(DateTime.utc(2026, 6, 4, 21, 30)), DateTime(2026, 6, 5));
      expect(moscowToday(DateTime.utc(2026, 6, 4, 20, 59)), DateTime(2026, 6, 4));
    });

    test('toMoscow обратен fromMoscow', () {
      final (date, time) = toMoscow(DateTime.utc(2026, 6, 4, 5));
      expect(date, DateTime(2026, 6, 4));
      expect(time, const TimeOfDay(hour: 8, minute: 0));
    });
  });

  group('цены (Правила поездки и цены)', () {
    test('пары цен — участки соседних точек', () {
      final c = WizardController(repositoryOf(FakeAdapter({})))
        ..addStop()
        ..addStop()
        ..addStop();
      expect(c.pricePairs, [(0, 1), (1, 2), (2, 3), (3, 4)]);
    });

    test('при двух остановках пар нет', () {
      final c = WizardController(repositoryOf(FakeAdapter({})));
      expect(c.pricePairs, isEmpty);
    });

    test('цены готовы, только когда введены все пары, «весь маршрут» и посадка', () {
      final c = _ready();
      expect(c.priceComplete, isTrue);
      c.setPairPrice(1, 2, null);
      expect(c.priceComplete, isFalse);
    });

    test('весь маршрут дешевле самого дорогого участка — ошибка у «Весь маршрут» с этим участком', () {
      final c = _ready(stops: 4)
        ..setPairPrice(1, 2, 700)
        ..setPriceFull(650);
      expect(c.fullPriceIssue, const FullBelowLeg(1, 2, 700));
      expect(c.priceComplete, isFalse);
      c.setPriceFull(700);
      expect(c.fullPriceIssue, isNull, reason: 'ровно как самый дорогой участок — можно');
      expect(c.priceComplete, isTrue);
    });

    test('весь маршрут дороже суммы участков — ошибка; ровно сумма — можно', () {
      final c = _ready()..setPriceFull(1201);
      expect(c.fullPriceIssue, const FullAboveSum(1200));
      expect(c.priceComplete, isFalse);
      c.setPriceFull(1200);
      expect(c.fullPriceIssue, isNull);
    });

    test('участок и весь маршрут не дешевле посадки; любая цена не больше 100 000', () {
      final c = _ready()..setPairPrice(0, 1, 200);
      expect(c.legPriceIssue(0), const PriceBelowBoarding(300));
      expect(c.legPriceIssue(1), isNull);
      expect(c.priceComplete, isFalse);
      c
        ..setPairPrice(0, 1, 600)
        ..setPriceBoardingMin(1300);
      expect(c.fullPriceIssue, const PriceBelowBoarding(1300));
      c
        ..setPriceBoardingMin(300)
        ..setPairPrice(0, 1, 100001);
      expect(c.legPriceIssue(0), const PriceTooHigh());
      expect(c.priceComplete, isFalse);
    });

    test('итог обратной поездки: участки исходной в обратном порядке', () {
      final json = tripJson();
      final stops = (json['stops']! as List).cast<Map<String, Object?>>();
      json['stops'] = [
        stops[0],
        stops[1],
        {...stops[1], 'idx': 2, 'cityId': 9, 'cityName': 'Мышкин', 'address': 'Площадь', 'shortAddress': 'Площадь'},
        {...stops[2], 'idx': 3},
      ];
      json['prices'] = [
        {'fromIdx': 0, 'toIdx': 1, 'price': 500},
        {'fromIdx': 1, 'toIdx': 2, 'price': 300},
        {'fromIdx': 2, 'toIdx': 3, 'price': 700},
      ];
      final summary = PublishSummary.fromTrip(
        lookupAppLocalizations(const Locale('ru')),
        TripDetails.fromJson(json),
        date: DateTime(2026, 6, 5),
        departTime: const TimeOfDay(hour: 9, minute: 0),
      );
      expect(summary.segments.map((s) => s.$2), [700, 300, 500]);
    });

    test('пустая посадка при введённой цене маршрута — подсказка «можно 0»', () {
      final c = _ready()..setPriceBoardingMin(null);
      expect(c.boardingPriceIssue, const BoardingEmpty());
      expect(c.priceComplete, isFalse);
      c.setPriceBoardingMin(0);
      expect(c.boardingPriceIssue, isNull);
      expect(c.priceComplete, isTrue);
    });
  });

  group('TripInput из черновика', () {
    test('поездка с пассажирами: места, цены пар, услуга с ценой', () {
      final c = _ready()
        ..setExtra(ExtraKind.pets, true)
        ..setBookingMode(BookingMode.instant);
      final input = c.toInput();
      expect(input.kind, TripKind.ride);
      expect(input.seatsTotal, 3);
      expect(input.departsAt, DateTime.utc(2026, 6, 4, 5));
      expect(input.arrivesAt, DateTime.utc(2026, 6, 4, 7));
      expect(input.prices.map((p) => (p.fromIdx, p.toIdx, p.price)), [(0, 1, 600), (1, 2, 600)]);
      expect(input.extras.map((e) => (e.kind, e.price)), [(ExtraKind.pets, 150)]);
      expect(input.parcelSeatsTotal, 0);
      expect(input.parcelOnlyAllowed, isFalse);
      expect(input.bookingMode, BookingMode.instant);
    });

    test('посылка: мест нет, только посылка разрешена, размеры с ценами 150/250/350', () {
      final c = _ready(kind: TripKind.parcel)
        ..setExtra(ExtraKind.parcelS, true)
        ..setExtra(ExtraKind.parcelL, true);
      final input = c.toInput();
      expect(input.seatsTotal, 0);
      expect(input.parcelOnlyAllowed, isTrue);
      expect(input.parcelSeatsTotal, 3);
      expect(input.extras.map((e) => (e.kind, e.price)), [(ExtraKind.parcelS, 150), (ExtraKind.parcelL, 350)]);
      expect(c.routeStepComplete, isTrue, reason: 'места посылке не нужны');
    });

    test('тип поездки — по выбранному авто: легковой → car, автобус → bus', () {
      final c = _ready();
      expect(c.toInput().vehicleKind, VehicleKind.car);
      c.setCar(const Car(
        id: 'bus1',
        brand: 'Ford',
        model: 'Transit',
        kind: VehicleKind.bus,
        seats: 24,
        plate: 'Р824РР76',
        status: CarStatus.verified,
        documents: [],
      ));
      expect(c.toInput().vehicleKind, VehicleKind.bus);
      expect(c.toPatch().vehicleKind, VehicleKind.bus);
    });

    test('места для посылок — 0 без размеров', () {
      final c = _ready()..setParcelSeats(5);
      expect(c.toInput().parcelSeatsTotal, 0);
    });

    test('поездка-посылка без размера не готова к шагу «Далее»', () {
      final c = _ready(kind: TripKind.parcel);
      expect(c.extrasComplete, isFalse);
      c.setExtra(ExtraKind.parcelM, true);
      expect(c.extrasComplete, isTrue);
    });

    test('поездка с пассажирами требует хотя бы одно место', () {
      final c = _ready()..setSeats(0);
      expect(c.routeStepComplete, isFalse);
    });
  });

  test('из поездки: остановки, время по Москве, цены пар, услуги', () {
    final c = WizardController.fromTrip(repositoryOf(FakeAdapter({})), TripDetails.fromJson(tripJson()));
    expect(c.stops.map((s) => s.cityId), [1, 2, 3]);
    expect(c.date, DateTime(2026, 6, 4));
    expect(c.departTime, const TimeOfDay(hour: 8, minute: 0));
    expect(c.arriveTime, const TimeOfDay(hour: 10, minute: 0));
    expect(c.pairPrice(0, 1), 500);
    expect(c.pairPrice(1, 2), 700);
    expect(c.extras, {ExtraKind.pets: 150});
    expect(c.priceComplete, isTrue);
    expect(c.readyToPublish, isTrue);
    final patch = c.toPatch();
    expect(patch.departsAt, DateTime.utc(2026, 6, 4, 5));
    expect(patch.stops.map((s) => s.cityId), [1, 2, 3]);
  });
}
