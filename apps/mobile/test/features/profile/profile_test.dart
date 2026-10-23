import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/session.dart';
import 'package:the_way/src/features/profile/profile_screen.dart';
import 'package:the_way/src/theme/app_colors.dart';
import 'package:the_way/src/widgets/app_header.dart';
import 'package:the_way/src/widgets/app_icon.dart';
import 'package:the_way/src/widgets/avatar.dart';
import 'package:the_way/src/features/profile/switch_mode_screen.dart';

import '../auth/fake_api.dart';

FakeAdapter _adapter(String mode) => FakeAdapter({
      'GET /me': (_) => FakeReply(200, meJson(name: 'Анастасия', mode: mode, trips: 120, reviews: 8)),
      'PATCH /me': (r) => FakeReply(200, meJson(name: 'Анастасия', mode: (r.data as Map)['mode'] as String)),
      'POST /auth/logout': (_) => const FakeReply(204),
    });

Future<void> _open(WidgetTester tester, FakeAdapter adapter, {AppSession? session}) async {
  usePhone(tester);
  final s = session ?? fakeSession(adapter);
  await tester.pumpWidget(fakeApp(s, const ProfileScreen()));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadGilroy);

  testWidgets('пассажир: шапка из GET /me, пункты меню, «Перейти в режим водителя», без автомобилей', (tester) async {
    final adapter = _adapter('passenger');
    await _open(tester, adapter);

    expect(adapter.requests.first.path, '/me');
    expect(find.text('Мой профиль'), findsOneWidget);
    expect(find.text('Анастасия'), findsOneWidget);
    expect(find.text('4,8'), findsOneWidget);
    expect(find.text('120 поездок'), findsOneWidget);
    expect(find.text('Перейти в режим водителя'), findsOneWidget);
    expect(find.text('Транспортные средства'), findsNothing);
    await tester.tap(find.text('Перейти в режим водителя'));
    await tester.pumpAndSettle();
    expect(find.text('route:profile/switch_mode'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    for (final title in ['Личные данные', 'Сохраненные маршруты', 'История заказов', 'Жалобы', 'Уведомления', 'Способ оплаты', 'Частые вопросы', 'О приложении']) {
      await tester.scrollUntilVisible(find.text(title), 100, scrollable: find.byType(Scrollable).first);
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('1'), findsNothing); // индикатора у «Уведомлений» нет
  });

  testWidgets('без фото «Мой профиль» рисует в круге силуэт человека, как экран регистрации', (tester) async {
    await _open(tester, _adapter('passenger'));
    final avatar = find.byType(Avatar);
    expect(tester.getSize(avatar), const Size(96, 96));
    final icon = tester.widget<AppIcon>(find.descendant(of: avatar, matching: find.byType(AppIcon)));
    expect(icon.name, 'users_user_rounded');
    expect(icon.size, 48);
    expect(icon.color, AppColors.textSecondary);
  });

  testWidgets('водитель: «Перейти в режим пассажира», «Транспортные средства» → cars; «Личные данные» → «Профиль - Личные данные»; пункты без экранов → stub', (tester) async {
    await _open(tester, _adapter('driver'));
    expect(find.text('Перейти в режим пассажира'), findsOneWidget);

    await tester.tap(find.text('Транспортные средства'));
    await tester.pumpAndSettle();
    expect(find.text('route:cars'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Личные данные'));
    await tester.pumpAndSettle();
    expect(find.text('Номер телефона'), findsOneWidget); // экран «Профиль - Личные данные», не заглушка
    expect(find.text('route:stub'), findsNothing);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Сохраненные маршруты'), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Сохраненные маршруты'));
    await tester.pumpAndSettle();
    expect(find.text('route:stub'), findsOneWidget);
  });

  testWidgets('«Выйти из аккаунта» («Профиль - Базовый экран»): окно «Выйдите из аккаунта?» с «Выйти» и «Отмена», без текста о несохранённом', (tester) async {
    final adapter = _adapter('passenger');
    final session = fakeSession(adapter);
    await session.signIn('tok');
    await _open(tester, adapter, session: session);

    await tester.scrollUntilVisible(find.text('Выйти из аккаунта'), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Выйти из аккаунта'));
    await tester.pumpAndSettle();
    expect(find.text('Выйдите из аккаунта?'), findsOneWidget);
    expect(find.text('Выйти'), findsOneWidget);
    expect(find.text('Отмена'), findsOneWidget);
    expect(find.textContaining('изменения'), findsNothing); // слой пояснения в кадре скрыт
    // Кадр «Профиль - Базовый экран»: окно 270×142 — заголовок 54 и две кнопки по 44.
    final window = find.byWidgetPredicate((w) => w is SizedBox && w.width == 270);
    expect(tester.getSize(window), const Size(270, 142));
    expect(adapter.requests.any((r) => r.path == '/auth/logout'), isFalse);
    expect(session.token, 'tok');
  });

  testWidgets('«Отмена» в окне выхода ничего не делает', (tester) async {
    final adapter = _adapter('passenger');
    final session = fakeSession(adapter);
    await session.signIn('tok');
    await _open(tester, adapter, session: session);

    await tester.scrollUntilVisible(find.text('Выйти из аккаунта'), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Выйти из аккаунта'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Выйдите из аккаунта?'), findsNothing);
    expect(adapter.requests.any((r) => r.path == '/auth/logout'), isFalse);
    expect(session.token, 'tok');
  });

  testWidgets('«Выйти» в окне снимает токен и открывает вход', (tester) async {
    final adapter = _adapter('passenger');
    final session = fakeSession(adapter);
    await session.signIn('tok');
    await _open(tester, adapter, session: session);

    await tester.scrollUntilVisible(find.text('Выйти из аккаунта'), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Выйти из аккаунта'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();
    expect(adapter.requests.any((r) => r.path == '/auth/logout'), isTrue);
    expect(session.token, isNull);
    expect(find.text('route:auth'), findsOneWidget);
  });

  testWidgets('«Профиль - Базовый экран»: шапка «Мой профиль» с нижней линией', (tester) async {
    await _open(tester, _adapter('passenger'));
    expect(tester.widget<AppHeader>(find.byType(AppHeader)).bordered, isTrue);
  });

  testWidgets('«Профиль - Базовый экран»: значки пунктов меню серые (text.secondary), не чёрные', (tester) async {
    await _open(tester, _adapter('driver'));
    final icons = tester.widgetList<AppIcon>(find.descendant(
      of: find.byType(InkWell),
      matching: find.byWidgetPredicate((w) => w is AppIcon && w.size == 24),
    )).toList();
    expect(icons.length, greaterThanOrEqualTo(5));
    for (final icon in icons) {
      expect(icon.color, AppColors.textSecondary, reason: icon.name);
    }
  });

  testWidgets('«Профиль - Базовый экран»: «★ 4,8 • 120 поездок» с кружком 3 в шапке', (tester) async {
    await _open(tester, _adapter('passenger'));
    final dot = find.byKey(const Key('rating_dot'));
    expect(dot, findsOneWidget);
    expect(tester.getSize(dot), const Size(3, 3));
    expect(tester.getRect(find.text('4,8')).right, lessThan(tester.getRect(dot).left));
    expect(tester.getRect(dot).right, lessThan(tester.getRect(find.text('120 поездок')).left));
  });

  testWidgets('ошибка загрузки без профиля: «Обновить» повторяет GET /me', (tester) async {
    var calls = 0;
    final adapter = FakeAdapter({
      'GET /me': (_) => ++calls == 1 ? const FakeReply(500, {'code': 'internal', 'message': 'x'}) : FakeReply(200, meJson(name: 'Анастасия')),
    });
    await _open(tester, adapter);
    expect(find.text('Обновить'), findsOneWidget);
    await tester.tap(find.text('Обновить'));
    await tester.pumpAndSettle();
    expect(find.text('Анастасия'), findsOneWidget);
  });

  testWidgets('выбор роли: PATCH /me {mode}, режим сессии меняется', (tester) async {
    usePhone(tester);
    final adapter = _adapter('passenger');
    final session = fakeSession(adapter);
    await tester.pumpWidget(fakeApp(session, const SwitchModeScreen()));
    expect(find.text('Выберите роль'), findsOneWidget);
    expect(session.mode, UserMode.passenger);

    await tester.tap(find.text('Водитель'));
    await tester.pumpAndSettle();
    final patch = adapter.requests.singleWhere((r) => r.method == 'PATCH');
    expect((patch.data as Map)['mode'], 'driver');
    expect(session.mode, UserMode.driver);
  });

  testWidgets('ошибка PATCH /me даже с кодом blocked — общий текст, режим не меняется', (tester) async {
    usePhone(tester);
    final adapter = FakeAdapter({
      'PATCH /me': (_) => const FakeReply(400, {'code': 'blocked', 'message': 'x'}),
    });
    final session = fakeSession(adapter);
    await tester.pumpWidget(fakeApp(session, const SwitchModeScreen()));

    await tester.tap(find.text('Водитель'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Не удалось выполнить действие'), findsOneWidget);
    expect(find.text('Ваш аккаунт заблокирован'), findsNothing);
    expect(session.mode, UserMode.passenger);
  });
}
