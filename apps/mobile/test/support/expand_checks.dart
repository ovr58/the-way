import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// раскрытие списка кнопкой «Смотреть стоимость» — одно движение 350 мс. Нажатие на [chip]:
/// на середине [item] уже в дереве и полупрозрачен, движение идёт; через 350 мс — список виден целиком, вместо
/// таблетки круглая кнопка [collapse]. Нажатие на [collapse] — обратно: список уходит, таблетка на месте.
Future<void> expectExpandCycle(
  WidgetTester tester, {
  required Key chip,
  required Key collapse,
  required Finder item,
}) async {
  double opacity() => tester.widget<Opacity>(find.ancestor(of: item, matching: find.byType(Opacity)).first).opacity;
  const half = Duration(milliseconds: 175);
  const rest = Duration(milliseconds: 180);

  expect(item, findsNothing);
  await tester.ensureVisible(find.byKey(chip));
  await tester.tap(find.byKey(chip));
  await tester.pump();
  await tester.pump(half);
  expect(item, findsOneWidget);
  expect(opacity(), allOf(greaterThan(0), lessThan(1)), reason: 'список выплывает, а не появляется разом');
  expect(tester.hasRunningAnimations, isTrue);
  await tester.pump(rest);
  expect(tester.hasRunningAnimations, isFalse, reason: '350 мс прошло — на месте');
  expect(opacity(), 1);
  expect(find.byKey(collapse), findsOneWidget);
  expect(find.byKey(chip), findsNothing);

  await tester.tap(find.byKey(collapse));
  await tester.pump();
  await tester.pump(half);
  expect(item, findsOneWidget, reason: 'сворачивается плавно, не исчезает разом');
  expect(opacity(), allOf(greaterThan(0), lessThan(1)));
  await tester.pump(rest);
  expect(item, findsNothing);
  expect(find.byKey(chip), findsOneWidget);
  expect(find.byKey(collapse), findsNothing);
  expect(tester.hasRunningAnimations, isFalse);
}
