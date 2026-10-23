import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/trip_new/data/trip_new_repository.dart';
import 'package:the_way/src/features/trip_new/steps/dashed_line.dart';
import 'package:the_way/src/features/trip_new/steps/route_step.dart';
import 'package:the_way/src/features/trip_new/steps/type_step.dart';
import 'package:the_way/src/features/trip_new/trip_created_screen.dart';
import 'package:the_way/src/features/trip_new/wizard_controller.dart';

import '../../support/gilroy.dart';
import 'support.dart';

/// Вёрстка по кадрам «Новый заказ - Тип заказа», «Новый заказ - Маршрут», «Новый заказ - Заказ создан». Настоящий Gilroy — иначе ширины
/// текста в тесте ничего не значат.
void main() {
  setUpAll(loadGilroy);

  // Плотность 2, как на снимках экранов: от неё зависят ширины букв Gilroy.
  void view(WidgetTester tester, double width, [double height = 812]) {
    tester.view.physicalSize = Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  WizardController draft() => WizardController(repositoryOf(FakeAdapter({})));

  group('«Новый заказ - Тип заказа» тип заказа', () {
    for (final width in [375.0, 360.0]) {
      testWidgets('карточки типа не переполняются на ширине ${width.toInt()}', (tester) async {
        view(tester, width);
        await tester.pumpWidget(app(TypeStep(controller: draft())));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    // Текст кадра остался у пассажира (мастер заказа); у водителя — «Везу пассажиров» (принятое решение 2026-10-22).
    testWidgets('подпись «Найти водителя для себя» — в одну строку, как в кадре', (tester) async {
      view(tester, 375);
      await tester.pumpWidget(app(TypeStep(controller: WizardController(repositoryOf(FakeAdapter({})), passengerOrder: true))));
      await tester.pump();
      expect(tester.getSize(find.text('Найти водителя для себя')).height, lessThan(24));
    });
  });

  group('«Новый заказ - Маршрут» маршрут', () {
    testWidgets('«Шаг N из 6» — справа с полем 16', (tester) async {
      view(tester, 375);
      await tester.pumpWidget(app(RouteStep(controller: draft())));
      await tester.pumpAndSettle(); // ответ на «Мои сохранённые маршруты» — иначе таймер Dio висит
      expect(tester.getTopRight(find.text('Шаг 2 из 6')).dx, 375 - 16);
    });

    testWidgets('«Добавить остановку» — слева, по ширине содержимого', (tester) async {
      view(tester, 375);
      await tester.pumpWidget(app(RouteStep(controller: draft())));
      await tester.pumpAndSettle(); // ответ на «Мои сохранённые маршруты» — иначе таймер Dio висит
      final button = find.ancestor(of: find.text('Добавить остановку'), matching: find.byType(InkWell)).first;
      expect(tester.getTopLeft(button).dx, 16);
      expect(tester.getSize(button).width, lessThan(200));
    });

    testWidgets('линия между «Откуда» и «Куда» — пунктирная, ряды ставят её на оба куска', (tester) async {
      view(tester, 375);
      await tester.pumpWidget(app(RouteStep(controller: draft())));
      await tester.pumpAndSettle(); // ответ на «Мои сохранённые маршруты» — иначе таймер Dio висит
      expect(find.byType(DashedLine), findsNWidgets(2));
    });

    testWidgets('пунктир: штрих 12, разрыв 12, толщина 2, цвет «text.secondary»', (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: SizedBox(height: 52, child: DashedLine())),
      ));
      final box = tester.renderObject(find.descendant(of: find.byType(DashedLine), matching: find.byType(CustomPaint)).first);
      expect(
        box,
        paints
          ..rect(rect: const Rect.fromLTWH(0, 0, 2, 12), color: const Color(0x800C0C0C))
          ..rect(rect: const Rect.fromLTWH(0, 24, 2, 12))
          ..rect(rect: const Rect.fromLTWH(0, 48, 2, 4)),
      );
    });
  });

  group('«Новый заказ - Заказ создан» «Заказ опубликован!»', () {
    late FakeAdapter adapter;
    late TripNewRepository repo;

    setUp(() {
      adapter = FakeAdapter({
        'GET /trips/limits': (o) => const FakeReply({'forwardUsed': 1, 'reverseUsed': 0, 'weekUsed': 1, 'weekLimit': 10, 'maxDaysAhead': 3}),
      });
      repo = repositoryOf(adapter);
    });

    Future<void> open(WidgetTester tester) async {
      view(tester, 375);
      await tester.pumpWidget(app(TripCreatedScreen(trip: TripDetails.fromJson(tripJson()), repository: repo)));
      await tester.pumpAndSettle();
    }

    testWidgets('вокруг галочки — искры', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('success_sparks')), findsOneWidget);
    });

    testWidgets('содержимое — по центру высоты, а не прижато к верху', (tester) async {
      await open(tester);
      expect(tester.getTopLeft(find.byKey(const Key('success_badge'))).dy, greaterThan(120));
    });

    testWidgets('заголовок карточки лимита — по центру', (tester) async {
      await open(tester);
      expect(tester.widget<Text>(find.text('Лимит публикаций')).textAlign, TextAlign.center);
    });
  });
}
