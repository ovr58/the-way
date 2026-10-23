import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/search/driver/driver_profile_screen.dart';
import 'package:the_way/src/theme/app_colors.dart';
import 'package:the_way/src/widgets/app_icon.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _review(String id, String author, int rating, String body, String at) =>
    {'id': id, 'authorName': author, 'rating': rating, 'body': body, 'createdAt': at};

FakeServer _server({required Map<String, Object?> user, required List<Object?> reviews}) => FakeServer()
  ..on('GET /users/d1/public', (_) => FakeReply(200, user))
  ..on('GET /users/d1/reviews', (_) => FakeReply(200, reviews));

Future<void> _open(WidgetTester tester, FakeServer server) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(fakeSession(server), const DriverProfileScreen(userId: 'd1')));
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('«Профиль - Профиль пассажира»: «Профиль водителя» — фото, имя, рейтинг, поездки; отзывы — автор, оценка, текст, дата', (tester) async {
    final server = _server(user: driverJson(), reviews: [
      _review('r1', 'Анна', 5, 'Отличная поездка', '2026-05-12T10:00:00.000Z'),
      _review('r2', 'Пётр', 4, 'Немного опоздал', '2026-04-03T10:00:00.000Z'),
    ]);
    await _open(tester, server);

    expect(find.text('Профиль водителя'), findsOneWidget);
    expect(find.text('Виктор О.'), findsOneWidget);
    expect(find.text('Рейтинг поездок'), findsOneWidget);
    expect(find.text('4,5'), findsOneWidget);
    expect(find.text('127 поездок'), findsOneWidget);
    expect(find.text('Отзывы'), findsOneWidget);
    expect(find.text('Анна'), findsOneWidget);
    expect(find.text('Отличная поездка'), findsOneWidget);
    expect(find.text('12 мая 2026'), findsOneWidget);
    int lit(String key) => tester
        .widgetList<AppIcon>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(AppIcon)))
        .where((i) => i.color == AppColors.accentWarning)
        .length;
    expect(lit('review_r1_stars_5'), 5);
    expect(lit('review_r2_stars_4'), 4);
    expect(tester.getTopLeft(find.text('Анна')).dy, lessThan(tester.getTopLeft(find.text('Пётр')).dy), reason: 'порядок сервера');
    expect(tester.getTopLeft(find.text('Рейтинг поездок')).dy, lessThan(tester.getTopLeft(find.text('Отзывы')).dy));
  });

  testWidgets('без отзывов — «5, нет отзывов» и «Отзывов пока нет»', (tester) async {
    final server = _server(user: {...driverJson(), 'rating': {'value': 0, 'count': 0}, 'tripsCount': 0}, reviews: []);
    await _open(tester, server);
    expect(find.text('5, нет отзывов'), findsOneWidget);
    expect(find.text('Отзывов пока нет'), findsOneWidget);
  });

  testWidgets('«Профиль - Профиль пассажира»: телефон известен — номер и «Написать в чат» (заглушка чата); нет телефона — ни того, ни другого', (tester) async {
    final server = _server(user: {...driverJson(), 'phone': '+79001112233'}, reviews: []);
    final opened = <String, List<Object?>>{};
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(fakeSession(server), const DriverProfileScreen(userId: 'd1'), opened: opened));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.text('+7 900 111 22 33'), findsOneWidget);
    await tester.tap(find.text('Написать в чат'));
    await tester.pumpAndSettle();
    expect(opened['stub'], ['Чат появится позже']);
  });

  testWidgets('без телефона кнопки чата нет', (tester) async {
    await _open(tester, _server(user: driverJson(), reviews: []));
    expect(find.text('Написать в чат'), findsNothing);
    expect(find.text('Номер телефона'), findsNothing);
  });

  testWidgets('ошибка загрузки — экран ошибки с повтором', (tester) async {
    final server = FakeServer()..on('GET /users/d1/public', (_) => const FakeReply(500, {'code': 'internal', 'message': 'x'}));
    await _open(tester, server);
    expect(find.text('Виктор О.'), findsNothing);
    expect(find.text('Обновить'), findsOneWidget);
  });
}
