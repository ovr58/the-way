/// Ответы подставного сервера для заказов пассажира (план `passenger-order_2026-10-22.md`): карточка
/// `OrderCard` и детали `OrderDetails`. Общие для тестов мастера, «Моих заказов» и снимков `ord-p-*`.
library;

Map<String, Object?> orderStop(int idx, String city, String address) =>
    {'idx': idx, 'cityId': idx + 1, 'cityName': city, 'address': address, 'shortAddress': address};

/// Заказ пассажира: Ярославль — Москва, выезд 16 мая 12:00 МСК, прибытие 15:00.
Map<String, Object?> orderCardJson({
  String id = 'o1',
  int number = 1240,
  String kind = 'ride',
  String status = 'open',
  int seats = 2,
  String parcelSize = 'none',
  String? parcelComment,
  List<String> extras = const ['pets'],
  String createdAt = '2026-05-12T09:00:00.000Z',
  String departsAt = '2026-05-16T09:00:00.000Z',
  String arrivesAt = '2026-05-16T12:00:00.000Z',
  String? bookingId,
}) =>
    {
      'id': id,
      'number': number,
      'kind': kind,
      'from': orderStop(0, 'Ярославль', 'Улица Солнечная, дом 1'),
      'to': orderStop(2, 'Москва', 'Улица Лунная, дом 2'),
      'stopsCount': 1,
      'departsAt': departsAt,
      'arrivesAt': arrivesAt,
      'seats': seats,
      'parcelSize': parcelSize,
      'parcelOnly': kind == 'parcel',
      'parcelComment': ?parcelComment,
      'extras': extras,
      'passenger': {
        'id': 'me',
        'name': 'Анастасия',
        'rating': {'value': 4.8, 'count': 8},
        'tripsCount': 120,
      },
      'status': status,
      'bookingId': ?bookingId,
      'createdAt': createdAt,
    };

Map<String, Object?> orderDetailsJson({
  String id = 'o1',
  int number = 1240,
  String kind = 'ride',
  String status = 'open',
  int seats = 2,
  String parcelSize = 'none',
  String? parcelComment,
  List<String> extras = const ['pets'],
  bool isMine = true,
}) =>
    {
      ...orderCardJson(
        id: id,
        number: number,
        kind: kind,
        status: status,
        seats: seats,
        parcelSize: parcelSize,
        parcelComment: parcelComment,
        extras: extras,
      ),
      'stops': [
        orderStop(0, 'Ярославль', 'Улица Солнечная, дом 1'),
        orderStop(1, 'Ростов', 'Улица Ленина, дом 5'),
        orderStop(2, 'Москва', 'Улица Лунная, дом 2'),
      ],
      'isMine': isMine,
      'matchingTrips': <Object?>[],
    };

Map<String, Object?> _user({String id = 'u1', String name = 'Виктор О.'}) => {
      'id': id,
      'name': name,
      'rating': {'value': 4.8, 'count': 3},
      'tripsCount': 120,
    };

/// Бронь пассажира на поездке t1 (Ярославль — Москва, 16 мая 12:00–15:00); из заказа — с [orderId].
Map<String, Object?> bookingJson({
  required String id,
  required int number,
  String status = 'paid',
  String createdAt = '2026-05-10T09:00:00.000Z',
  String? orderId,
  int? orderNumber,
  String? paidAt,
}) =>
    {
      'id': id,
      'number': number,
      'status': status,
      'seats': 1,
      'fromIdx': 0,
      'toIdx': 1,
      'from': orderStop(0, 'Ярославль', 'Улица Солнечная, дом 1'),
      'to': orderStop(1, 'Москва', 'Улица Лунная, дом 2'),
      'segmentPrice': 400,
      'parcelSize': 'none',
      'parcelOnly': false,
      'extras': <Object>[],
      'priceTotal': 600,
      'createdAt': createdAt,
      'trip': {
        'id': 't1',
        'number': 7,
        'kind': 'ride',
        'from': orderStop(0, 'Ярославль', 'Улица Солнечная, дом 1'),
        'to': orderStop(1, 'Москва', 'Улица Лунная, дом 2'),
        'stopsCount': 0,
        'departsAt': '2026-05-16T09:00:00.000Z',
        'arrivesAt': '2026-05-16T12:00:00.000Z',
        'seatsFree': 3,
        'seatsTotal': 4,
        'parcelSeatsFree': 0,
        'parcelSeatsTotal': 0,
        'price': 1200,
        'driver': _user(),
        'extras': <String>[],
        'parcelAllowed': false,
        'parcelSizes': <String>[],
        'duplicates': 1,
        'registrationOpen': true,
        'bookable': false,
        'parcelBookable': false,
        'effectiveStatus': 'active',
      },
      'passenger': _user(id: 'me', name: 'Анастасия'),
      'orderId': ?orderId,
      'orderNumber': ?orderNumber,
      'paidAt': ?paidAt,
    };

/// Поездка t1 целиком (`GET /trips/t1`) для деталей брони.
Map<String, Object?> tripDetailsJson() => {
      ...(bookingJson(id: 'b0', number: 0)['trip']! as Map<String, Object?>),
      'stops': [orderStop(0, 'Ярославль', 'Улица Солнечная, дом 1'), orderStop(1, 'Москва', 'Улица Лунная, дом 2')],
      'prices': <Object>[],
      'priceBoardingMin': 100,
      'extrasPriced': <Object>[],
      'parcelOnlyAllowed': false,
      'bookingMode': 'standard',
      'car': {
        'id': 'c1',
        'brand': 'Toyota',
        'model': 'Camry',
        'kind': 'car',
        'seats': 4,
        'plate': '7777 АА-7',
        'status': 'verified',
        'documents': <Object>[],
      },
      'isMine': false,
      'editLocked': false,
    };
