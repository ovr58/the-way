import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/home_shell.dart';
import 'package:the_way/src/features/profile_setup/profile_setup_screen.dart';

import '../screens/world.dart';

/// Запуск с сохранённой сессией: профиль ещё не загружен, `GET /me` приходит после старта.
/// Без имени — экран «Создайте свой профиль», с именем — оболочка.
void main() {
  testWidgets('сохранённая сессия, у профиля нет имени → экран создания профиля', (tester) async {
    final world = ShotWorld();
    world.session.me = null;
    world.routes['GET /me'] = (_) => {...meJson(), 'name': null};

    await world.open(tester);

    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
    debugDisableShadows = true; // shotSettle включает тени; проверка среды в конце теста ждёт исходное
  });

  testWidgets('сохранённая сессия, имя есть → оболочка', (tester) async {
    final world = ShotWorld();
    world.session.me = null;

    await world.open(tester);

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(ProfileSetupScreen), findsNothing);
    debugDisableShadows = true; // shotSettle включает тени; проверка среды в конце теста ждёт исходное
  });
}
