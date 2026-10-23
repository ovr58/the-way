import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/shot.dart';
import '../screens/world.dart';

/// Пара плашек «Дата и время | Мест для пассажиров» (тема equal-tiles): в кадрах «Детали поездки - Скролл», «Поездка завершена» обе 170×58,
/// белый блок во всю ширину экрана с полями 16; подпись в одну строку. Когда подпись всё же
/// переносится (узкий экран, крупный шрифт), обе плашки тянутся по высоте большей.
void main() {
  shotInit();

  Rect tile(WidgetTester tester, String label) =>
      tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(Container)).first);

  // Подпись мест: у водителя «Мест для пассажиров»; в деталях брони пассажира — «Мест свободно» (принятое решение
  // 2026-10-22).
  void expectPair(WidgetTester tester, {String seats = 'Мест для пассажиров'}) {
    final left = tile(tester, 'Дата и время');
    final right = tile(tester, seats);
    expect(left.width, closeTo(169.5, 0.6));
    expect(right.width, closeTo(169.5, 0.6));
    expect(left.height, right.height);
    expect(left.height, 58);
    expect(left.top, right.top);
  }

  testWidgets('«Поездка завершена» детали поездки водителя: плашки 170×58, равной высоты', (tester) async {
    shotSurface(tester, height: 882);
    final world = ShotWorld(mode: UserMode.driver)
      ..routes['GET /trips/t1'] = tripDetails(isMine: true, seatsTotal: 4, seatsFree: 2, carJson: myCars.first, paidTotal: 600)
      ..routes['GET /trips/t1/bookings'] = <Object?>[];
    await world.open(tester, route: 'driver_trips/details', args: 't1');
    expectPair(tester);
    debugDisableShadows = true; // shotSettle включает тени; проверка среды в конце теста ждёт исходное
  });

  testWidgets('«Детали поездки - Скролл» детали брони пассажира: плашки 170×58, равной высоты', (tester) async {
    shotSurface(tester);
    final world = ShotWorld()
      ..routes['GET /bookings/b1'] = booking(status: 'paid')
      ..routes['GET /trips/t1'] = tripDetails(seatsTotal: 4, seatsFree: 2, carJson: myCars.first);
    await world.open(tester, route: 'passenger_trips/details', args: 'b1');
    expectPair(tester, seats: 'Мест свободно');
    debugDisableShadows = true; // shotSettle включает тени; проверка среды в конце теста ждёт исходное
  });
}
