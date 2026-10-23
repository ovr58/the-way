import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/profile/profile_screen.dart';
import 'package:the_way/src/widgets/app_header.dart';

import '../auth/fake_api.dart';

Map<String, Object?> _complaint(String id, String reason, String status, String createdAt) =>
    {'id': id, 'reason': reason, 'status': status, 'createdAt': createdAt};

Future<FakeAdapter> _open(WidgetTester tester, FakeReply Function(FakeRequest) complaints) async {
  usePhone(tester);
  final adapter = FakeAdapter({
    'GET /me': (_) => FakeReply(200, meJson(name: 'Анастасия')),
    'GET /me/complaints': complaints,
  });
  await tester.pumpWidget(fakeApp(fakeSession(adapter), const ProfileScreen()));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Жалобы'), 100, scrollable: find.byType(Scrollable).first);
  await tester.tap(find.text('Жалобы'));
  await tester.pumpAndSettle();
  return adapter;
}

void main() {
  setUpAll(loadGilroy);

  testWidgets('две жалобы: строки в порядке сервера, «Открыта» и «Закрыта», дата по Москве', (tester) async {
    final adapter = await _open(
      tester,
      (_) => FakeReply(200, [
        _complaint('c1', 'Опоздал на посадку', 'open', '2026-10-12T22:30:00Z'),
        _complaint('c2', 'Грубое общение', 'closed', '2026-09-03T09:00:00Z'),
      ]),
    );

    expect(adapter.requests.any((r) => r.path == '/me/complaints'), isTrue);
    final header = tester.widget<AppHeader>(find.byType(AppHeader));
    expect(header.title, 'Жалобы');
    expect(header.onBack, isNotNull);
    expect(header.trailing, isNull);
    expect(find.text('Опоздал на посадку'), findsOneWidget);
    expect(find.text('13 октября 2026 · Открыта'), findsOneWidget); // 22:30 UTC — уже 13-е по Москве
    expect(find.text('Грубое общение'), findsOneWidget);
    expect(find.text('3 сентября 2026 · Закрыта'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Опоздал на посадку')).dy, lessThan(tester.getTopLeft(find.text('Грубое общение')).dy));
  });

  testWidgets('пустой ответ: «Жалоб нет» и пояснение', (tester) async {
    await _open(tester, (_) => const FakeReply(200, <Object?>[]));
    expect(find.text('Жалоб нет'), findsOneWidget);
    expect(find.text('Здесь появятся жалобы на вас, если они будут'), findsOneWidget);
  });

  testWidgets('ошибка загрузки: «Обновить» повторяет запрос', (tester) async {
    var calls = 0;
    await _open(
      tester,
      (_) => ++calls == 1
          ? const FakeReply(500, {'code': 'internal', 'message': 'x'})
          : FakeReply(200, [_complaint('c1', 'Опоздал на посадку', 'open', '2026-10-12T10:00:00Z')]),
    );
    expect(find.text('Обновить'), findsOneWidget);
    await tester.tap(find.text('Обновить'));
    await tester.pumpAndSettle();
    expect(find.text('Опоздал на посадку'), findsOneWidget);
  });
}
