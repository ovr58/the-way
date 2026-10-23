import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/auth/auth_screen.dart';
import 'package:the_way/src/features/auth/data/phone_country.dart';

import 'fake_api.dart';

/// Ответ Android на запрос страны телефона; `null` — страна неизвестна, [error] — отказ канала.
void _mockCountry(WidgetTester tester, String? iso, {Exception? error}) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(phoneCountryChannel, (call) async {
    expect(call.method, 'countryIso');
    if (error != null) throw error;
    return iso;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(phoneCountryChannel, null));
}

String _fieldText(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText)).controller.text;

void main() {
  setUpAll(loadGilroy);

  group('справочник кодов стран («Вход - Ввод номера (данные введены)»)', () {
    test('страна SIM или сети → код страны', () {
      expect(callingCodeOf('ru'), '7');
      expect(callingCodeOf('kz'), '7');
      expect(callingCodeOf('by'), '375');
      expect(callingCodeOf('BY'), '375');
      expect(callingCodeOf('us'), '1');
      expect(callingCodeOf('de'), '49');
      expect(callingCodeOf('uz'), '998');
      expect(callingCodeOf('am'), '374');
    });

    test('неизвестная страна → нет кода', () {
      expect(callingCodeOf(null), isNull);
      expect(callingCodeOf(''), isNull);
      expect(callingCodeOf('xx'), isNull);
    });

    test('полный справочник: все страны ISO, код — 1–3 цифры', () {
      expect(countryCallingCodes.length, greaterThanOrEqualTo(240));
      for (final entry in countryCallingCodes.entries) {
        expect(entry.key, matches(RegExp(r'^[a-z]{2}$')), reason: entry.key);
        expect(entry.value, matches(RegExp(r'^[1-9]\d{0,2}$')), reason: entry.key);
      }
    });

    test('начало номера: «+код» или только «+»', () {
      expect(phonePrefixFor('by'), '+375');
      expect(phonePrefixFor('ru'), '+7');
      expect(phonePrefixFor(null), '+');
      expect(phonePrefixFor('xx'), '+');
    });
  });

  group('поле номера («Вход - Ввод номера (данные введены)»): код страны подставлен заранее', () {
    testWidgets('SIM Беларуси → «+375», курсор после кода', (tester) async {
      usePhone(tester);
      _mockCountry(tester, 'by');
      await tester.pumpWidget(fakeApp(fakeSession(FakeAdapter({})), const AuthScreen()));
      await tester.pump();

      expect(_fieldText(tester), '+375');
      final selection = tester.widget<EditableText>(find.byType(EditableText)).controller.selection;
      expect(selection, const TextSelection.collapsed(offset: 4));
    });

    testWidgets('страна неизвестна → только «+»', (tester) async {
      usePhone(tester);
      _mockCountry(tester, null);
      await tester.pumpWidget(fakeApp(fakeSession(FakeAdapter({})), const AuthScreen()));
      await tester.pump();

      expect(_fieldText(tester), '+');
    });

    testWidgets('канала нет (не Android) → только «+»', (tester) async {
      usePhone(tester);
      _mockCountry(tester, null, error: MissingPluginException());
      await tester.pumpWidget(fakeApp(fakeSession(FakeAdapter({})), const AuthScreen()));
      await tester.pump();

      expect(_fieldText(tester), '+');
    });

    testWidgets('ошибка Android → только «+»', (tester) async {
      usePhone(tester);
      _mockCountry(tester, null, error: PlatformException(code: 'telephony'));
      await tester.pumpWidget(fakeApp(fakeSession(FakeAdapter({})), const AuthScreen()));
      await tester.pump();

      expect(_fieldText(tester), '+');
    });

    testWidgets('номер набран раньше ответа Android — поле не трогаем', (tester) async {
      usePhone(tester);
      final reply = Completer<String?>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(phoneCountryChannel, (_) => reply.future);
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(phoneCountryChannel, null));
      await tester.pumpWidget(fakeApp(fakeSession(FakeAdapter({})), const AuthScreen()));
      await tester.enterText(find.byType(EditableText), '+7999');
      await tester.pump();

      reply.complete('by');
      await tester.pump();
      expect(_fieldText(tester), '+7 999');
    });

    testWidgets('код можно стереть и набрать свой', (tester) async {
      usePhone(tester);
      _mockCountry(tester, 'by');
      await tester.pumpWidget(fakeApp(fakeSession(FakeAdapter({})), const AuthScreen()));
      await tester.pump();

      await tester.enterText(find.byType(EditableText), '');
      await tester.pump();
      expect(_fieldText(tester), '');
      await tester.enterText(find.byType(EditableText), '+7999');
      await tester.pump();
      expect(_fieldText(tester), '+7 999');
    });
  });
}
