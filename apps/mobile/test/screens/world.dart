import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/app.dart';
import 'package:the_way/src/app/session.dart';

import '../features/driver_bookings/support.dart' show MockAdapter;
import 'shot.dart';

/// Мир снимков: подставной сервер, сессия и запуск настоящего приложения (`TheWayApp`, таблица
/// маршрутов) на нужном маршруте. Фото людей и авто приходят по `/files/photo-<id>` и `/files/car-<id>` —
/// их подменяет [servePhotos] (у каждого человека и авто своё фото).
///
/// **Один сценарий, а не текст каждого кадра.** Кадры между собой не согласованы (лента «Базовые экраны - Поездки есть» —
/// «09:00, 1800 ₽», детали той же поездки «Детали поездки - Мест нет» — «08:00, 1200 ₽»; у брони 3 места на «Экран поездки после оплаты» и 24 на «Детали поездки - Бронь есть»),
/// поэтому числа здесь — одной истории и считаются так, как считает сервер:
/// - **поездка Виктора О.** ([viktorTrip], `t1`) — пассажир (я, Анастасия) находит её в ленте («Базовые экраны - Поездки есть»),
/// открывает («Детали поездки - Мест нет»), бронирует («Бронирование» – «Заказ - Оплата прошла»), видит в «Мои заказы» («Мои заказы - Есть заказы») и в деталях брони («Экран поездки после оплаты» – «Детали поездки - Лимит отмен»);
/// - **моя поездка** ([myTrip], `t2`) — я водитель: карточка «Базовые экраны - Поездок нет», детали «Детали поездки созданной водителем - Без пассажиров» – «Редактирование - Нельзя выбрать кол-во мест меньше чем УЖЕ занято», заявки «Редактирование - Пассажиры есть» – «Пассажир оплатил»;
/// - цена брони — [shotPriceTotal] (формула `apps/api/.../bookings/internal/pricing.ts`), занятые места,
///   «Стоимость» водителя и закрытая правка — из списка броней (места занимает только оплата).
///
/// Где число снимка расходится с текстом кадра, причина — в README снимков, раздел «Данные снимков».
class ShotWorld {
  ShotWorld({this.mode = UserMode.passenger, bool geoShown = true}) {
    FlutterSecureStorage.setMockInitialValues({});
    adapter = MockAdapter(routes);
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter
      ..transformer = SyncTransformer();
    session = AppSession(const FlutterSecureStorage(), token: 'tok', geoPromptShown: geoShown)
      ..api = TheWayApi(dio)
      ..me = Me.fromJson(meJson(mode: mode));
    routes['GET /me'] = (_) => meJson(mode: mode);
  }

  final UserMode mode;
  final Map<String, Object?> routes = {
    'GET /updates': <Object?>[],
    'GET /trips': feed(),
  };
  late final MockAdapter adapter;
  late final AppSession session;

  /// Запускает приложение; [route] — маршрут из `AppRoutes`, [args] — его аргументы
  /// (для `shell` — номер вкладки).
  Future<void> open(WidgetTester tester, {String route = 'shell', Object? args}) async {
    await tester.pumpWidget(shotRoot(TheWayApp(session: session, routeObserver: RouteNameObserver())));
    shotTake(tester);
    await tester.pump();
    shotTake(tester);
    if (route != 'shell' || args != null) {
      navigatorKey.currentState!.pushNamedAndRemoveUntil(route, (_) => false, arguments: args);
    }
    await shotSettle(tester);
  }

  /// Нажимает [finder] и даёт ответам прийти.
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    shotTake(tester);
    await tester.pump();
    shotTake(tester);
    await tester.tap(finder);
    await shotSettle(tester);
  }
}

// ---- люди и авто ---------------------------------------------------------------------------

Map<String, Object?> rating(num value, [int count = 4]) => {'value': value, 'count': count};

/// Мой телефон — тот же, что при входе («Вход - Ввод номера (данные введены)» – «Вход - СМС код (базовый экран)»: SIM Беларуси, «+375 25 777 44 20»).
const myPhone = '+375257774420';

Map<String, Object?> meJson({UserMode mode = UserMode.passenger, String name = 'Анастасия', String? photo = '/files/photo-me'}) => {
      'id': 'me',
      'phone': myPhone,
      'name': name,
      'photoUrl': photo,
      'city': {'id': 1, 'name': 'Ярославль'},
      'mode': mode.json,
      'rating': rating(4.8, 8),
      'tripsCount': 120,
      'cancellationsLast30': 0,
    };

