import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/onboarding/onboarding_images.dart';
import 'package:the_way/src/features/onboarding/onboarding_screen.dart';

import '../auth/fake_api.dart';

void main() {
  setUpAll(loadGilroy);

  testWidgets('splash → слайд 1 → слайд 2 → роль: выбор роли сохраняется и ведёт к выбору города', (tester) async {
    usePhone(tester);
    final session = fakeSession(FakeAdapter({}));
    await tester.pumpWidget(fakeApp(session, const OnboardingScreen()));

    expect(find.text('Попутчики и посылки по вашему маршруту'), findsOneWidget);
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Находите нужное направление'), findsOneWidget);

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Зарегистрируйтесь'), findsOneWidget);

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(find.textContaining('От чьего лица вы хотите'), findsOneWidget);
    expect(find.text('Продолжить'), findsNothing);

    await tester.tap(find.text('Водитель'));
    await tester.pumpAndSettle();
    expect(session.pendingMode, UserMode.driver);
    expect(session.onboardingDone, isFalse);
    expect(find.text('route:city_select'), findsOneWidget);
  });

  testWidgets('«Назад» системы на слайдах и роли — на предыдущую страницу, до заставки', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(fakeApp(fakeSession(FakeAdapter({})), const OnboardingScreen()));
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(find.textContaining('От чьего лица вы хотите'), findsOneWidget);

    for (final expected in ['Зарегистрируйтесь', 'Находите нужное направление', 'Попутчики и посылки по вашему маршруту']) {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.textContaining(expected), findsOneWidget, reason: 'после «Назад» — $expected');
    }
  });

  testWidgets('«Уже есть аккаунт» ведёт ко входу без выбора роли', (tester) async {
    usePhone(tester);
    final session = fakeSession(FakeAdapter({}));
    await tester.pumpWidget(fakeApp(session, const OnboardingScreen()));

    await tester.tap(find.text('Уже есть аккаунт'));
    await tester.pumpAndSettle();
    expect(find.text('route:auth'), findsOneWidget);
    expect(session.pendingMode, isNull);
    expect(session.onboardingDone, isFalse);
  });

  testWidgets('слайды 2 и 3: обводка карточки 3 px #f6f6f7; «Онбординг - Слайд 3»: фон #ededed, невыбранная карточка #f6f6f6', (tester) async {
    usePhone(tester);
    final session = fakeSession(FakeAdapter({}));
    await tester.pumpWidget(fakeApp(session, const OnboardingScreen()));
    final stroke = Border.all(color: const Color(0xFFF6F6F7), width: 3);
    bool hasStroke(Widget w) => w is Container && (w.foregroundDecoration as BoxDecoration?)?.border == stroke;

    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate(hasStroke), findsOneWidget); // «Онбординг - Слайд 2»

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate(hasStroke), findsOneWidget); // «Онбординг - Слайд 3»
    expect(find.byWidgetPredicate((w) => w is Container && (w.decoration as BoxDecoration?)?.color == const Color(0xFFEDEDED)), findsOneWidget);
    final passenger = tester.widget<Material>(find.ancestor(of: find.text('Пассажир'), matching: find.byType(Material)).first);
    expect(passenger.color, const Color(0xFFF6F6F6));
  });

  for (final width in [360.0, 411.0]) {
    testWidgets('слайд 1 («Онбординг - Слайд 1») — картинка по центру экрана шириной ${width.toInt}', (tester) async {
      tester.view
        ..physicalSize = Size(width, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(fakeApp(fakeSession(FakeAdapter({})), const OnboardingScreen()));
      await tester.tap(find.text('Начать'));
      await tester.pumpAndSettle();

      final picture = find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == OnboardingImages.slide1);
      expect(picture, findsOneWidget);
      expect(tester.getCenter(picture).dx, closeTo(width / 2, 0.5));
      expect(tester.getSize(picture).width, 378, reason: 'размер кадра 378×290 сохранён');
    });
  }
}
