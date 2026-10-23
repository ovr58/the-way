import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/theme/app_colors.dart';
import 'package:the_way/src/widgets/app_switch.dart';

/// Ручка переключателя — круг 18.
Finder get _knob => find.byWidgetPredicate((w) {
      if (w is! Container) return false;
      final d = w.decoration;
      return d is BoxDecoration && d.shape == BoxShape.circle;
    });

Widget _app({bool disableAnimations = false}) {
  var on = false;
  return MaterialApp(
    builder: (context, child) =>
        MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations), child: child!),
    home: Scaffold(
      body: Center(
        child: StatefulBuilder(
          builder: (context, setState) => AppSwitch(value: on, onChanged: (v) => setState(() => on = v)),
        ),
      ),
    ),
  );
}

/// Цвет дорожки, как он нарисован сейчас.
Color _track(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(find.byType(AppSwitch));
  final decorated = find.descendant(of: find.byType(AppSwitch), matching: find.byType(DecoratedBox)).evaluate().map((e) => e.widget as DecoratedBox);
  expect(box.hasSize, isTrue);
  return (decorated.first.decoration as BoxDecoration).color!;
}

void main() {
  testWidgets('ручка едет плавно, цвет дорожки перетекает; итог — как в макете', (tester) async {
    await tester.pumpWidget(_app());
    final start = tester.getCenter(_knob).dx;
    expect(_track(tester), AppColors.bgSurfaceAlt);

    await tester.tap(find.byType(AppSwitch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final mid = tester.getCenter(_knob).dx;
    final midTrack = _track(tester);

    await tester.pumpAndSettle();
    final end = tester.getCenter(_knob).dx;
    expect(mid, greaterThan(start));
    expect(mid, lessThan(end));
    expect(midTrack, isNot(AppColors.bgSurfaceAlt));
    expect(midTrack, isNot(AppColors.accentPrimary));
    expect(_track(tester), AppColors.accentPrimary);

    await tester.tap(find.byType(AppSwitch));
    await tester.pumpAndSettle();
    expect(tester.getCenter(_knob).dx, start);
    expect(_track(tester), AppColors.bgSurfaceAlt);
  });

  // Принятое решение 2026-10-22: 300 мс, easeInOut.
  testWidgets('длительность — 300 мс, кривая easeInOut', (tester) async {
    await tester.pumpWidget(_app());
    final start = tester.getCenter(_knob).dx;
    await tester.tap(find.byType(AppSwitch));
    await tester.pump();
    await tester.pumpAndSettle();
    final end = tester.getCenter(_knob).dx;

    await tester.tap(find.byType(AppSwitch));
    await tester.pump();
    double progress() => (end - tester.getCenter(_knob).dx) / (end - start);
    await tester.pump(const Duration(milliseconds: 75)); // четверть времени: разгон — путь меньше линейного
    expect(progress(), lessThan(0.2));
    await tester.pump(const Duration(milliseconds: 75)); // половина времени: easeInOut симметрична — полпути
    expect(progress(), closeTo(0.5, 0.06));
    // Допуск — кадр: тикер стартует кадром после нажатия.
    await tester.pump(const Duration(milliseconds: 130));
    expect(tester.hasRunningAnimations, isTrue, reason: '280 мс — ещё в пути');
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.hasRunningAnimations, isFalse, reason: '320 мс — на месте');
  });

  testWidgets('неактивный тумблер выглядит как прежде и не двигается', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: AppSwitch(value: false, onChanged: null)))));
    final start = tester.getCenter(_knob).dx;
    expect(_track(tester), AppColors.bgSurfaceAlt);
    await tester.tap(find.byType(AppSwitch));
    await tester.pumpAndSettle();
    expect(tester.getCenter(_knob).dx, start);
    expect(_track(tester), AppColors.bgSurfaceAlt);
  });

  testWidgets('движение и при отключённых анимациях системы (reduce-motion не выключает)', (tester) async {
    await tester.pumpWidget(_app(disableAnimations: true));
    final start = tester.getCenter(_knob).dx;
    await tester.tap(find.byType(AppSwitch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final mid = tester.getCenter(_knob).dx;
    await tester.pumpAndSettle();
    expect(mid, greaterThan(start));
    expect(mid, lessThan(tester.getCenter(_knob).dx));
  });
}
