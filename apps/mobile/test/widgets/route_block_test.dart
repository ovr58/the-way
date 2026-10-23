import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/l10n/app_localizations.dart';
import 'package:the_way/src/features/search/details/route_block.dart';
import 'package:the_way/src/theme/app_colors.dart';
import 'package:the_way/src/theme/app_theme.dart';
import 'package:the_way/src/widgets/app_icon.dart';

/// Показ адреса — «Город, улица»; город фикстур один.
Stop _stop(int idx, String address) => Stop(idx: idx, cityId: idx + 1, cityName: 'Город', address: address, shortAddress: address);

Widget _app(List<Stop> stops) => MaterialApp(
      theme: buildTheme(),
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: SingleChildScrollView(child: RouteBlock(stops: stops))),
    );

/// Серые круги 6×6 — точки промежуточных остановок («Детали поездки - Места есть»).
Finder get _dots => find.byWidgetPredicate((w) {
      if (w is! Container) return false;
      final d = w.decoration;
      return d is BoxDecoration &&
          d.shape == BoxShape.circle &&
          d.color == AppColors.textSecondary &&
          w.constraints?.maxWidth == 6;
    });

void main() {
  const chip = Key('route_stops_chip');

  testWidgets('две остановки: по нажатию кнопка исчезает, на её месте два пункта с точками и линией', (tester) async {
    await tester.pumpWidget(_app([_stop(0, 'Старт'), _stop(1, 'Улица Ленина'), _stop(2, 'Улица Пушкина'), _stop(3, 'Финиш')]));
    expect(find.byKey(chip), findsOneWidget);
    expect(find.text('2 остановки'), findsOneWidget);
    expect(find.text('Город, Улица Ленина'), findsNothing);
    expect(_dots, findsOneWidget); // точка при кнопке

    await tester.tap(find.byKey(chip));
    await tester.pumpAndSettle();

    expect(find.byKey(chip), findsNothing);
    expect(find.text('2 остановки'), findsNothing);
    expect(find.text('Город, Улица Ленина'), findsOneWidget);
    expect(find.text('Город, Улица Пушкина'), findsOneWidget);
    expect(_dots, findsNWidgets(2));
    // Порядок сверху вниз: старт, остановки, финиш.
    final ys = ['Старт', 'Улица Ленина', 'Улица Пушкина', 'Финиш']
        .map((t) => tester.getTopLeft(find.text('Город, $t')).dy)
        .toList();
    expect(ys, [...ys]..sort());
  });

  testWidgets('одна остановка: один пункт на месте кнопки', (tester) async {
    await tester.pumpWidget(_app([_stop(0, 'Старт'), _stop(1, 'Улица Ленина'), _stop(2, 'Финиш')]));
    expect(find.text('1 остановка'), findsOneWidget);
    await tester.tap(find.byKey(chip));
    await tester.pumpAndSettle();
    expect(find.byKey(chip), findsNothing);
    expect(find.text('Город, Улица Ленина'), findsOneWidget);
    expect(_dots, findsOneWidget);
  });

  // раскрытие плавное — высота и прозрачность; кнопка перетекает в круглую со стрелкой вверх и уезжает
  // вправо от списка; обратное нажатие возвращает «N остановки ⌄» на прежнее место.
  const collapse = Key('route_stops_collapse');
  final four = [_stop(0, 'Старт'), _stop(1, 'Улица Ленина'), _stop(2, 'Улица Пушкина'), _stop(3, 'Финиш')];

  testWidgets('раскрытие плавное — на середине высота между свёрнутой и раскрытой, список полупрозрачный', (tester) async {
    await tester.pumpWidget(_app(four));
    final block = find.byType(RouteBlock);
    final collapsedH = tester.getSize(block).height;

    await tester.tap(find.byKey(chip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 175));
    final midH = tester.getSize(block).height;
    final fade = tester.widgetList<FadeTransition>(
      find.ancestor(of: find.text('Город, Улица Ленина'), matching: find.byType(FadeTransition)),
    );
    expect(fade.any((f) => f.opacity.value > 0 && f.opacity.value < 1), isTrue, reason: 'прозрачность в пути');

    await tester.pumpAndSettle();
    final expandedH = tester.getSize(block).height;
    expect(midH, greaterThan(collapsedH));
    expect(midH, lessThan(expandedH));
  });

  testWidgets('раскрыто — круглая кнопка со стрелкой вверх без текста, справа от списка остановок', (tester) async {
    await tester.pumpWidget(_app(four));
    await tester.tap(find.byKey(chip));
    await tester.pumpAndSettle();

    final button = find.byKey(collapse);
    expect(button, findsOneWidget);
    expect(find.descendant(of: button, matching: find.byType(Text)), findsNothing);
    // Стрелка — та же «вниз», повёрнутая на пол-оборота: поворот виден в пути, а не подменой значка.
    final rotation = tester.widget<Transform>(
      find.ancestor(of: find.descendant(of: button, matching: find.byType(AppIcon)), matching: find.byType(Transform)).first,
    );
    expect(rotation.transform.getRotation().entry(0, 0), closeTo(-1, 1e-9), reason: 'повёрнута на 180°');
    final box = tester.getRect(button);
    expect(box.width, box.height, reason: 'круг');
    expect(box.right, closeTo(tester.getRect(find.byType(RouteBlock)).right, 0.5), reason: 'у правого края');
    for (final t in ['Улица Ленина', 'Улица Пушкина']) {
      expect(tester.getRect(find.text('Город, $t')).right, lessThanOrEqualTo(box.left), reason: 'список левее кнопки');
    }
  });

  testWidgets('одно движение 350 мс easeInOut — на середине кнопка уже уже, текст полупрозрачен, стрелка повёрнута наполовину', (tester) async {
    await tester.pumpWidget(_app(four));
    final width0 = tester.getSize(find.byKey(chip)).width;
    await tester.tap(find.byKey(chip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 175));
    final toggle = find.byKey(collapse);
    final midWidth = tester.getSize(toggle).width;
    expect(midWidth, lessThan(width0));
    expect(midWidth, greaterThan(tester.getSize(toggle).height));
    final label = tester.widget<Opacity>(find.ancestor(of: find.text('2 остановки'), matching: find.byType(Opacity)).first);
    expect(label.opacity, closeTo(0.5, 0.1));
    final angle = tester.widget<Transform>(
      find.ancestor(of: find.descendant(of: toggle, matching: find.byType(AppIcon)), matching: find.byType(Transform)).first,
    ).transform.getRotation().entry(0, 0);
    expect(angle, closeTo(0, 0.2), reason: 'cos 90° — поворот на полпути');
    await tester.pump(const Duration(milliseconds: 155));
    expect(tester.hasRunningAnimations, isTrue, reason: '330 мс — ещё в пути');
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.hasRunningAnimations, isFalse, reason: '370 мс — на месте (допуск — кадр)');
  });

  testWidgets('круглая кнопка — обратно: список свёрнут, «2 остановки ⌄» на прежнем месте', (tester) async {
    await tester.pumpWidget(_app(four));
    final before = tester.getTopLeft(find.byKey(chip));
    final collapsedH = tester.getSize(find.byType(RouteBlock)).height;
    await tester.tap(find.byKey(chip));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(collapse));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 175));
    expect(tester.getSize(find.byType(RouteBlock)).height, greaterThan(collapsedH), reason: 'сворачивается плавно');
    await tester.pumpAndSettle();

    expect(find.text('Город, Улица Ленина'), findsNothing);
    expect(find.text('2 остановки'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(chip)), before);
    expect(tester.getSize(find.byType(RouteBlock)).height, collapsedH);
  });

  testWidgets('без промежуточных остановок кнопки нет', (tester) async {
    await tester.pumpWidget(_app([_stop(0, 'Старт'), _stop(1, 'Финиш')]));
    expect(find.byKey(chip), findsNothing);
    expect(find.text('Город, Старт'), findsOneWidget);
    expect(find.text('Город, Финиш'), findsOneWidget);
  });
}
