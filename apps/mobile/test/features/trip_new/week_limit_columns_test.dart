import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/trip_new/limit_screen.dart';
import 'package:the_way/src/features/trip_new/trip_created_screen.dart';

import '../../support/gilroy.dart';
import 'support.dart';

/// на «Обратное направление - Заказ создан» шкалы дня и недели — две колонки рядом, промежуток 20 (кадр: `order-info`, `flex row gap 20`);
/// «Новый заказ - Заказ создан» и обычный «Новый заказ - Маршрут сохранен» — столбиком.
void main() {
  // Без шрифта кадра тестовые буквы шире настоящих и подписи в колонке 145 переносятся.
  setUpAll(loadGilroy);

  void phoneView(WidgetTester tester) {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  FakeAdapter limits({int forward = 1, int reverse = 1, int week = 3}) => FakeAdapter({
        'GET /trips/limits': (o) => FakeReply(
            {'forwardUsed': forward, 'reverseUsed': reverse, 'weekUsed': week, 'weekLimit': 10, 'maxDaysAhead': 3}),
      });

  Rect bar(WidgetTester tester, int i) => tester.getRect(find.byType(ClipRRect).at(i));

  testWidgets('«Обратное направление - Заказ создан»: «день выезда N/2» слева и «На неделе N/10» справа — колонки поровну, промежуток 20', (tester) async {
    phoneView(tester);
    final trip = TripDetails.fromJson(tripJson(id: 'trip2', reverseOf: 'trip1'));
    await tester.pumpWidget(app(TripCreatedScreen(trip: trip, repository: repositoryOf(limits()))));
    await tester.pumpAndSettle();

    final day = tester.getRect(find.text('4 июня'));
    final week = tester.getRect(find.text('На неделе'));
    expect(week.top, day.top, reason: 'подписи на одной строке');
    expect(week.left, greaterThan(day.right));
    final left = bar(tester, 0);
    final right = bar(tester, 1);
    expect(right.top, left.top);
    expect(left.width, right.width, reason: 'колонки поровну');
    expect(right.left - left.right, 20);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('3/10'), findsOneWidget);
  });

  testWidgets('«Новый заказ - Заказ создан»: «Туда / Обратно» — столбиком, как в кадре', (tester) async {
    phoneView(tester);
    final trip = TripDetails.fromJson(tripJson());
    await tester.pumpWidget(app(TripCreatedScreen(trip: trip, repository: repositoryOf(limits(reverse: 0)))));
    await tester.pumpAndSettle();
    final first = bar(tester, 0);
    final second = bar(tester, 1);
    expect(second.left, first.left);
    expect(second.top, greaterThan(first.bottom));
  });

  Future<void> openLimit(WidgetTester tester, FakeAdapter adapter) async {
    await tester.pumpWidget(app(LimitScreen(
      repository: repositoryOf(adapter),
      carId: 'car1',
      date: DateTime(2026, 6, 4),
      onCancel: () {},
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('«Новый заказ - Маршрут сохранен» (лимит суток): «Туда / Обратно» — столбиком, как в кадре', (tester) async {
    phoneView(tester);
    await openLimit(tester, limits());
    expect(find.text('Туда'), findsOneWidget);
    final first = bar(tester, 0);
    final second = bar(tester, 1);
    expect(second.left, first.left);
    expect(second.top, greaterThan(first.bottom));
  });

  testWidgets('«Новый заказ - Маршрут сохранен» (лимит недели, кадра нет): шкалы дня и недели рядом, как на «Обратное направление - Заказ создан»', (tester) async {
    phoneView(tester);
    await openLimit(tester, limits(week: 10));
    expect(find.text('На неделе'), findsOneWidget);
    final left = bar(tester, 0);
    final right = bar(tester, 1);
    expect(right.top, left.top);
    expect(left.width, right.width);
    expect(right.left - left.right, 20);
  });
}