Map<String, Object?> user(String id, String name, {num rate = 4.5, int trips = 127, String? phone, int ratingCount = 4}) => {
      'id': id,
      'name': name,
      'photoUrl': '/files/photo-$id',
      'rating': rating(rate, ratingCount),
      'tripsCount': trips,
      'phone': ?phone,
    };

/// Я — водитель своей поездки.
Map<String, Object?> me() => user('me', 'Анастасия', rate: 4.8, trips: 120);

/// Водитель поездки, которую находит пассажир («Базовые экраны - Поездки есть», «Детали поездки - Мест нет» – «Детали поездки - Лимит отмен»).
Map<String, Object?> viktor({String? phone}) => user('d1', 'Виктор О.', phone: phone);

/// Пассажиры моей поездки («Детали поездки - С пассажирами», «Профиль - Профиль пассажира» – «Пассажир оплатил») — разные люди, а не трижды «Виктор О.» кадров.
Map<String, Object?> pavel({String? phone}) => user('p1', 'Павел С.', rate: 4.8, trips: 120, phone: phone);
Map<String, Object?> olga({String? phone = '+79051234567'}) => user('p2', 'Ольга Н.', rate: 4.9, trips: 34, phone: phone);
Map<String, Object?> alexey({String? phone = '+79157654321'}) => user('p3', 'Алексей Р.', rate: 4.7, trips: 58, phone: phone);

Map<String, Object?> stop(int idx, String city, String address, {num? lat, num? lng}) =>
    {'idx': idx, 'cityId': idx + 1, 'cityName': city, 'address': address, 'shortAddress': address, 'lat': ?lat, 'lng': ?lng};

/// Остановки «Улица Солнечная, дом 1 → … → Улица Лунная, дом 2» кадров экранов поездки.
final routeStops = [
  stop(0, 'Ярославль', 'Улица Солнечная, дом 1'),
  stop(1, 'Ростов', 'Улица Ленина, дом 5'),
  stop(2, 'Ростов', 'Улица Пушкина, дом 10'),
  stop(3, 'Москва', 'Улица Лунная, дом 2'),
];

Map<String, Object?> car({
  String id = 'c1',
  String brand = 'Toyota',
  String model = 'Camry',
  String status = 'verified',
  String plate = '7841HX-7',
  int seats = 4,
  bool sts = false,
}) =>
    {
      'id': id,
      'brand': brand,
      'model': model,
      'kind': 'car',
      'seats': seats,
      'plate': plate,
      'photoUrl': '/files/car-$id',
      'status': status,
      'documents': sts
          ? [
              {'id': 'd1', 'kind': 'sts', 'url': '/files/doc-1'},
            ]
          : <Object?>[],
    };

/// Мои авто («Транспортные средства»; в мастере «Новый заказ - Выбор авто - есть авто», «Новый заказ - Выбор авто - выбрано авто» — первые два): три разных легковых, а не три копии карточки кадра.
/// Сценарий снимков — на легковом, мест 1–8 (реестр, строка 69): автобуса «Solaris StarLiner, 24 места»
/// кадров «Детали поездки - Бронь есть» – «Отлик» в снимках нет.
final myCars = [
  car(id: 'c1', plate: '7841HX-7'),
  car(id: 'c2', brand: 'Hyundai', model: 'Solaris', plate: 'В222ВВ76'),
  car(id: 'c3', brand: 'Kia', model: 'Rio', plate: 'Е333ЕЕ76'),
];

/// Авто Виктора О. («Детали поездки - Мест нет» – «Детали поездки - Лимит отмен»): «Toyota Camry 7777 АА-7», как в кадрах деталей поездки.
final viktorCar = car(id: 'v1', plate: '7777 АА-7');

/// «15 мая, 09:00» по Москве — 06:00 UTC.
String mskIso(int day, int hour, [int minute = 0, int month = 5]) =>
    DateTime.utc(2026, month, day, hour - 3, minute).toIso8601String();

// ---- цены: формула сервера -----------------------------------------------------------------

