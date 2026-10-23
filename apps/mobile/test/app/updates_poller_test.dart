import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/updates_watcher.dart';

import '../screens/shot.dart';
import '../screens/world.dart';

/// Автообновление событий: на переднем плане — проверка
/// раз в 30 с от конца предыдущей; в фоне — ни одной; ручная проверка сбрасывает таймер; одна проверка за раз
/// (ручная и автоматическая присоединяются к идущей). Время — подставное (`testWidgets` + `pump`).
void main() {
  shotInit();

  late int calls;
  late Duration takes;
  late UpdatesPoller poller;

  setUp(() {
    calls = 0;
    takes = Duration.zero;
    poller = UpdatesPoller()
      ..attach(() async {
        calls++;
        await Future<void>.delayed(takes);
      });
  });

  // Таймер снимается до конца теста: проверка «таймеров не осталось» идёт раньше tearDown.
  void timerTest(String name, Future<void> Function(WidgetTester) body) => testWidgets(name, (tester) async {
        await body(tester);
        poller.detach();
      });

  Future<void> wait(WidgetTester tester, int seconds) => tester.pump(Duration(seconds: seconds));

  timerTest('на переднем плане: сразу при возврате, дальше каждые 30 с', (tester) async {
    poller.resume();
    await wait(tester, 0);
    expect(calls, 1);
    await wait(tester, 29);
    expect(calls, 1);
    await wait(tester, 1);
    expect(calls, 2);
    await wait(tester, 30);
    expect(calls, 3);
  });

  timerTest('в фоне запросов нет; возврат — проверка сразу и таймер заново', (tester) async {
    poller.resume();
    await wait(tester, 0);
    poller.pause();
    await wait(tester, 120);
    expect(calls, 1);
    poller.resume();
    await wait(tester, 0);
    expect(calls, 2);
    await wait(tester, 30);
    expect(calls, 3);
  });

  timerTest('ручная сбрасывает таймер: через 29 с после неё запроса нет, через 30 — есть', (tester) async {
    poller.resume();
    await wait(tester, 10);
    poller.refresh(); // ручная на 10-й секунде
    await wait(tester, 0);
    expect(calls, 2);
    await wait(tester, 29);
    expect(calls, 2);
    await wait(tester, 1);
    expect(calls, 3);
  });

  timerTest('(а) ручная во время автопроверки — одна проверка, таймер от её конца', (tester) async {
    takes = const Duration(seconds: 5);
    poller.resume();
    await wait(tester, 2);
    poller.refresh(); // не ждём: незавершённый Future под подставным временем повесил бы тест
    await wait(tester, 3);
    expect(calls, 1);
    takes = Duration.zero;
    await wait(tester, 29);
    expect(calls, 1);
    await wait(tester, 1);
    expect(calls, 2);
  });

  timerTest('(б) тик таймера во время ручной проверки — одна проверка, таймер от её конца', (tester) async {
    poller.resume();
    await wait(tester, 25);
    takes = const Duration(seconds: 10);
    poller.refresh(); // не ждём: незавершённый Future под подставным временем повесил бы тест // идёт до 35 с — через момент тика (30 с)
    await wait(tester, 5);
    expect(calls, 2, reason: 'тик на 30 с не запускает вторую');
    await wait(tester, 5);
    expect(calls, 2);
    takes = Duration.zero;
    await wait(tester, 29);
    expect(calls, 2);
    await wait(tester, 1);
    expect(calls, 3);
  });

  timerTest('сигнал «проверка прошла» — один на проверку, и на присоединённую тоже', (tester) async {
    takes = const Duration(seconds: 5);
    final before = poller.ticks.value;
    poller.resume();
    await wait(tester, 1);
    poller.refresh();
    await wait(tester, 4);
    expect(poller.ticks.value, before + 1);
    takes = Duration.zero;
    await wait(tester, 30);
    expect(poller.ticks.value, before + 2);
  });

  timerTest('без оболочки ручное обновление ничего не делает', (tester) async {
    poller.detach();
    await poller.refresh();
    expect(calls, 0);
  });

  testWidgets('оболочка: тик 30 с — GET /updates; в фоне — нет; возврат — сразу', (tester) async {
    poller.detach();
    shotSurface(tester);
    final world = ShotWorld();
    await world.open(tester);
    int updates() => world.adapter.log.where((r) => r == 'GET /updates').length;
    final start = updates();
    expect(start, greaterThanOrEqualTo(1), reason: 'проверка при открытии');
    await wait(tester, 30);
    await wait(tester, 0);
    expect(updates(), start + 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await wait(tester, 90);
    expect(updates(), start + 1, reason: 'в фоне таймер стоит');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await wait(tester, 0);
    await wait(tester, 0);
    expect(updates(), start + 2);
    debugDisableShadows = true;
  });
}
