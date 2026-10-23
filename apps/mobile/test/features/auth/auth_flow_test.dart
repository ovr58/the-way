import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/auth/auth_screen.dart';
import 'package:the_way/src/features/auth/data/phone_format.dart';
import 'package:the_way/src/features/auth/widgets/consent_text.dart';
import 'package:the_way/src/features/auth/widgets/cta_bar.dart';

import 'fake_api.dart';

const _phone = '+375257774420';

FakeAdapter _adapter({required bool isNew}) => FakeAdapter({
      'POST /auth/request-code': (_) => const FakeReply(200, {'resendAfterSec': 60}),
      'POST /auth/verify': (r) {
        final code = (r.data as Map)['code'];
        if (code != '111111') return const FakeReply(400, {'code': 'invalid_code', 'message': 'Неверный код'});
        return FakeReply(200, {'token': 'tok', 'isNew': isNew, 'me': meJson(name: isNew ? null : 'Анна')});
      },
      'PATCH /me': (_) => FakeReply(200, meJson(name: 'Анна', mode: 'driver')),
      'GET /me': (_) => FakeReply(200, meJson(name: 'Анна', mode: 'driver')),
    });

Future<void> _toCodeScreen(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), _phone);
  await tester.pump();
  await tester.tap(find.text('Получить код'));
  await tester.pumpAndSettle();
}

/// Шесть цифр — вход сам.
Future<void> _enterCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byKey(const Key('auth_code_field')), code);
  await tester.pumpAndSettle();
}

/// Код в поле без события набора (вставка): автовход не срабатывает, входит «Вход».
Future<void> _putCode(WidgetTester tester, String code) async {
  tester.widget<TextField>(find.byKey(const Key('auth_code_field'))).controller!.text = code;
  await tester.pump();
}

