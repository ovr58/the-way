import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../widgets/trip_card_view.dart';
import 'data/trip_new_repository.dart';
import 'moscow_time.dart';

/// Точка маршрута черновика: адрес и ровно одно из `place` (подсказка Mapbox) или `cityId`
/// (город из списка).
class WizardStop {
  WizardStop({this.address = '', this.shortAddress, this.cityId, this.cityName = '', this.place, this.lat, this.lng});

  /// Остановка сохранённой поездки или шаблона: адрес хранится как пришёл (пустой — пустой),
  /// иначе правка поездки молча переписала бы его названием города; название — в [displayAddress].
  factory WizardStop.fromStop(Stop s) => WizardStop(
        address: s.address,
        shortAddress: s.shortAddress,
        cityId: s.cityId,
        cityName: s.cityName,
        lat: s.lat,
        lng: s.lng,
      );

  String address;

  /// Короткий адрес для карточки поездки — `GeoSuggestion.shortLabel` (PN-2); собирает сервер.
  String? shortAddress;

  /// Название города остановки из сохранённой поездки или шаблона (для показа при пустом адресе).
  String cityName;
  int? cityId;

  /// Название города, выбранного из справочника («Выбрать город из списка»): в адрес не входит (адрес остаётся
  /// введённой строкой и уходит на сервер как есть), нужен для показа «Город, текст» и текстов вроде ошибки цены.
  String pickedCity = '';
  Place? place;
  num? lat;
  num? lng;

  /// Что показать в поле и на экранах: «Город, адрес» без задвоения, а при пустом адресе — город.
  /// Город известен у остановки сохранённой поездки или шаблона и у точки из списка городов; у ввода
  /// и подсказки он уже в адресе.
  String get displayAddress => withCity(cityName.isNotEmpty ? cityName : pickedCity, address);

  /// Город точки для текстов: из подсказки, из справочника или из сохранённой поездки — не полный адрес.
  String get city => place?.name ?? (pickedCity.isNotEmpty ? pickedCity : cityName);

  /// Населённый пункт определён: есть `place` или `cityId`.
  bool get isSet => place != null || cityId != null;

  StopInput toInput() => place != null
      ? StopInput(address: address, shortAddress: shortAddress, place: place, lat: lat, lng: lng)
      : StopInput(address: address, shortAddress: shortAddress, cityId: cityId, lat: lat, lng: lng);

  /// Ключ точки для сравнения маршрута с исходным (правка поездки).
  String get signature => '${cityId ?? place?.name}|$address';
}

/// Цены по умолчанию из макета: услуги 150, посылка S/M/L — 150/250/350.
int defaultExtraPrice(ExtraKind kind) => switch (kind) {
      ExtraKind.parcelM => 250,
      ExtraKind.parcelL => 350,
      _ => 150,
    };

/// Верхняя граница любой цены поездки, ₽ (`PRICE_MAX` сервера).
const priceMax = 100000;

/// Нарушение правила цен у поля шага цен; текст собирает экран. Те же правила проверяет
/// сервер (`trip-validation.ts`, `checkPrices`).
sealed class PriceIssue {
  const PriceIssue();
}

/// Цена больше [priceMax].
final class PriceTooHigh extends PriceIssue {
  const PriceTooHigh();
  @override
  bool operator ==(Object other) => other is PriceTooHigh;
  @override
  int get hashCode => 0;
}

/// Цена ниже стоимости посадки [boarding].
final class PriceBelowBoarding extends PriceIssue {
  const PriceBelowBoarding(this.boarding);
  final int boarding;
  @override
  bool operator ==(Object other) => other is PriceBelowBoarding && other.boarding == boarding;
  @override
  int get hashCode => boarding.hashCode;
}

/// «Весь маршрут» дешевле самого дорогого участка [from] → [to] ценой [price].
final class FullBelowLeg extends PriceIssue {
  const FullBelowLeg(this.from, this.to, this.price);
  final int from;
  final int to;
  final int price;
  @override
  bool operator ==(Object other) => other is FullBelowLeg && other.from == from && other.to == to && other.price == price;
  @override
  int get hashCode => Object.hash(from, to, price);
}

/// «Весь маршрут» дороже суммы участков [sum].
final class FullAboveSum extends PriceIssue {
  const FullAboveSum(this.sum);
  final int sum;
  @override
  bool operator ==(Object other) => other is FullAboveSum && other.sum == sum;
  @override
  int get hashCode => sum.hashCode;
}

