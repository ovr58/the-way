import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/profile_setup/profile_setup_screen.dart';

import '../auth/fake_api.dart';

FakeAdapter _adapter() => FakeAdapter({
      'POST /files': (_) => const FakeReply(201, {'id': 'f1', 'url': '/files/f1'}),
      'PATCH /me': (_) => FakeReply(200, meJson(name: 'Анна', mode: 'driver')),
      'GET /me': (_) => FakeReply(200, meJson(name: 'Анна', mode: 'driver')),
    });

void main() {
  setUpAll(loadGilroy);

  testWidgets('поле имени — каждое слово с заглавной буквы', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(fakeApp(fakeSession(_adapter()), const ProfileSetupScreen()));
    expect(tester.widget<TextField>(find.byType(TextField)).textCapitalization, TextCapitalization.words);
  });

  testWidgets('имя обязательно: «Далее» ждёт непустое имя; PATCH /me несёт имя, фото, город и роль', (tester) async {
    usePhone(tester);
    final adapter = _adapter();
    final session = fakeSession(adapter)
      ..pendingCityId = 5
      ..pendingMode = UserMode.driver;
    final photo = File('${Directory.systemTemp.path}/u1_profile_photo_test.jpg')..writeAsBytesSync([1, 2, 3]);
    addTearDown(() {
      try {
        photo.deleteSync();
      } on FileSystemException {
        // Windows держит файл, пока его читает загрузка; временная папка очистится сама.
      }
    });
    await tester.pumpWidget(fakeApp(session, ProfileSetupScreen(pickPhoto: (_) async => photo)));

    expect(find.text('Создайте свой профиль'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(find.text('Начать'), findsNothing); // и в фокусе — «Далее» («Создание профиля - Ввод имя»/«Создание профиля - Загрузка фото» — «Начать», реестр)
    await tester.tap(find.text('Далее'));
    await tester.pump();
    expect(adapter.requests, isEmpty);

    await tester.tap(find.byKey(const Key('profile_setup_photo_button')));
    await tester.pumpAndSettle();
    expect(find.text('Загрузка фотографии'), findsOneWidget);
    expect(find.text('Камера'), findsOneWidget);
    await tester.tap(find.text('Галерея'));
    await tester.pumpAndSettle();
    expect(adapter.requests.single.path, '/files');

    await tester.enterText(find.byType(TextField), ' Анна ');
    await tester.pump();
    expect(find.text('6/50'), findsOneWidget);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle(); // потеря фокуса применяется отдельным кадром
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    final patch = adapter.requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.data, {'name': 'Анна', 'photoFileId': 'f1', 'cityId': 5, 'mode': 'driver'});
    expect(session.me?.name, 'Анна');
    expect(session.pendingCityId, isNull);
    expect(find.text('route:shell'), findsOneWidget);
  });

  testWidgets('камера запрещена — «Нет доступа к камере…», а не «Проверьте интернет»', (tester) async {
    usePhone(tester);
    final adapter = _adapter();
    await tester.pumpWidget(fakeApp(fakeSession(adapter), ProfileSetupScreen(pickPhoto: (_) async => throw PlatformException(code: 'camera_access_denied', message: 'The user did not allow camera access.'))));
    await tester.tap(find.byKey(const Key('profile_setup_photo_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Камера'));
    await tester.pumpAndSettle();
    expect(find.text('Нет доступа к камере — разрешите в настройках телефона'), findsOneWidget);
    expect(find.textContaining('Проверьте интернет'), findsNothing);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('промежутки подсказка—фото—имя — 24, как в «Создание профиля - Базовый экран»', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(fakeApp(fakeSession(_adapter()), const ProfileSetupScreen()));
    expect(find.byWidgetPredicate((w) => w is SizedBox && w.height == 24 && w.width == null && w.child == null), findsNWidgets(2));
  });

  testWidgets('слишком большой файл: текст ошибки, фото не принято', (tester) async {
    usePhone(tester);
    final adapter = FakeAdapter({'POST /files': (_) => const FakeReply(413, {'code': 'file_too_large', 'message': 'x'})});
    final photo = File('${Directory.systemTemp.path}/u1_profile_photo_big_test.jpg')..writeAsBytesSync([1]);
    addTearDown(() {
      try {
        photo.deleteSync();
      } on FileSystemException {
        // Windows держит файл, пока его читает загрузка; временная папка очистится сама.
      }
    });
    await tester.pumpWidget(fakeApp(fakeSession(adapter), ProfileSetupScreen(pickPhoto: (_) async => photo)));

    await tester.tap(find.byKey(const Key('profile_setup_photo_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Камера'));
    await tester.pumpAndSettle();
    expect(find.textContaining('до 10 МБ'), findsOneWidget);
  });
}
