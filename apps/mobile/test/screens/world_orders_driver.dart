import 'world.dart';

/// Подставные ответы лент заказов пассажиров глазами водителя (план `passenger-order_2026-10-22.md`,
/// Б3.3). Одна история с миром снимков: я (Анастасия) — водитель, 16 мая у меня поездка t2 «Ярославль →
/// Москва» в 12:00 ([myTrip]) и ещё одна в 18:00 ([myEveningTrip]); пассажиры — люди мира снимков.

/// Заказ пассажира (`OrderCard`): точки — Ярославль → Москва, 16 мая.
Map<String, Object?> orderCard(
  String id,
  Map<String, Object?> passenger, {
  required int number,
  required Map<String, Object?> from,
  required Map<String, Object?> to,
  int hour = 12,
  int hours = 4,
  String kind = 'ride',
  int seats = 1,
  String parcelSize = 'none',
  String? parcelComment,
  List<String> extras = const [],
  int stopsCount = 0,
  num km = 3.2,
}) =>
    {
      'id': id,
      'number': number,
      'kind': kind,
      'from': from,
      'to': to,
      'stopsCount': stopsCount,
      'departsAt': mskIso(16, hour),
      'arrivesAt': mskIso(16, hour + hours),
      'seats': seats,
      'parcelSize': parcelSize,
      'parcelOnly': kind == 'parcel',
      'parcelComment': ?parcelComment,
      'extras': extras,
      'passenger': passenger,
      'distanceKm': km,
      'status': 'open',
      'createdAt': '2026-05-14T10:00:00.000Z',
    };

/// Заказ Павла С.: два места и животные — под него подходят обе мои поездки 16 мая.
Map<String, Object?> pavelOrder() => orderCard(
      'o1',
      pavel(),
      number: 1301,
      from: stop(0, 'Ярославль', 'Улица Солнечная, дом 1'),
      to: stop(1, 'Москва', 'Улица Лунная, дом 2'),
      seats: 2,
      extras: const ['pets'],
    );

/// Лента «Заказы пассажиров»: Павел С. (поездка), Ольга Н. (посылка с комментарием), Алексей Р.
/// (поездка с остановкой, багажом и детским креслом).
List<Map<String, Object?>> driverOrdersFeed() => [
      pavelOrder(),
      orderCard(
        'o2',
        olga(phone: null),
        number: 1302,
        from: stop(0, 'Ярославль', 'Улица Свободы, дом 62'),
        to: stop(1, 'Москва', 'Проспект Мира, дом 10'),
        hour: 14,
        kind: 'parcel',
        seats: 0,
        parcelSize: 'M',
        parcelComment: 'Коробка с документами',
        km: 4.1,
      ),
      alexeyOrder(),
    ];

/// Заказ Алексея Р.: одно место, остановка в Ростове, багаж и детское кресло.
Map<String, Object?> alexeyOrder() => orderCard(
      'o3',
      alexey(phone: null),
      number: 1303,
      from: stop(0, 'Ярославль', 'Улица Садовая, дом 3'),
      to: stop(2, 'Москва', 'Улица Мира, дом 9'),
      hour: 16,
      extras: const ['luggage', 'child_seat'],
      stopsCount: 1,
      km: 5.0,
    );

/// Детали заказа Алексея Р.: весь маршрут с остановкой; подходит одна моя поездка — вечерняя (она
/// выбрана сама).
Map<String, Object?> alexeyOrderDetails() {
  final card = alexeyOrder();
  final trip = myEveningTrip();
  return {
    ...card,
    'stops': [card['from'], stop(1, 'Ростов', 'Улица Ленина, дом 5'), card['to']],
    'isMine': false,
    'matchingTrips': [
      {
        'trip': tripCard(trip),
        'fromIdx': 0,
        'toIdx': 3,
        'priceTotal': shotPriceTotal(trip, fromIdx: 0, toIdx: 3, seats: 1, services: const ['luggage', 'child_seat']),
      },
    ],
  };
}

/// Моя вторая поездка 16 мая — вечерняя, 18:00–22:00, 3 свободных места.
Map<String, Object?> myEveningTrip() => tripDetails(
      id: 't3',
      number: 1242,
      departsAt: mskIso(16, 18),
      arrivesAt: mskIso(16, 22),
      seatsTotal: 4,
      seatsFree: 3,
      driver: me(),
      isMine: true,
    );

/// Детали заказа Павла С. (`OrderDetails`) с моими подходящими поездками: сумма брони — формулой
/// сервера (отрезок всего маршрута × места + животные).
Map<String, Object?> pavelOrderDetails({bool withTrips = true}) {
  final card = pavelOrder();
  Map<String, Object?> match(Map<String, Object?> trip) => {
        'trip': tripCard(trip),
        'fromIdx': 0,
        'toIdx': 3,
        'priceTotal': shotPriceTotal(trip, fromIdx: 0, toIdx: 3, seats: 2, services: const ['pets']),
      };
  return {
    ...card,
    'stops': [card['from'], card['to']],
    'isMine': false,
    'matchingTrips': withTrips ? [match(myTrip()), match(myEveningTrip())] : <Object?>[],
  };
}