/// Стоимость посадки не введена, а цены уже вводятся.
final class BoardingEmpty extends PriceIssue {
  const BoardingEmpty();
  @override
  bool operator ==(Object other) => other is BoardingEmpty;
  @override
  int get hashCode => 1;
}

/// Вместимость легкового авто — наибольшее число мест заказа пассажира (`CAR_SEATS_MAX` сервера).
const orderSeatsMax = 8;

/// Услуги: вид цены поездки и вид услуги заказа.
const serviceKinds = [
  (ExtraKind.childSeat, ServiceKind.childSeat),
  (ExtraKind.luggage, ServiceKind.luggage),
  (ExtraKind.pets, ServiceKind.pets),
];

const parcelKinds =[ExtraKind.parcelS, ExtraKind.parcelM, ExtraKind.parcelL];

bool isParcelKind(ExtraKind kind) => parcelKinds.contains(kind);

/// Черновик поездки, общий для шагов мастера, обратной поездки и правки: один держатель
/// `TripInput`. Правил поездки здесь нет — шаг, лимит и три дня влияют только на то, что
/// предлагает экран; решает сервер.
class WizardController extends ChangeNotifier {
  WizardController(this.repository, {this.homeCityId, this.now = DateTime.now, this.passengerOrder = false});

  /// Из поездки — для правки (`GET /trips/{id}`).
  factory WizardController.fromTrip(
    TripNewRepository repository,
    TripDetails t, {
    int? homeCityId,
    DateTime Function() now = DateTime.now,
  }) {
    final c = WizardController(repository, homeCityId: homeCityId, now: now);
    c.kind = t.kind;
    c.stops
      ..clear()
      ..addAll(t.stops.map(WizardStop.fromStop));
    final (departDate, departTime) = toMoscow(t.departsAt);
    c.date = departDate;
    c.departTime = departTime;
    c.arriveTime = toMoscow(t.arrivesAt).$2;
    c.seatsTotal = t.seatsTotal;
    c.priceFull = t.price;
    c.priceBoardingMin = t.priceBoardingMin;
    for (final p in t.prices) {
      c.pairPrices[_pairKey(p.fromIdx, p.toIdx)] = p.price;
    }
    c.carId = t.car.id;
    c.carKind = t.car.kind;
    c.carSeats = t.car.seats;
    c.carLabel = '${t.car.brand} ${t.car.model}, ${t.car.plate}';
    for (final e in t.extrasPriced) {
      c.extras[e.kind] = e.price;
    }
    c.parcelSeatsTotal = t.parcelSeatsTotal == 0 ? 3 : t.parcelSeatsTotal;
    c.parcelOnly = t.parcelOnlyAllowed;
    c.bookingMode = t.bookingMode;
    return c;
  }

  /// Отклик водителя новой поездкой (Б2.2): мастер поездки, заполненный из заказа — тип, точки,
  /// дата и время, места заказа, его услуги и размер посылки с ценами по умолчанию; у заказа-посылки —
  /// «Без проезда пассажира». Публикация уходит с `orderId`.
  factory WizardController.fromOrder(
    TripNewRepository repository,
    OrderDetails o, {
    int? homeCityId,
    DateTime Function() now = DateTime.now,
  }) {
    final c = WizardController(repository, homeCityId: homeCityId, now: now)
      ..orderId = o.id
      ..minSeats = o.seats
      ..kind = o.kind;
    c.stops
      ..clear()
      ..addAll(o.stops.map(WizardStop.fromStop));
    final (departDate, departTime) = toMoscow(o.departsAt);
    c.date = departDate;
    c.departTime = departTime;
    c.arriveTime = toMoscow(o.arrivesAt).$2;
    c.seatsTotal = o.kind == TripKind.parcel ? 0 : o.seats;
    for (final (extra, service) in serviceKinds) {
      if (o.extras.contains(service)) c.extras[extra] = defaultExtraPrice(extra);
    }
    final parcel = switch (o.parcelSize) {
      ParcelSize.s => ExtraKind.parcelS,
      ParcelSize.m => ExtraKind.parcelM,
      ParcelSize.l => ExtraKind.parcelL,
      _ => null,
    };
    if (parcel != null) c.extras[parcel] = defaultExtraPrice(parcel);
    c.parcelOnly = o.kind == TripKind.parcel;
    return c;
  }

  final TripNewRepository repository;

  /// Заказ, на который водитель откликается этой поездкой; уходит в `TripInput.orderId`.
  String? orderId;

