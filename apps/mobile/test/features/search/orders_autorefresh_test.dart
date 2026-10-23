import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/updates_watcher.dart';
import 'package:the_way/src/features/search/data/search_filter.dart';
import 'package:the_way/src/features/search/filter/location_service.dart';
import 'package:the_way/src/features/search/search_screen.dart';

import '../../support/fake_api.dart';
import 'order_fixtures.dart';

/// Лента «Заказы пассажиров» перечитывается на каждом тике автообновления (30 с), пока она на экране
/// (принятое решение 2026-10-22); ручной жест не задваивает запрос с тиком.
class _Location implements LocationService {
  const _Location();

  @override
  Future<Coords?> ifGranted() async => null;

  @override
  Future<Coords?> request() async => null;
}

void main() {
  late FakeServer server;
  late int checks;

  setUp(() {
    checks = 0;
    server = FakeServer()
      ..on('GET /trips', (_) => FakeReply(200, [tripCardJson(id: 't1')]))
      ..on('GET /orders', (_) => FakeReply(200, [orderCardJson()]));
    updatesPoller.attach(() async => checks++);
  });

  // Таймер опроса не включается (resume не зовётся); проверка снимается до конца теста.
  tearDown(updatesPoller.detach);

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = fakeSession(server)..pendingMode = UserMode.driver;
    await tester.pumpWidget(testApp(session, const SearchScreen(location: _Location())));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  Future<void> tick(WidgetTester tester) async {
    await tester.runAsync(() async {
      await updatesPoller.refresh();
      // Запрос ленты, начатый тиком, доходит до подставного сервера в настоящем времени.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  int feeds() => server.of('GET /orders').length;

  testWidgets('вкладка заказов открыта — тик перечитывает ленту; открыты «Поездки» — нет', (tester) async {
    await open(tester);
    await tester.tap(find.text('Заказы пассажиров'));
    await tester.pumpAndSettle();
    expect(feeds(), 1);
    await tick(tester);
    expect(feeds(), 2);
    await tester.tap(find.text('Поездки').last);
    await tester.pumpAndSettle();
    await tick(tester);
    expect(feeds(), 2);
  });

  testWidgets('поверх ленты открыт другой экран — тик ленту не перечитывает', (tester) async {
    await open(tester);
    await tester.tap(find.text('Заказы пассажиров'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(SearchScreen)))
        .push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('поверх'))));
    await tester.pumpAndSettle();
    await tick(tester);
    expect(feeds(), 1);
  });

  testWidgets('жест «потянуть вниз» — одна проверка событий и один запрос ленты', (tester) async {
    await open(tester);
    await tester.tap(find.text('Заказы пассажиров'));
    await tester.pumpAndSettle();
    // Действие жеста — onRefresh индикатора ленты (сам жест — виджет платформы).
    tester.widget<RefreshIndicator>(find.byType(RefreshIndicator).last).onRefresh();
    await tester.pumpAndSettle();
    expect(checks, 1);
    expect(feeds(), 2);
  });
}