/// Цены участков поездки ровно такие, какие принимает сервер (`trip-validation.ts`, `checkPrices`):
/// участки соседних точек; цена участка — доля цены всего маршрута, округлённая вверх, — так весь маршрут
/// не дороже суммы участков и не дешевле самого дорогого. Без остановок участков нет.
List<Map<String, Object?>> pairPrices(int stopCount, int priceFull) {
  final last = stopCount - 1;
  final leg = (priceFull + last - 1) ~/ last;
  return [
    if (last > 1)
      for (var k = 0; k < last; k++) {'fromIdx': k, 'toIdx': k + 1, 'price': leg},
  ];
}

const _servicePrices = {'luggage': 150, 'pets': 150, 'child_seat': 100};
const _parcelPrices = {'S': 150, 'M': 250, 'L': 350};
const _parcelKind = {'S': 'parcel_s', 'M': 'parcel_m', 'L': 'parcel_l'};

/// Цена отрезка: весь маршрут — цена поездки; иначе сумма участков на пути, но не дороже всего маршрута;
/// участка нет — `null` (`pricing.ts`, `segPrice`).
int? shotSegPrice(Map<String, Object?> trip, int fromIdx, int toIdx) {
  final last = (trip['stops']! as List).length - 1;
  if (fromIdx < 0 || toIdx > last || fromIdx >= toIdx) return null;
  if (fromIdx == 0 && toIdx == last) return trip['price']! as int;
  final legs = (trip['prices']! as List).cast<Map<String, Object?>>();
  var sum = 0;
  for (var k = fromIdx; k < toIdx; k++) {
    final leg = legs.where((p) => p['fromIdx'] == k && p['toIdx'] == k + 1).firstOrNull;
    if (leg == null) return null;
    sum += leg['price']! as int;
  }
  return sum < (trip['price']! as int) ? sum : trip['price']! as int;
}

int _extraPrice(Map<String, Object?> trip, String kind) => (trip['extrasPriced']! as List)
    .cast<Map<String, Object?>>()
    .firstWhere((e) => e['kind'] == kind)['price']! as int;

/// Итог брони: цена отрезка × места + услуги + размер посылки (`pricing.ts`, `priceBooking`).
int shotPriceTotal(
  Map<String, Object?> trip, {
  required int fromIdx,
  required int toIdx,
  required int seats,
  String parcelSize = 'none',
  List<String> services = const [],
}) {
  final segment = shotSegPrice(trip, fromIdx, toIdx)!;
  final parcel = parcelSize == 'none' ? 0 : _extraPrice(trip, _parcelKind[parcelSize]!);
  return segment * seats + services.fold<int>(0, (sum, s) => sum + _extraPrice(trip, s)) + parcel;
}

/// `GET /trips/{id}/quote` подставного сервера: итог по параметрам запроса той же формулой.
Object? Function(RequestOptions) quoteRoute(Map<String, Object?> trip) => (o) {
      final q = o.queryParameters;
      int arg(String key) => int.parse('${q[key]}');
      final extras = '${q['extras'] ?? ''}';
      return {
        'segmentPrice': shotSegPrice(trip, arg('fromIdx'), arg('toIdx')),
        'priceTotal': shotPriceTotal(
          trip,
          fromIdx: arg('fromIdx'),
          toIdx: arg('toIdx'),
          seats: arg('seats'),
          parcelSize: '${q['parcelSize'] ?? 'none'}',
          services: extras.isEmpty ? const [] : extras.split(','),
        ),
      };
    };

// ---- поездки --------------------------------------------------------------------------------