  /// Нижняя граница мест: у отклика — места заказа.
  int minSeats = 0;

  /// Город профиля: подсказки адреса ищутся рядом с ним.
  final int? homeCityId;

  /// Мастер заказа пассажира: тип → маршрут → услуги, без цены и авто; итог — `OrderInput`.
  final bool passengerOrder;

  /// Источник «сейчас» мастера: окно дат и времени выезда считается от него (тест подменяет).
  final DateTime Function() now;

  TripKind kind = TripKind.ride;
  final List<WizardStop> stops = [WizardStop(), WizardStop()];

  /// Московская дата выезда и время выезда / прибытия.
  DateTime? date;
  TimeOfDay? departTime;
  TimeOfDay? arriveTime;
  int seatsTotal = 0;

  int? priceFull;
  int? priceBoardingMin;
  final Map<String, int> pairPrices = {};

  String? carId;
  int? carSeats;

  /// Тип выбранного авто — он же тип поездки.
  VehicleKind carKind = VehicleKind.car;

  /// «Марка Модель, номер» — для окна «Опубликовать поездку?».
  String? carLabel;

  /// Включённые услуги и размеры посылки с ценой.
  final Map<ExtraKind, int> extras = {};
  int parcelSeatsTotal = 3;
  bool parcelOnly = false;
  BookingMode bookingMode = BookingMode.standard;

  static String _pairKey(int from, int to) => '$from-$to';

  void _changed(void Function() change) {
    change();
    notifyListeners();
  }

  // --- тип ---

  /// Посылка — без пассажирских мест (`seatsTotal = 0`), с выездом «только посылка».
  void setKind(TripKind value) => _changed(() {
        kind = value;
        if (value == TripKind.parcel) seatsTotal = 0;
      });

  // --- маршрут ---

  /// Новая промежуточная остановка перед финишем.
  void addStop() => _changed(() => stops.insert(stops.length - 1, WizardStop()));

  /// Удаляется только промежуточная остановка.
  void removeStop(int index) {
    if (index <= 0 || index >= stops.length - 1) return;
    _changed(() => stops.removeAt(index));
  }

  /// Ввод текста снимает выбранный населённый пункт: адрес изменился.
  void setStopText(int index, String text) => _changed(() {
        final s = stops[index];
        if (s.address == text) return;
        s
          ..address = text
          ..shortAddress = null
          ..cityId = null
          ..cityName = ''
          ..pickedCity = ''
          ..place = null
          ..lat = null
          ..lng = null;
      });

  void setStopFromSuggestion(int index, GeoSuggestion s) => _changed(() {
        stops[index]
          ..address = s.label
          ..shortAddress = s.shortLabel
          ..place = s.place
          ..lat = s.lat
          ..lng = s.lng
          ..cityId = null
          ..cityName = ''
          ..pickedCity = '';
      });

  /// Город из списка: адрес — введённая строка (или название города), координат нет.
  void setStopFromCity(int index, City city, String typed) => _changed(() {
        stops[index]
          ..address = typed.trim().isEmpty ? city.name : typed
          ..shortAddress = null
          ..cityId = city.id
          ..pickedCity = city.name
          ..place = null
          ..lat = null
          ..lng = null;
      });

  void applyTemplate(RouteTemplate template) => _changed(() {
        stops
          ..clear()
          ..addAll(template.stops.map(WizardStop.fromStop));
      });

  /// У каждой точки есть `place` или `cityId`, точек не меньше двух.
  bool get routeComplete => stops.length >= 2 && stops.every((s) => s.isSet);

  String get routeSignature => stops.map((s) => s.signature).join('>');

  List<StopInput> get stopInputs => [for (final s in stops) s.toInput()];

  // --- дата и время ---

  /// Дата выезда. Время, не попадающее в окно публикации на этот день (раньше «сейчас» или позже
  /// «сейчас» + 72 ч), сбрасывается — иначе отказ сервера всплыл бы только на шаге 6.
  void setDate(DateTime value) => _changed(() {
        date = DateTime(value.year, value.month, value.day);
        final time = departTime;
        if (time != null && !departWithinWindow(date!, time, now())) departTime = null;
      });

  void setDepartTime(TimeOfDay value) => _changed(() => departTime = value);

  void setArriveTime(TimeOfDay value) => _changed(() => arriveTime = value);

  void setSeats(int value) => _changed(() => seatsTotal = value.clamp(minSeats, maxSeats));

