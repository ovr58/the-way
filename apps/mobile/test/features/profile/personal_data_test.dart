import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/session.dart';
import 'package:the_way/src/features/auth/widgets/cta_bar.dart';
import 'package:the_way/src/features/profile/personal_data/personal_data_screen.dart';
import 'package:the_way/src/features/profile_setup/photo_picker.dart';
import 'package:the_way/src/widgets/app_header.dart';
import 'package:the_way/src/widgets/app_icon.dart';
import 'package:the_way/src/widgets/avatar.dart';

import '../auth/fake_api.dart';

FakeAdapter _adapter({FakeReply Function(FakeRequest)? patch}) => FakeAdapter({
      'GET /me': (_) => FakeReply(200, meJson(name: 'Мария')),
      'PATCH /me': patch ?? (_) => FakeReply(200, meJson(name: 'Мария')),
      'POST /files': (_) => const FakeReply(201, {'id': 'f1', 'url': '/files/f1'}),
    });

/// Экран «Личные данные» поверх страницы-основы: `pop` после сохранения возвращает на неё.
Future<AppSession> _open(WidgetTester tester, FakeAdapter adapter, {PhotoPicker? pick}) async {
  usePhone(tester);
  final session = fakeSession(adapter)..me = Me.fromJson({...meJson(name: 'Анастасия'), 'phone': '+79001234567'});
  await tester.pumpWidget(fakeApp(
    session,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => pick == null ? const PersonalDataScreen() : PersonalDataScreen(pickPhoto: pick)),
          ),
          child: const Text('основа'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('основа'));
  await tester.pumpAndSettle();
  return session;
}

bool _saveEnabled(WidgetTester tester) => tester.widget<CtaButton>(find.byType(CtaButton)).onPressed != null;

void main() {
  setUpAll(loadGilroy);

  testWidgets('поле имени — каждое слово с заглавной буквы, номер телефона не затронут', (tester) async {
    await _open(tester, _adapter());
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.first.textCapitalization, TextCapitalization.words);
    expect(fields.last.textCapitalization, TextCapitalization.none);
  });

  testWidgets('без фото в круге — силуэт человека, как на экране регистрации', (tester) async {
    await _open(tester, _adapter());
    final icon = tester.widget<AppIcon>(find.descendant(of: find.byType(Avatar), matching: find.byType(AppIcon)));
    expect(icon.name, 'users_user_rounded');
    expect(icon.size, 48);
  });

  testWidgets('«Профиль - Личные данные»: шапка со стрелкой назад без «трёх точек», имя и номер из GET /me, панель «Сохранить»', (tester) async {
    await _open(tester, _adapter());
    final header = tester.widget<AppHeader>(find.byType(AppHeader));
    expect(header.title, 'Личные данные');
    expect(header.onBack, isNotNull);
    expect(header.trailing, isNull);
    expect(find.text('Анастасия'), findsOneWidget);
    expect(find.text('+7 900 123 45 67'), findsOneWidget); // маска экрана входа, как в кадре
    expect(find.text('Номер телефона'), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('personal_data_photo'))), const Size(96, 96));
  });

  testWidgets('без изменений «Сохранить» неактивна; пустое имя — неактивна', (tester) async {
    final adapter = _adapter();
    await _open(tester, adapter);
    expect(_saveEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pump();
    expect(_saveEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField).first, 'Анастасия ');
    await tester.pump();
    expect(_saveEnabled(tester), isFalse); // то же имя с пробелом — не изменение
    expect(adapter.requests, isEmpty);
  });

  testWidgets('номер не редактируется', (tester) async {
    await _open(tester, _adapter());
    final phone = tester.widget<TextField>(find.byType(TextField).last);
    expect(phone.readOnly, isTrue);
    expect(phone.controller!.text, '+7 900 123 45 67');
  });

  testWidgets('новое имя: PATCH /me несёт name, photoFileId — null, номера нет; GET /me, возврат и подсказка', (tester) async {
    final adapter = _adapter();
    final session = await _open(tester, adapter);

    await tester.enterText(find.byType(TextField).first, ' Мария ');
    await tester.pump();
    expect(_saveEnabled(tester), isTrue);
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final patch = adapter.requests.singleWhere((r) => r.method == 'PATCH');
    final body = patch.data as Map;
    expect(body['name'], 'Мария');
    expect(body['photoFileId'], isNull);
    expect(body.containsKey('phone'), isFalse);
    expect(adapter.requests.last.path, '/me'); // refresh() после PATCH
    expect(adapter.requests.last.method, 'GET');
    expect(session.me?.name, 'Мария');
    expect(find.text('основа'), findsOneWidget);
    expect(find.text('Изменения сохранены'), findsOneWidget);
  });

  testWidgets('новое фото: шторка «Камера»/«Галерея», POST /files, затем PATCH с photoFileId и без имени', (tester) async {
    final adapter = _adapter();
    final photo = File('${Directory.systemTemp.path}/u7_personal_data_photo_test.jpg')..writeAsBytesSync([1, 2, 3]);
    addTearDown(() {
      try {
        photo.deleteSync();
      } on FileSystemException {
        // Windows держит файл, пока его читает загрузка; временная папка очистится сама.
      }
    });
    PhotoSource? asked;
    await _open(tester, adapter, pick: (source) async {
      asked = source;
      return photo;
    });

    await tester.tap(find.byKey(const Key('personal_data_photo')));
    await tester.pumpAndSettle();
    expect(find.text('Загрузка фотографии'), findsOneWidget);
    expect(find.text('Камера'), findsOneWidget);
    await tester.tap(find.text('Галерея'));
    await tester.pumpAndSettle();
    expect(asked, PhotoSource.gallery);
    expect(adapter.requests.single.path, '/files');
    expect(_saveEnabled(tester), isTrue); // имя то же, но фото изменилось

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    final body = adapter.requests.singleWhere((r) => r.method == 'PATCH').data as Map;
    expect(body['photoFileId'], 'f1');
    expect(body['name'], isNull);
  });

  testWidgets('камера запрещена — «Нет доступа к камере…»', (tester) async {
    await _open(tester, _adapter(), pick: (_) async => throw PlatformException(code: 'camera_access_denied', message: 'The user did not allow camera access.'));
    await tester.tap(find.byKey(const Key('personal_data_photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Камера'));
    await tester.pumpAndSettle();
    expect(find.text('Нет доступа к камере — разрешите в настройках телефона'), findsOneWidget);
  });

  testWidgets('ошибка сохранения: общий текст, экран остаётся', (tester) async {
    final adapter = _adapter(patch: (_) => const FakeReply(500, {'code': 'internal', 'message': 'x'}));
    await _open(tester, adapter);
    await tester.enterText(find.byType(TextField).first, 'Мария');
    await tester.pump();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Не удалось выполнить действие'), findsOneWidget);
    expect(find.text('Личные данные'), findsOneWidget);
  });
}