/// Детали поездки (`TripDetails`). Цены пар — [pairPrices], цены услуг — только предложенных.
Map<String, Object?> tripDetails({
  String id = 't1',
  int number = 1231,
  String kind = 'ride',
  List<Map<String, Object?>>? stops,
  String? departsAt,
  String? arrivesAt,
  int seatsTotal = 3,
  int seatsFree = 1,
  int parcelSeatsTotal = 3,
  int parcelSeatsFree = 1,
  int price = 1200,
  int priceBoardingMin = 100,
  Map<String, Object?>? driver,
  Map<String, Object?>? carJson,
  List<String> extras = const ['luggage', 'pets', 'child_seat'],
  List<String> parcelSizes = const ['S', 'M'],
  bool bookable = true,
  bool parcelBookable = true,
  bool isMine = false,
  Map<String, Object?>? myBooking,
  bool editLocked = false,
  String bookingMode = 'standard',
  int? paidTotal,
  String status = 'active',
  bool registrationOpen = false,
  int duplicates = 1,
  num distanceKm = 3.2,
}) {
  final s = stops ?? routeStops;
  return {
    'id': id,
    'number': number,
    'kind': kind,
    'from': s.first,
    'to': s.last,
    'stopsCount': s.length - 2,
    'departsAt': departsAt ?? mskIso(15, 8),
    'arrivesAt': arrivesAt ?? mskIso(15, 18),
    'seatsFree': seatsFree,
    'seatsTotal': seatsTotal,
    'parcelSeatsFree': parcelSizes.isEmpty ? 0 : parcelSeatsFree,
    'parcelSeatsTotal': parcelSizes.isEmpty ? 0 : parcelSeatsTotal,
    'price': price,
    'distanceKm': distanceKm,
    'driver': driver ?? viktor(),
    'extras': extras,
    'parcelAllowed': parcelSizes.isNotEmpty,
    'parcelSizes': parcelSizes,
    'duplicates': duplicates,
    'registrationOpen': registrationOpen,
    'bookable': bookable,
    'parcelBookable': parcelBookable && parcelSizes.isNotEmpty,
    'effectiveStatus': status,
    'stops': s,
    'prices': pairPrices(s.length, price),
    'priceBoardingMin': priceBoardingMin,
    'extrasPriced': [
      for (final e in extras) {'kind': e, 'price': _servicePrices[e]},
      for (final size in parcelSizes) {'kind': _parcelKind[size], 'price': _parcelPrices[size]},
    ],
    'parcelOnlyAllowed': true,
    'bookingMode': bookingMode,
    'car': carJson ?? viktorCar,
    'isMine': isMine,
    'editLocked': editLocked,
    'myBooking': myBooking,
    'paidTotal': ?paidTotal,
  };
}

/// Поездка Виктора О. глазами пассажира («Базовые экраны - Поездки есть», «Детали поездки - Мест нет» – «Детали поездки - Лимит отмен»): 15 мая 08:00–18:00, 1200 ₽, 3 места (свободно 1),
/// посылки S, M (свободно 1 из 3), «Toyota Camry 7777 АА-7».
Map<String, Object?> viktorTrip({
  int seatsFree = 1,
  bool bookable = true,
  Map<String, Object?>? myBooking,
  List<String> parcelSizes = const ['S', 'M'],
  List<Map<String, Object?>>? stops,
  String? driverPhone,
  bool registrationOpen = false,
  int duplicates = 1,
}) =>
    tripDetails(
      seatsFree: seatsFree,
      bookable: bookable,
      myBooking: myBooking,
      parcelSizes: parcelSizes,
      stops: stops,
      driver: viktor(phone: driverPhone),
      registrationOpen: registrationOpen,
      duplicates: duplicates,
    );

const _joined = ['awaiting_payment', 'paid'];

/// Моя поездка водителем («Базовые экраны - Поездок нет» – «Пассажир оплатил»): 16 мая 12:00–16:00, 1200 ₽, «Toyota Camry 7841HX-7», 4 места.
/// Места и «Стоимость» — из [bookings]: место занимает только оплата (сервер сдвигает занятые при `pay`),
/// «Стоимость» — сумма оплаченных броней, правка закрыта при брони «ждёт оплаты» или «оплачено».
Map<String, Object?> myTrip({List<Map<String, Object?>> bookings = const [], String status = 'active', int seatsTotal = 4}) {
  final paid = bookings.where((b) => b['status'] == 'paid');
  final paidSeats = paid.fold<int>(0, (sum, b) => sum + (b['seats']! as int));
  final paidParcels = paid.where((b) => b['parcelSize'] != 'none').length;
  return tripDetails(
    id: 't2',
    number: 1241,
    departsAt: mskIso(16, 12),
    arrivesAt: mskIso(16, 16),
    seatsTotal: seatsTotal,
    seatsFree: seatsTotal - paidSeats,
    parcelSeatsFree: 3 - paidParcels,
    driver: me(),
    carJson: myCars.first,
    isMine: true,
    paidTotal: paid.fold<int>(0, (sum, b) => sum + (b['priceTotal']! as int)),
    editLocked: bookings.any((b) => _joined.contains(b['status'])),
    status: status,
  );
}

