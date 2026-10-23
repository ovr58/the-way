import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/trip_new/moscow_time.dart';
import 'package:the_way/src/features/trip_new/steps/datetime_step.dart';
import 'package:the_way/src/features/trip_new/wizard_controller.dart';
import 'package:the_way/src/widgets/app_button.dart';

import 'support.dart';

/// Окно публикации — 72 ч от «сейчас». «Сейчас» — 22.10 01:20 по Москве.
final _now = DateTime.utc(2026, 10, 21, 22, 20, 30);

WizardController _draft() => WizardController(repositoryOf(FakeAdapter({})), now: () => _now);

/// 22.10 15:10 по Москве.
final _afternoon = DateTime.utc(2026, 10, 22, 12, 10);

/// 22.10 23:40 по Москве — сегодня слотов не осталось.
final _lateNight = DateTime.utc(2026, 10, 22, 20, 40);

void main() {
  group('moscow_time: нижняя граница окна (не раньше «сейчас»)', () {
    test('сегодня — следующий получас после «сейчас»; другие дни без ограничения', () {
      expect(earliestDepartOn(DateTime(2026, 10, 22), _now), const TimeOfDay(hour: 1, minute: 30));
      expect(earliestDepartOn(DateTime(2026, 10, 22), _afternoon), const TimeOfDay(hour: 15, minute: 30));
      expect(earliestDepartOn(DateTime(2026, 10, 23), _now), isNull);
    });

    test('ровно на получасе — следующий получас, а не «сейчас»', () {
      final onTheDot = DateTime.utc(2026, 10, 22, 12, 0); // 15:00
      expect(earliestDepartOn(DateTime(2026, 10, 22), onTheDot), const TimeOfDay(hour: 15, minute: 30));
    });

    test('после 23:30 сегодня слотов нет', () {
      expect(hasDepartSlotsOn(DateTime(2026, 10, 22), _lateNight), isFalse);
      expect(hasDepartSlotsOn(DateTime(2026, 10, 22), _afternoon), isTrue);
      expect(hasDepartSlotsOn(DateTime(2026, 10, 23), _lateNight), isTrue);
    });
  });

  group('moscow_time: окно 72 ч', () {
    test('в крайный день время выезда — не позже «сейчас» + 72 ч, с шагом 30 минут', () {
      expect(latestDepartOn(DateTime(2026, 10, 25), _now), const TimeOfDay(hour: 1, minute: 0));
    });

    test('в остальные дни ограничения по времени нет', () {
      expect(latestDepartOn(DateTime(2026, 10, 24), _now), isNull);
      expect(latestDepartOn(DateTime(2026, 10, 22), _now), isNull);
    });
  });

  group('WizardController: сегодняшнее время в прошлом', () {
    test('выбрали сегодня при времени раньше «сейчас» — время сбрасывается', () {
      final c = WizardController(repositoryOf(FakeAdapter({})), now: () => _afternoon)
        ..setDate(DateTime(2026, 10, 23))
        ..setDepartTime(const TimeOfDay(hour: 8, minute: 0))
        ..setDate(DateTime(2026, 10, 22));
      expect(c.departTime, isNull);
    });

    test('время позже «сейчас» на сегодня сохраняется', () {
      final c = WizardController(repositoryOf(FakeAdapter({})), now: () => _afternoon)
        ..setDate(DateTime(2026, 10, 23))
        ..setDepartTime(const TimeOfDay(hour: 18, minute: 0))
        ..setDate(DateTime(2026, 10, 22));
      expect(c.departTime, const TimeOfDay(hour: 18, minute: 0));
    });
  });

  group('WizardController: дата и время в окне', () {
    test('выбрали крайный день при позднем времени — время сбрасывается, не уходит на сервер', () {
      final c = _draft()
        ..setDate(DateTime(2026, 10, 24))
        ..setDepartTime(const TimeOfDay(hour: 8, minute: 0))
        ..setDate(DateTime(2026, 10, 25));
      expect(c.departTime, isNull);
    });

    test('время в пределах окна сохраняется при смене даты', () {
      final c = _draft()
        ..setDate(DateTime(2026, 10, 24))
        ..setDepartTime(const TimeOfDay(hour: 0, minute: 30))
        ..setDate(DateTime(2026, 10, 25));
      expect(c.departTime, const TimeOfDay(hour: 0, minute: 30));
    });
  });

  group('лист «Выбрать время» на крайний день', () {
    Future<WizardController> open(WidgetTester tester) async {
      tallView(tester);
      final c = _draft()..setDate(DateTime(2026, 10, 25));
      await tester.pumpWidget(app(Scaffold(
        body: ListenableBuilder(listenable: c, builder: (_, _) => DepartureBlock(controller: c)),
      )));
      await tapField(tester, 'Время');
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('колесо открывается на крайнем допустимом времени, а не на 8:00', (tester) async {
      final c = await open(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Выбрать время'));
      await tester.pumpAndSettle();
      expect(c.departTime, const TimeOfDay(hour: 1, minute: 0));
    });

    testWidgets('прокрутка часов за предел возвращается к крайнему времени', (tester) async {
      final c = await open(tester);
      final hours = find.byType(CupertinoPicker).first;
      await tester.drag(hours, const Offset(0, -40.0 * 6));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Выбрать время'));
      await tester.pumpAndSettle();
      expect(c.departTime, const TimeOfDay(hour: 1, minute: 0));
    });

    testWidgets('сегодня: колесо открывается на ближайшем допустимом времени, а не на 8:00', (tester) async {
      tallView(tester);
      final c = WizardController(repositoryOf(FakeAdapter({})), now: () => _afternoon)..setDate(DateTime(2026, 10, 22));
      await tester.pumpWidget(app(Scaffold(
        body: ListenableBuilder(listenable: c, builder: (_, _) => DepartureBlock(controller: c)),
      )));
      await tapField(tester, 'Время');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Выбрать время'));
      await tester.pumpAndSettle();
      expect(c.departTime, const TimeOfDay(hour: 15, minute: 30));
    });

    testWidgets('сегодня: прокрутка часов в прошлое возвращается к ближайшему допустимому времени', (tester) async {
      tallView(tester);
      final c = WizardController(repositoryOf(FakeAdapter({})), now: () => _afternoon)
        ..setDate(DateTime(2026, 10, 22))
        ..setDepartTime(const TimeOfDay(hour: 18, minute: 0));
      await tester.pumpWidget(app(Scaffold(
        body: ListenableBuilder(listenable: c, builder: (_, _) => DepartureBlock(controller: c)),
      )));
      await tapField(tester, 'Время');
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CupertinoPicker).first, const Offset(0, 40.0 * 6)); // 18 → 12
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Выбрать время'));
      await tester.pumpAndSettle();
      expect(c.departTime, const TimeOfDay(hour: 15, minute: 30));
    });

    testWidgets('поздно вечером сегодняшний день в календаре серый — первый день завтра', (tester) async {
      tallView(tester);
      final c = WizardController(repositoryOf(FakeAdapter({})), now: () => _lateNight);
      await tester.pumpWidget(app(Scaffold(
        body: ListenableBuilder(listenable: c, builder: (_, _) => DepartureBlock(controller: c)),
      )));
      await tapField(tester, 'Дата');
      await tester.pumpAndSettle();
      final calendar = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
      expect(calendar.firstDate, DateTime(2026, 10, 23));
      expect(calendar.lastDate, DateTime(2026, 10, 25));
    });

    testWidgets('календарь не даёт выбрать день за окном: последний день — +3 от «сейчас» по Москве', (tester) async {
      tallView(tester);
      final c = _draft();
      await tester.pumpWidget(app(Scaffold(
        body: ListenableBuilder(listenable: c, builder: (_, _) => DepartureBlock(controller: c)),
      )));
      await tapField(tester, 'Дата');
      await tester.pumpAndSettle();
      final calendar = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
      expect(calendar.firstDate, DateTime(2026, 10, 22));
      expect(calendar.lastDate, DateTime(2026, 10, 25));
    });
  });
}