void main() {
  setUpAll(loadGilroy);

  group('формат номера', () {
    test('любой код страны: «+» и пробелы, 8–15 цифр', () {
      expect(formatPhone('375257774420'), '+375 25 777 44 20');
      expect(formatPhone('+79991234567'), '+7 999 123 45 67');
      expect(formatPhone('abc'), '');
      expect(formatPhone('+3751234567890123'), '+375 12 345 67 89 01 2'); // не больше 15 цифр
      expect(isValidPhone('+3752577'), isFalse); // 7 цифр
      expect(isValidPhone('+37525777'), isTrue); // 8 цифр
      expect(isValidPhone('+375123456789012'), isTrue); // 15 цифр
      expect(toE164('+375 25 777 44 20'), _phone);
    });
  });

  testWidgets('вход («Вход - Ввод номера (номер введён)», «Вход - Ввод номера (фокус)»): пустое поле в фокусе — подпись над примером номера, без наложения', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(fakeApp(fakeSession(_adapter(isNew: true)), const AuthScreen()));
    await tester.pump();
    final label = tester.getRect(find.text('Номер телефона'));
    final example = tester.getRect(find.text('+375 25 777 44 20'));
    expect(label.overlaps(example), isFalse, reason: 'подпись $label, пример $example');
    expect(label.bottom, lessThanOrEqualTo(example.top + 0.5));
  });

  testWidgets('номер → код → SMS: кнопка «Получить код» ждёт 8+ цифр, на сервер уходит E.164', (tester) async {
    usePhone(tester);
    final adapter = _adapter(isNew: true);
    await tester.pumpWidget(fakeApp(fakeSession(adapter), const AuthScreen()));

    await tester.enterText(find.byType(TextField), '+3752577');
    await tester.pump();
    await tester.tap(find.text('Получить код'));
    await tester.pump();
    expect(adapter.requests, isEmpty);

    await _toCodeScreen(tester);
    final sent = adapter.requests.single;
    expect(sent.path, '/auth/request-code');
    expect((sent.data as Map)['phone'], _phone);
    expect(find.textContaining('+375 25 777 44 20'), findsOneWidget);
  });

  test('«+7» и «+1» — ровно 11 цифр, остальные коды — 8–15', () {
    expect(isValidPhone('+7 900 000 00 0'), isFalse); // 10 цифр
    expect(isValidPhone('+7 900 000 00 01'), isTrue); // 11
    expect(isValidPhone('+7 900 000 00 012'), isFalse); // 12
    expect(isValidPhone('+1 202 555 01'), isFalse); // 10
    expect(isValidPhone('+1 202 555 01 23'), isTrue); // 11
    expect(isValidPhone('+1 202 555 01 234'), isFalse); // 12
    expect(isValidPhone('+44 20 7946 09'), isTrue); // 10
  });

  testWidgets('«Получить код» для «+7» ждёт ровно 11 цифр, для «+44» хватает 10', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(fakeApp(fakeSession(_adapter(isNew: true)), const AuthScreen()));
    VoidCallback? getCode() => tester.widget<CtaButton>(find.byType(CtaButton)).onPressed;
    Future<void> type(String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
    }

    await type('+7900000000');
    expect(getCode(), isNull, reason: '10 цифр');
    await type('+79000000001');
    expect(getCode(), isNotNull, reason: '11 цифр');
    await type('+790000000012');
    expect(getCode(), isNull, reason: '12 цифр');
    await type('+4420794609');
    expect(getCode(), isNotNull, reason: '+44, 10 цифр');
  });

  testWidgets('неверный код — ячейки пусты, поле в фокусе, клавиатура открыта, надпись до первой цифры', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(fakeApp(fakeSession(_adapter(isNew: true)), const AuthScreen()));
    await _toCodeScreen(tester);
    final field = find.byKey(const Key('auth_code_field'));
    // Клавиатуру закрыли до ответа сервера: после ошибки она открыта снова.
    await _putCode(tester, '000000');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.tap(find.text('Вход'));
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(field);
    expect(input.controller!.text, isEmpty);
    expect(input.focusNode!.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(find.text('Неверный код подтверждения'), findsOneWidget);

    await tester.enterText(field, '1');
    await tester.pump();
    expect(find.text('Неверный код подтверждения'), findsNothing);
  });

  testWidgets('фокус в поле, а клавиатуру скрыли — после неверного кода она снова открыта', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(fakeApp(fakeSession(_adapter(isNew: true)), const AuthScreen()));
    await _toCodeScreen(tester);
    final field = find.byKey(const Key('auth_code_field'));
    await tester.showKeyboard(field);
    await _putCode(tester, '000000');
    tester.testTextInput.hide(); // «Назад» системы: клавиатура скрыта, фокус остался
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    await tester.tap(find.text('Вход'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('экран кода: промежуток между ячейками и «Отправить» — 24, как в «Вход - СМС код (неправильный код)»', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(fakeApp(fakeSession(_adapter(isNew: true)), const AuthScreen()));
    await _toCodeScreen(tester);
    expect(find.byWidgetPredicate((w) => w is SizedBox && w.height == 24 && w.width == null && w.child == null), findsOneWidget);
  });

  testWidgets('000000 → «Неверный код подтверждения», остаёмся на экране кода', (tester) async {
    usePhone(tester);
    final session = fakeSession(_adapter(isNew: true));
    await tester.pumpWidget(fakeApp(session, const AuthScreen()));
    await _toCodeScreen(tester);

    await _enterCode(tester, '000000');
    expect(find.text('Неверный код подтверждения'), findsOneWidget);
    expect(find.textContaining('Код не подходит'), findsOneWidget);
    expect(session.token, isNull);
    expect(find.text('route:profile_setup'), findsNothing);
  });

  testWidgets('«Вход - СМС код (неправильный код)»: при неверном коде «Вход» неактивна, пока код не изменён', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(fakeApp(fakeSession(_adapter(isNew: true)), const AuthScreen()));
    await _toCodeScreen(tester);
    VoidCallback? login() => tester.widget<CtaButton>(find.byType(CtaButton)).onPressed;

    await _enterCode(tester, '000000');
    expect(find.text('Неверный код подтверждения'), findsOneWidget);
    expect(login(), isNull);

    await tester.enterText(find.byKey(const Key('auth_code_field')), '0');
    await tester.pump();
    expect(find.text('Неверный код подтверждения'), findsNothing);
    await _putCode(tester, '000001');
    expect(login(), isNotNull);
  });

  // Строка «Продолжая, я соглашаюсь…» видна только в кадрах ввода телефона «Вход - Ввод номера (данные введены)» – «Вход - Базовый экран»; в кадрах кода
  // («Вход - СМС код (неправильный код)» – «Вход - СМС код (базовый экран)»), профиля («Создание профиля - Данные заполнены», «Создание профиля - Ввод имя», «Создание профиля - Загрузка фото», «Создание профиля - Базовый экран») и города («Выбор города») этот слой скрыт.
  testWidgets('строка согласия — только на вводе телефона («Вход - Ввод номера (данные введены)» – «Вход - Базовый экран»), на экране кода её нет («Вход - СМС код (код введён)» – «Вход - СМС код (базовый экран)»)', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(fakeApp(fakeSession(_adapter(isNew: true)), const AuthScreen()));
    await tester.pump();
    expect(find.byType(ConsentText), findsOneWidget);

    await _toCodeScreen(tester);
    expect(find.byType(ConsentText), findsNothing);
    await tester.enterText(find.byKey(const Key('auth_code_field')), '000001');
    await tester.pump();
    expect(find.byType(ConsentText), findsNothing);
  });

  testWidgets('нижняя панель по умолчанию — без строки согласия (профиль «Создание профиля - Данные заполнены», «Создание профиля - Ввод имя», «Создание профиля - Загрузка фото», «Создание профиля - Базовый экран»; город «Выбор города»)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CtaBar(children: [SizedBox()]))));
    expect(find.byType(ConsentText), findsNothing);
  });

  testWidgets('шестая цифра входит сама, без нажатия «Вход»; кнопка остаётся', (tester) async {
    usePhone(tester);
    final adapter = _adapter(isNew: true);
    await tester.pumpWidget(fakeApp(fakeSession(adapter), const AuthScreen()));
    await _toCodeScreen(tester);
    expect(find.text('Вход'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('auth_code_field')), '11111');
    await tester.pumpAndSettle();
    expect(adapter.requests.where((r) => r.path == '/auth/verify'), isEmpty, reason: 'пять цифр — не входим');

    await tester.enterText(find.byKey(const Key('auth_code_field')), '111111');
    await tester.pumpAndSettle();
    expect(find.text('route:profile_setup'), findsOneWidget);
    expect(adapter.requests.where((r) => r.path == '/auth/verify'), hasLength(1));
  });

  testWidgets('✓ клавиатуры при шести цифрах — вход', (tester) async {
    usePhone(tester);
    final adapter = _adapter(isNew: true);
    await tester.pumpWidget(fakeApp(fakeSession(adapter), const AuthScreen()));
    await _toCodeScreen(tester);
    final field = find.byKey(const Key('auth_code_field'));
    final input = tester.widget<TextField>(field);
    input.controller!.text = '111111'; // набрано, но автовход не сработал (вставка кода и т. п.)
    await tester.pump();
    await tester.showKeyboard(field);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('route:profile_setup'), findsOneWidget);
  });

  testWidgets('111111 и isNew → profile_setup, токен и профиль в сессии', (tester) async {
    usePhone(tester);
    final session = fakeSession(_adapter(isNew: true));
    await tester.pumpWidget(fakeApp(session, const AuthScreen()));
    await _toCodeScreen(tester);

    await _enterCode(tester, '111111');
    expect(find.text('route:profile_setup'), findsOneWidget);
    expect(session.token, 'tok');
    expect(session.me?.id, 'u1');
  });

  testWidgets('111111 и не isNew → PATCH /me с выбранными городом и ролью, затем shell', (tester) async {
    usePhone(tester);
    final adapter = _adapter(isNew: false);
    final session = fakeSession(adapter)
      ..pendingCityId = 7
      ..pendingMode = UserMode.driver;
    await tester.pumpWidget(fakeApp(session, const AuthScreen()));
    await _toCodeScreen(tester);

    await _enterCode(tester, '111111');
    expect(find.text('route:shell'), findsOneWidget);
    final patch = adapter.requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.path, '/me');
    expect((patch.data as Map)['cityId'], 7);
    expect((patch.data as Map)['mode'], 'driver');
    expect(session.pendingCityId, isNull);
  });

  testWidgets('не isNew без выбранных города и роли → без PATCH /me', (tester) async {
    usePhone(tester);
    final adapter = _adapter(isNew: false);
    await tester.pumpWidget(fakeApp(fakeSession(adapter), const AuthScreen()));
    await _toCodeScreen(tester);

    await _enterCode(tester, '111111');
    expect(find.text('route:shell'), findsOneWidget);
    expect(adapter.requests.where((r) => r.method == 'PATCH'), isEmpty);
  });

  testWidgets('таймер: через resendAfterSec секунд появляется «Отправить», повтор шлёт код снова', (tester) async {
    usePhone(tester);
    final adapter = _adapter(isNew: true);
    await tester.pumpWidget(fakeApp(fakeSession(adapter), const AuthScreen()));
    await _toCodeScreen(tester);
    expect(find.text('0:59'), findsNothing);
    expect(find.text('1:00'), findsOneWidget);
    expect(find.text('Отправить'), findsNothing);

    await tester.pump(const Duration(seconds: 59));
    expect(find.text('Отправить'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Отправить'), findsOneWidget);

    await tester.tap(find.text('Отправить'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(adapter.requests.where((r) => r.path == '/auth/request-code'), hasLength(2));
    expect(find.text('Отправить'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