/// Карточка поездки внутри брони и в ленте (`TripCard`) — детали без полей деталей.
Map<String, Object?> tripCard(Map<String, Object?> details, {Map<String, Object?> overrides = const {}}) {
  final d = {...details, ...overrides};
  for (final k in ['stops', 'prices', 'priceBoardingMin', 'extrasPriced', 'parcelOnlyAllowed', 'bookingMode', 'car', 'isMine', 'editLocked', 'myBooking', 'paidTotal']) {
    d.remove(k);
  }
  return d;
}

/// Карточка ленты другого водителя («Базовые экраны - Поездки есть» — вторая и третья карточки).
Map<String, Object?> feedCard(
  String id,
  Map<String, Object?> driver,
  num km, {
  required Map<String, Object?> from,
  required Map<String, Object?> to,
  int seats = 1,
  List<String> extras = const ['pets', 'child_seat'],
}) =>
    tripCard(tripDetails(
      id: id,
      number: 1250,
      stops: [from, to],
      departsAt: mskIso(15, 9),
      seatsTotal: seats,
      seatsFree: seats,
      price: 1800,
      driver: driver,
      extras: extras,
      parcelSizes: const [],
      distanceKm: km,
    ));

/// Лента «Поездки» («Базовые экраны - Поездки есть»): первая карточка — поездка Виктора О. (та же, что в деталях «Детали поездки - Мест нет»), за ней
/// поездки Александра П. и Дмитрия С.
List<Map<String, Object?>> feed({bool registrationOpen = false, int duplicates = 1, bool third = true}) => [
      tripCard(viktorTrip(registrationOpen: registrationOpen, duplicates: duplicates)),
      feedCard('f2', user('d-f2', 'Александр П.', rate: 3.8), 4.0,
          from: stop(0, 'Ярославль', 'Улица Солнечная, дом 5'), to: stop(1, 'Москва', 'Проспект Мечты, дом 12')),
      if (third)
        feedCard('f3', user('d-f3', 'Дмитрий С.', rate: 2.1), 5.0,
            from: stop(0, 'Ярославль', 'Улица Садовая, дом 3'), to: stop(1, 'Москва', 'Улица Мира, дом 9')),
    ];

/// Поездка другого водителя на две точки — для броней «Мои заказы» («Мои заказы - Есть заказы»).
Map<String, Object?> otherTrip(
  String id, {
  required String from,
  required String to,
  required int day,
  required int hour,
  int hours = 3,
  Map<String, Object?>? driver,
  String status = 'active',
}) =>
    tripDetails(
      id: id,
      number: 1260,
      stops: [stop(0, 'Ярославль', from), stop(1, 'Москва', to)],
      departsAt: mskIso(day, hour),
      arrivesAt: mskIso(day, hour + hours),
      price: 600,
      driver: driver,
      status: status,
    );

// ---- брони ----------------------------------------------------------------------------------

/// Бронь (`Booking`) на поездке [trip] (по умолчанию — поездка Виктора О.): цена отрезка и итог — по
/// формуле сервера, услуги и посылка — по ценам поездки. [passenger] — по умолчанию я.
Map<String, Object?> booking({
  String id = 'b1',
  int number = 1231,
  String status = 'paid',
  Map<String, Object?>? trip,
  Map<String, Object?>? passenger,
  int seats = 1,
  int fromIdx = 0,
  int? toIdx,
  String parcelSize = 'none',
  bool parcelOnly = false,
  List<String> services = const [],
  String? parcelComment,
  num? segmentKm = 3.2,
}) {
  final t = trip ?? viktorTrip();
  final stops = (t['stops']! as List).cast<Map<String, Object?>>();
  final to = toIdx ?? stops.length - 1;
  return {
    'id': id,
    'number': number,
    'status': status,
    'seats': seats,
    'fromIdx': fromIdx,
    'toIdx': to,
    'from': stops[fromIdx],
    'to': stops[to],
    'segmentPrice': shotSegPrice(t, fromIdx, to),
    'parcelSize': parcelSize,
    'parcelOnly': parcelOnly,
    'parcelComment': ?parcelComment,
    'extras': [
      for (final s in services) {'kind': s, 'price': _extraPrice(t, s)},
      if (parcelSize != 'none') {'kind': _parcelKind[parcelSize], 'price': _extraPrice(t, _parcelKind[parcelSize]!)},
    ],
    'priceTotal': shotPriceTotal(t, fromIdx: fromIdx, toIdx: to, seats: seats, parcelSize: parcelSize, services: services),
    'segmentKm': ?segmentKm,
    'createdAt': mskIso(14, 10),
    'paidAt': status == 'paid' ? mskIso(14, 11) : null,
    'trip': tripCard(t),
    'passenger': passenger ?? me(),
  };
}