  /// Верхняя граница счётчика мест: у заказа — вместимость легкового, у поездки — только чтобы
  /// число влезало в строку.
  int get maxSeats => passengerOrder ? orderSeatsMax : 99;

  bool get timeComplete => date != null && departTime != null && arriveTime != null;

  DateTime? get departsAt =>
      date == null || departTime == null ? null : fromMoscow(date!, departTime!);

  DateTime? get arrivesAt => timeComplete ? arrivalFrom(date!, departTime!, arriveTime!) : null;

  /// Экран «Новый заказ - Маршрут» готов к «Далее»: маршрут, время и (для поездки с пассажирами) места.
  bool get routeStepComplete =>
      routeComplete && timeComplete && (kind == TripKind.parcel || seatsTotal >= 1);

  // --- цены ---

  /// Пары цен — участки соседних точек `(k, k+1)`; без остановок пар нет: цена одна — «Весь маршрут».
  List<(int, int)> get pricePairs {
    final last = stops.length - 1;
    return [if (last > 1) for (var k = 0; k < last; k++) (k, k + 1)];
  }

  int? pairPrice(int from, int to) => pairPrices[_pairKey(from, to)];

  void setPairPrice(int from, int to, int? value) => _changed(() {
        if (value == null) {
          pairPrices.remove(_pairKey(from, to));
        } else {
          pairPrices[_pairKey(from, to)] = value;
        }
      });

  /// Заменяет цены пар целиком (правка поездки: сброс при смене маршрута и возврат при отказе).
  void replacePairPrices(Map<String, int> prices) => _changed(() {
        pairPrices
          ..clear()
          ..addAll(prices);
      });

  void setPriceFull(int? value) => _changed(() => priceFull = value);

  void setPriceBoardingMin(int? value) => _changed(() => priceBoardingMin = value);

  /// Ошибка цены одного поля: больше [priceMax] или ниже посадки.
  PriceIssue? _bounds(int? price) {
    if (price == null) return null;
    if (price > priceMax) return const PriceTooHigh();
    final boarding = priceBoardingMin;
    if (boarding != null && price < boarding) return PriceBelowBoarding(boarding);
    return null;
  }

  /// Ошибка у «Весь маршрут»: границы, затем не меньше самого дорогого введённого участка и,
  /// когда введены все, не больше их суммы.
  PriceIssue? get fullPriceIssue {
    final full = priceFull;
    final bounds = _bounds(full);
    if (full == null || bounds != null) return bounds;
    final legs = [for (final p in pricePairs) if (pairPrice(p.$1, p.$2) case final price?) (p, price)];
    if (legs.isEmpty) return null;
    final top = legs.reduce((a, b) => b.$2 > a.$2 ? b : a);
    if (full < top.$2) return FullBelowLeg(top.$1.$1, top.$1.$2, top.$2);
    if (legs.length < pricePairs.length) return null;
    final sum = legs.fold<int>(0, (acc, l) => acc + l.$2);
    return full > sum ? FullAboveSum(sum) : null;
  }

  /// Ошибка участка с началом в точке [from].
  PriceIssue? legPriceIssue(int from) => _bounds(pairPrice(from, from + 1));

  /// Ошибка у «Стоимость посадки»: пусто, когда цены уже вводятся, или больше [priceMax].
  PriceIssue? get boardingPriceIssue {
    final boarding = priceBoardingMin;
    if (boarding == null) return priceFull != null ? const BoardingEmpty() : null;
    return boarding > priceMax ? const PriceTooHigh() : null;
  }

  /// Все цены введены, «Весь маршрут» и участки положительны и без ошибок. Посадка за 0 ₽ допустима
  /// (принятое решение 2026-10-22).
  bool get priceComplete =>
      (priceFull ?? 0) > 0 &&
      (priceBoardingMin ?? -1) >= 0 &&
      pricePairs.every((p) => (pairPrice(p.$1, p.$2) ?? 0) > 0) &&
      fullPriceIssue == null &&
      boardingPriceIssue == null &&
      pricePairs.every((p) => legPriceIssue(p.$1) == null);

  List<Price> get priceList => [
        for (final p in pricePairs) Price(fromIdx: p.$1, toIdx: p.$2, price: pairPrice(p.$1, p.$2) ?? 0),
      ];

  // --- авто ---

  void setCar(Car car) => _changed(() {
        carId = car.id;
        carKind = car.kind;
        carSeats = car.seats;
        carLabel = '${car.brand} ${car.model}, ${car.plate}';
      });

