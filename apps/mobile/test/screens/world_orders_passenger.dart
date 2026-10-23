import 'package:api_client/api_client.dart';
import 'package:the_way/src/features/trip_new/data/trip_new_repository.dart';
import 'package:the_way/src/features/trip_new/wizard_controller.dart';

import 'trip_new_helpers.dart';
import 'world.dart';

/// Заказы пассажира в мире снимков `ord-p-*` (план `passenger-order_2026-10-22.md`, Б2.5). Я — пассажир
/// Анастасия; заказы — того же края, что лента и мастер (Ярославль → Ростов → Москва), после моей брони
/// на поездке Виктора О. (`myBooking`, создана 14 мая).

/// Точки заказа: «Улица Солнечная, дом 1 → Улица Ленина, дом 5 → Улица Лунная, дом 2».
final orderStops = [routeStops[0], routeStops[1], {...routeStops[3], 'idx': 2}];

/// Мой заказ: на 20 мая, выезд 09:00, прибытие ~13:00, 2 места, с животными и багажом; ищем водителя.
Map<String, Object?> myOrder({String status = 'open'}) => order(id: 'o1', number: 1240, status: status);

/// Мой заказ-посылка: 18 мая, 10:00–14:00, размер M, «Документы».
Map<String, Object?> myParcelOrder() => order(
      id: 'o2',
      number: 1238,
      kind: 'parcel',
      seats: 0,
      parcelSize: 'M',
      parcelComment: 'Документы',
      services: const [],
      day: 18,
      hour: 10,
      createdDay: 15,
    );

Map<String, Object?> order({
  required String id,
  required int number,
  String status = 'open',
  String kind = 'ride',
  int seats = 2,
  String parcelSize = 'none',
  String? parcelComment,
  List<String> services = const ['pets', 'luggage'],
  int day = 20,
  int hour = 9,
  int createdDay = 16,
}) =>
    {
      'id': id,
      'number': number,
      'kind': kind,
      'from': orderStops.first,
      'to': orderStops.last,
      'stopsCount': orderStops.length - 2,
      'departsAt': mskIso(day, hour),
      'arrivesAt': mskIso(day, hour + 4),
      'seats': seats,
      'parcelSize': parcelSize,
      'parcelOnly': kind == 'parcel',
      'parcelComment': ?parcelComment,
      'extras': services,
      'passenger': me(),
      'status': status,
      'createdAt': mskIso(createdDay, 10),
      'stops': orderStops,
      'isMine': true,
      'matchingTrips': <Object?>[],
    };

/// Черновик мастера заказа: Ярославль → Ростов → Москва, завтра 8:00–12:00, 2 места.
WizardController orderDraft(ShotWorld world, {TripKind kind = TripKind.ride}) {
  final c = WizardController(TripNewRepository(world.session.api), passengerOrder: true)..setKind(kind);
  c.addStop();
  for (var i = 0; i < c.stops.length; i++) {
    c.setStopFromSuggestion(i, GeoSuggestion.fromJson(tripAddresses[i]));
  }
  c
    ..setDate(tripDay())
    ..setDepartTime(departAt)
    ..setArriveTime(arriveAt);
  if (kind == TripKind.ride) c.setSeats(2);
  return c;
}