/// Моя бронь на поездке Виктора О. («Экран поездки после оплаты», «Мои заказы - Есть заказы», «Детали поездки - Бронь есть», «Детали поездки - Отмена брони» – «Детали поездки - Лимит отмен»): «Улица Солнечная, дом 1 → Улица Ленина,
/// дом 5», 1 место, с животными — 400 + 150 = 550 ₽.
Map<String, Object?> myBooking({String status = 'paid', String id = 'b1'}) =>
    booking(id: id, status: status, toIdx: 1, services: const ['pets']);

/// Заявки на мою поездку («Детали поездки - С пассажирами» – «Редактирование - Нельзя выбрать кол-во мест меньше чем УЖЕ занято», «Редактирование - Пассажиры есть» – «Пассажир оплатил»): не подтверждена (Павел С., 2 места), ждёт оплаты
/// (Ольга Н.), оплачена (Алексей Р., до «Улицы Пушкина»). Занято оплатой — 1 место из 4.
List<Map<String, Object?>> myTripBookings() {
  final t = myTrip();
  return [
    booking(id: 'b21', number: 2101, status: 'requested', trip: t, seats: 2, passenger: pavel()),
    booking(id: 'b22', number: 2102, status: 'awaiting_payment', trip: t, passenger: olga(), segmentKm: 1.8),
    booking(id: 'b23', number: 2103, status: 'paid', trip: t, toIdx: 2, passenger: alexey(), segmentKm: 5.1),
  ];
}

/// Карточка поездки в «Мои заказы» водителя («Базовые экраны - Поездок нет»): поля карточки и счётчики откликов из [bookings].
Map<String, Object?> driverCard(Map<String, Object?> trip, {List<Map<String, Object?>> bookings = const []}) {
  int count(String status) => bookings.where((b) => b['status'] == status).length;
  final active = bookings.where((b) => ['requested', ..._joined].contains(b['status'])).toList();
  return {
    ...tripCard(trip),
    'requested': count('requested'),
    'awaitingPayment': count('awaiting_payment'),
    'paid': count('paid'),
    'parcels': bookings.where((b) => b['parcelSize'] != 'none').length,
    'responders': [
      for (final b in active.take(2))
        {'id': (b['passenger']! as Map)['id'], 'photoUrl': (b['passenger']! as Map)['photoUrl']},
    ],
  };
}

// ---- подсказки адреса -----------------------------------------------------------------------

Map<String, Object?> suggestion(String label, String city, {String region = 'Ярославская область', num lat = 57.62, num lng = 39.89}) => {
      'label': label,
      'shortLabel': label,
      'lat': lat,
      'lng': lng,
      'place': {'name': city, 'region': region},
    };

/// Подсказки, которые знает подставной геокодер («Новый заказ - Маршрут выбор 1 точки», «Новый заказ - Маршрут выбор 2 точки» и маршрут мастера).
final suggestions = [
  suggestion('Солнечная 1, Ярославль', 'Ярославль'),
  suggestion('Солнечная 5, Ярославль', 'Ярославль'),
  suggestion('Ленина 5, Ростов', 'Ростов', lat: 57.18, lng: 39.41),
  suggestion('Ленина 12, Ярославль', 'Ярославль'),
  suggestion('Лунная 2, Москва', 'Москва', region: 'Москва', lat: 55.75, lng: 37.62),
];

/// `GET /geo/suggest` подставного сервера: подсказки, в которых есть набранный текст.
Object? Function(RequestOptions) suggestRoute() => (o) {
      final q = '${o.queryParameters['q'] ?? ''}'.toLowerCase();
      return [for (final s in suggestions) if ((s['label']! as String).toLowerCase().contains(q)) s];
    };
