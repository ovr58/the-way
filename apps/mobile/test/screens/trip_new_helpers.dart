import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/app.dart';
import 'package:the_way/src/features/trip_new/data/trip_new_repository.dart';
import 'package:the_way/src/features/trip_new/moscow_time.dart';
import 'package:the_way/src/features/trip_new/wizard_controller.dart';

import 'shot.dart';
import 'world.dart';

/// Три остановки мастера («Новый заказ - кол-во пассажиров» – «Экран для отключенной монетизации», «Редактирование - Изменений нет», «Редактирование - Изменения есть»): Ярославль → Ростов → Москва — тот же край, что лента и
/// список городов, а не «Минск → Могилёв» кадров.
final tripAddresses = [suggestions[0], suggestions[2], suggestions[4]];

/// День поездки мастера и правки — завтра по Москве: поездка в прошлом не публикуется (сервер «Отправление
/// в прошлом», календарь прошлых дней не даёт), поэтому дата кадра «04.06.2026» в снимок не идёт.
DateTime tripDay() {
  final today = moscowToday();
  return DateTime(today.year, today.month, today.day + 1);
}

/// Выезд 8:00, прибытие 12:00 (в кадре «8:00 → 8:00»).
const departAt = TimeOfDay(hour: 8, minute: 0);
const arriveAt = TimeOfDay(hour: 12, minute: 0);

/// Черновик мастера с остановками [tripAddresses] (при `stops: 2` — первая и последняя).
WizardController draft(ShotWorld world, {bool times = true, int stops = 3}) {
  final c = WizardController(TripNewRepository(world.session.api));
  while (c.stops.length < stops) {
    c.addStop();
  }
  for (var i = 0; i < c.stops.length; i++) {
    final a = i == c.stops.length - 1 ? tripAddresses.last : tripAddresses[i];
    c.setStopFromSuggestion(i, GeoSuggestion.fromJson(a));
  }
  if (times) {
    c
      ..setDate(tripDay())
      ..setDepartTime(departAt)
      ..setArriveTime(arriveAt)
      ..setSeats(4);
  }
  return c;
}

/// Открывает [screen] поверх приложения.
Future<void> push(WidgetTester tester, Widget screen) async {
  navigatorKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => screen));
  await tester.pump();
  shotTake(tester);
  await shotSettle(tester);
}
