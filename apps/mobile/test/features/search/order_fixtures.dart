import '../../support/fake_api.dart';

/// Пассажир заказа — не «Виктор О.» водителя.
Map<String, Object?> passengerJson() => {
      'id': 'p1',
      'name': 'Павел С.',
      'rating': {'value': 4.8, 'count': 5},
      'tripsCount': 12,
    };

/// Карточка заказа пассажира (`OrderCard`): поездка на 2 места, Ярославль → Москва, выезд 22.10 в 09:00 МСК.
Map<String, Object?> orderCardJson({
  String id = 'o1',
  String from = 'Улица Солнечная, дом 1',
  String to = 'Улица Лунная, дом 2',
  String kind = 'ride',
  int seats = 2,
  String parcelSize = 'none',
  String? parcelComment,
  List<String> extras = const ['pets'],
  int stopsCount = 0,
}) =>
    {
      'id': id,
      'number': 31,
      'kind': kind,
      'from': stopJson(0, from),
      'to': stopJson(1, to),
      'stopsCount': stopsCount,
      'departsAt': '2026-10-22T06:00:00.000Z',
      'arrivesAt': '2026-10-22T11:00:00.000Z',
      'seats': seats,
      'parcelSize': parcelSize,
      'parcelOnly': kind == 'parcel',
      'parcelComment': parcelComment,
      'extras': extras,
      'passenger': passengerJson(),
      'distanceKm': 3.2,
      'status': 'open',
      'createdAt': '2026-10-21T10:00:00.000Z',
    };

/// Детали заказа (`OrderDetails`) с подходящими поездками водителя [matching] (id поездок).
Map<String, Object?> orderDetailsJson({
  String id = 'o1',
  List<String> matching = const ['t1', 't2'],
  String kind = 'ride',
  int seats = 2,
  String parcelSize = 'none',
  String? parcelComment,
  List<String> extras = const ['pets'],
  List<String> middle = const [],
}) {
  final card = orderCardJson(
    id: id,
    kind: kind,
    seats: seats,
    parcelSize: parcelSize,
    parcelComment: parcelComment,
    extras: extras,
    stopsCount: middle.length,
  );
  final last = middle.length + 1;
  return {
    ...card,
    'to': stopJson(last, 'Улица Лунная, дом 2'),
    'stops': [
      card['from'],
      for (var i = 0; i < middle.length; i++) stopJson(i + 1, middle[i]),
      stopJson(last, 'Улица Лунная, дом 2'),
    ],
    'isMine': false,
    'matchingTrips': [
      for (var i = 0; i < matching.length; i++)
        {
          'trip': {...tripCardJson(id: matching[i]), 'number': 7 + i},
          'fromIdx': 0,
          'toIdx': 3,
          'priceTotal': 2500 + 100 * i,
        },
    ],
  };
}
