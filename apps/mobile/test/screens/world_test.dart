import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'world.dart';

RequestOptions _get(String path, Map<String, Object?> query) => RequestOptions(path: path, queryParameters: query);

/// Подставной сервер снимков считает так же, как настоящий (`apps/api/.../bookings/internal/pricing.ts`):
/// иначе на снимке «Итого» не меняется от услуг («Бронирование - С доп услугами»), а цены соседних экранов спорят друг с другом.
void main() {
  group('цена брони — формула сервера', () {
    final trip = viktorTrip();

    test('отрезок: весь маршрут — цена поездки, иначе сумма участков; обратного нет', () {
      expect(shotSegPrice(trip, 0, 3), 1200);
      expect(shotSegPrice(trip, 0, 1), 400);
      expect(shotSegPrice(trip, 2, 3), 400);
      expect(shotSegPrice(trip, 1, 2), 400);
      expect(shotSegPrice(trip, 0, 2), 800);
      expect(shotSegPrice(trip, 2, 1), isNull);
    });

    test('итог: отрезок × места + услуги + размер посылки', () {
      expect(shotPriceTotal(trip, fromIdx: 0, toIdx: 3, seats: 1, services: ['luggage', 'pets']), 1500);
      expect(shotPriceTotal(trip, fromIdx: 0, toIdx: 1, seats: 1, services: ['pets']), 550);
      expect(shotPriceTotal(trip, fromIdx: 0, toIdx: 3, seats: 0, parcelSize: 'S'), 150);
      expect(shotPriceTotal(trip, fromIdx: 0, toIdx: 3, seats: 2), 2400);
    });

    test('цены — участки соседних точек, как требует сервер', () {
      final pairs = [for (final p in (trip['prices']! as List).cast<Map<String, Object?>>()) '${p['fromIdx']}:${p['toIdx']}'];
      expect(pairs, ['0:1', '1:2', '2:3']);
    });

    test('ответ quote считается по запросу: услуги меняют итог', () {
      final quote = quoteRoute(trip);
      expect(quote(_get('/trips/t1/quote', {'fromIdx': 0, 'toIdx': 3, 'seats': 1})), {'segmentPrice': 1200, 'priceTotal': 1200});
      expect(quote(_get('/trips/t1/quote', {'fromIdx': 0, 'toIdx': 3, 'seats': 1, 'extras': 'luggage,pets'})),
          {'segmentPrice': 1200, 'priceTotal': 1500});
      expect(quote(_get('/trips/t1/quote', {'fromIdx': 0, 'toIdx': 3, 'seats': 0, 'parcelSize': 'S'})),
          {'segmentPrice': 1200, 'priceTotal': 150});
    });
  });

  group('данные одного сценария', () {
    test('бронь несёт цену по формуле, оплата водителя и занятые места — из броней', () {
      final b = booking(trip: viktorTrip(), fromIdx: 0, toIdx: 1, services: ['pets']);
      expect(b['segmentPrice'], 400);
      expect(b['priceTotal'], 550);

      final paid = [
        booking(id: 'b1', trip: myTrip(), status: 'paid', seats: 1),
        booking(id: 'b2', trip: myTrip(), status: 'awaiting_payment', seats: 2),
      ];
      final t = myTrip(bookings: paid);
      expect((t['seatsTotal']! as int) - (t['seatsFree']! as int), 1); // места занимает только оплата
      expect(t['paidTotal'], 1200);
      expect(t['editLocked'], isTrue); // есть бронь «ждёт оплаты» или «оплачено»
      final empty = myTrip();
      expect(empty['paidTotal'], 0);
      expect(empty['seatsFree'], empty['seatsTotal']);
      expect(empty['editLocked'], isFalse);
    });

    test('подсказки адреса — по набранному тексту', () {
      final suggest = suggestRoute();
      final found = suggest(_get('/geo/suggest', {'q': 'Ленин'})) as List<Object?>;
      expect(found, isNotEmpty);
      for (final s in found.cast<Map<String, Object?>>()) {
        expect((s['label']! as String).toLowerCase(), contains('ленин'));
      }
    });
  });
}
