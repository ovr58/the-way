import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:the_way/src/features/trip_new/moscow_time.dart';
import 'package:the_way/src/features/trip_new/return_trip_screen.dart';
import 'package:the_way/src/features/trip_new/trip_created_screen.dart';
import 'package:the_way/src/widgets/app_button.dart';

import 'support.dart';

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<InkWell>(find.widgetWithText(InkWell, label)).onTap != null;

void main() {
  group('ReturnTripScreen («Обратное направление», «Обратное направление - Дата и время выставлены», «Обратное направление», «Обратное направление - Заказ создан»)', () {
    testWidgets('остановки в обратном порядке; дата и время → POST /reverse → итог «Обратное направление - Заказ создан»', (tester) async {
      tallView(tester);
      final adapter = FakeAdapter({
        'GET /trips/trip1': (o) => FakeReply(tripJson()),
        'POST /trips/trip1/reverse': (o) => FakeReply(tripJson(id: 'trip2', reverseOf: 'trip1')),
        'GET /trips/limits': (o) => const FakeReply({'forwardUsed': 1, 'reverseUsed': 1, 'weekUsed': 2, 'weekLimit': 10, 'maxDaysAhead': 3}),
      });
      await tester.pumpWidget(app(ReturnTripScreen(tripId: 'trip1', repository: repositoryOf(adapter))));
      await tester.pumpAndSettle();
      expect(find.text('Обратное направление'), findsOneWidget);
      final texts = tester.widgetList<TextField>(find.byType(TextField)).map((f) => f.controller!.text).take(3).toList();
      expect(texts, ['Углич, Рынок', 'Рыбинск, Центр', 'Ярославль, Победы 1']);
      expect(_enabled(tester, 'Опубликовать поездку'), isFalse);

      await tapField(tester, 'Дата');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Выбрать дату'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tapField(tester, 'Время', index: i);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(AppButton, 'Выбрать время'));
        await tester.pumpAndSettle();
      }
      expect(_enabled(tester, 'Опубликовать поездку'), isTrue);
      await tester.tap(find.widgetWithText(AppButton, 'Опубликовать поездку'));
      await tester.pumpAndSettle();
      expect(find.text('Опубликовать поездку?'), findsOneWidget);
      // Участки обратной: исходные Ярославль → Рыбинск 500 и Рыбинск → Углич 700 в обратном порядке.
      await tester.tap(find.text('Смотреть стоимость'));
      await tester.pumpAndSettle();
      expect(find.text('Углич, Рынок - Рыбинск, Центр'), findsOneWidget);
      expect(find.text('Рыбинск, Центр - Ярославль, Победы 1'), findsOneWidget);
      expect(find.text('700 ₽'), findsOneWidget);
      expect(find.text('500 ₽'), findsOneWidget);
      await tester.tap(find.text('Да, опубликовать'));
      await tester.pumpAndSettle();
      final body = adapter.callsTo('POST /trips/trip1/reverse').single.data as Map<String, dynamic>;
      expect(body.keys, containsAll(['departsAt', 'arrivesAt']));
      expect(find.text('Заказ опубликован!'), findsOneWidget);
      expect(find.text('Мои заказы'), findsOneWidget);
      expect(find.text('Добавить обратный маршрут'), findsNothing);
      // «Обратное направление - Заказ создан»: шкалы «Сегодня 2/2 · На неделе 2/10», как нарисованы; неделя заполнена на 2/10.
      expect(find.text('4 июня'), findsOneWidget, reason: 'подпись суточной шкалы — день выезда');
      expect(find.text('Сегодня'), findsNothing);
      expect(find.text('2/2'), findsOneWidget);
      expect(find.text('На неделе'), findsOneWidget);
      expect(find.text('2/10'), findsOneWidget);
      expect(tester.widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox)).map((b) => b.widthFactor), [1, 0.2]);
    });

    testWidgets('промежуточная точка обратной поездки подписана «Остановка», как в прямой', (tester) async {
      tallView(tester);
      final adapter = FakeAdapter({'GET /trips/trip1': (o) => FakeReply(tripJson())});
      await tester.pumpWidget(app(ReturnTripScreen(tripId: 'trip1', repository: repositoryOf(adapter))));
      await tester.pumpAndSettle();
      expect(find.text('Точка посадки'), findsOneWidget, reason: 'первая точка');
      expect(find.text('Остановка'), findsOneWidget, reason: 'промежуточная');
      expect(find.text('Пункт назначения'), findsOneWidget, reason: 'последняя');
    });

    testWidgets('итог «Обратное направление - Заказ создан»: выезд сегодня — суточная шкала «Сегодня», выезд завтра — «<число> <месяц>»',
        (tester) async {
      tallView(tester);
      final adapter = FakeAdapter({
        'GET /trips/limits': (o) => const FakeReply({'forwardUsed': 1, 'reverseUsed': 1, 'weekUsed': 2, 'weekLimit': 10, 'maxDaysAhead': 3}),
      });
      Future<void> show(DateTime day) async {
        // Полдень по Москве выбранного дня — тот же московский день, что и в приложении.
        final departs = DateTime.utc(day.year, day.month, day.day, 9).toIso8601String();
        final trip = TripDetails.fromJson(tripJson(id: 'trip2', reverseOf: 'trip1', departsAt: departs));
        await tester.pumpWidget(app(TripCreatedScreen(key: ValueKey(day), trip: trip, repository: repositoryOf(adapter))));
        await tester.pumpAndSettle();
      }

      final today = moscowToday();
      await show(today);
      expect(find.text('Сегодня'), findsOneWidget);

      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      await show(tomorrow);
      expect(find.text('Сегодня'), findsNothing);
      expect(find.text(DateFormat('d MMMM', 'ru').format(tomorrow)), findsOneWidget);
    });

    testWidgets('403 blocked на POST /reverse: окно закрыто, подсказки нет (отказ показывает экран блокировки)',
        (tester) async {
      tallView(tester);
      final adapter = FakeAdapter({
        'GET /trips/trip1': (o) => FakeReply(tripJson()),
        'POST /trips/trip1/reverse': (o) => const FakeReply({'code': 'blocked', 'message': 'x'}, 403),
        'GET /trips/limits': (o) => const FakeReply({'forwardUsed': 1, 'reverseUsed': 1, 'weekUsed': 2, 'weekLimit': 10, 'maxDaysAhead': 3}),
      });
      await tester.pumpWidget(app(ReturnTripScreen(tripId: 'trip1', repository: repositoryOf(adapter))));
      await tester.pumpAndSettle();
      await tapField(tester, 'Дата');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Выбрать дату'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tapField(tester, 'Время', index: i);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(AppButton, 'Выбрать время'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.widgetWithText(AppButton, 'Опубликовать поездку'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Да, опубликовать'));
      await tester.pumpAndSettle();

      expect(adapter.callsTo('POST /trips/trip1/reverse'), hasLength(1));
      expect(find.text('Опубликовать поездку?'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