  // --- услуги и посылка ---

  bool extraOn(ExtraKind kind) => extras.containsKey(kind);

  void setExtra(ExtraKind kind, bool on) => _changed(() {
        if (on) {
          extras.putIfAbsent(kind, () => defaultExtraPrice(kind));
        } else {
          extras.remove(kind);
        }
      });

  void setExtraPrice(ExtraKind kind, int price) => _changed(() => extras[kind] = price);

  void setParcelSeats(int value) => _changed(() => parcelSeatsTotal = value);

  void setParcelOnly(bool value) => _changed(() => parcelOnly = value);

  void setBookingMode(BookingMode value) => _changed(() => bookingMode = value);

  bool get hasParcel => extras.keys.any(isParcelKind);

  /// Места для посылок: 0 без размеров.
  int get effectiveParcelSeats => hasParcel ? parcelSeatsTotal : 0;

  /// Шаг услуг готов: поездка-посылка требует хотя бы один размер и число мест для посылок.
  bool get extrasComplete =>
      (kind == TripKind.ride || hasParcel) && (!hasParcel || parcelSeatsTotal >= 1) &&
      extras.values.every((p) => p >= 0);

  // --- заказ пассажира ---

  /// Размер посылки заказа — один (шторка «Новый заказ - Выбор веса посылки» в режиме заказа); `none` — без посылки.
  ParcelSize orderParcel = ParcelSize.none;

  /// Комментарий к посылке заказа («Вид посылки», как в брони «Бронирование»).
  String parcelComment = '';

  void setOrderParcel(ParcelSize value) => _changed(() => orderParcel = value);

  void setParcelComment(String value) => _changed(() => parcelComment = value);

  /// Заказ готов к публикации: маршрут, время, места (у поездки) и размер (у посылки).
  bool get orderReady => routeStepComplete && (kind == TripKind.ride || orderParcel != ParcelSize.none);

  /// Тело `POST /orders`: услуги — только у поездки, комментарий — только при посылке.
  OrderInput toOrderInput() {
    final comment = parcelComment.trim();
    return OrderInput(
      kind: kind,
      stops: stopInputs,
      departsAt: departsAt!,
      arrivesAt: arrivesAt!,
      seats: kind == TripKind.parcel ? 0 : seatsTotal,
      parcelSize: orderParcel,
      parcelComment: orderParcel != ParcelSize.none && comment.isNotEmpty ? comment : null,
      extras: kind == TripKind.parcel ? const [] : [for (final (e, s) in serviceKinds) if (extraOn(e)) s],
    );
  }

  // --- итог ---

  bool get readyToPublish =>
      routeStepComplete && priceComplete && carId != null && extrasComplete;
  /// Тело `POST /trips`. Поездка-посылка всегда «только посылка»: мест для пассажиров нет.
  TripInput toInput() => TripInput(
        kind: kind,
        vehicleKind: carKind,
        stops: stopInputs,
        departsAt: departsAt!,
        arrivesAt: arrivesAt!,
        seatsTotal: kind == TripKind.parcel ? 0 : seatsTotal,
        priceFull: priceFull!,
        prices: priceList,
        priceBoardingMin: priceBoardingMin!,
        carId: carId!,
        extras: [for (final e in extras.entries) Extra(kind: e.key, price: e.value)],
        parcelOnlyAllowed: hasParcel && (kind == TripKind.parcel || parcelOnly),
        parcelSeatsTotal: effectiveParcelSeats,
        bookingMode: bookingMode,
        orderId: orderId,
      );

  /// Тело `PATCH /trips/{id}`: сгенерированная схема `TripPatch` требует все поля, поэтому уходит
  /// полное состояние — неизменённые поля совпадают с текущими, сервер сливает их без изменений.
  TripPatch toPatch() {
    final i = toInput();
    return TripPatch(
      kind: i.kind,
      vehicleKind: i.vehicleKind,
      stops: i.stops,
      departsAt: i.departsAt,
      arrivesAt: i.arrivesAt,
      seatsTotal: i.seatsTotal,
      priceFull: i.priceFull,
      prices: i.prices,
      priceBoardingMin: i.priceBoardingMin,
      carId: i.carId,
      extras: i.extras,
      parcelOnlyAllowed: i.parcelOnlyAllowed,
      parcelSeatsTotal: i.parcelSeatsTotal,
      bookingMode: i.bookingMode,
    );
  }
}
