import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/auth/auth_screen.dart';

import 'fake_api.dart';

const _phone = '+375257774420';

FakeAdapter _adapter() => FakeAdapter({
      'POST /auth/request-code': (_) => const FakeReply(200, {'resendAfterSec': 60}),
      'POST /auth/verify': (r) => FakeReply(200, {'token': 'tok', 'isNew': true, 'me': meJson()}),
    });

Finder get _field => find.byKey(const Key('auth_code_field'));

String _text(WidgetTester tester) => tester.widget<TextField>(_field).controller!.text;

/// Клавиатура или касание ставят курсор скрытого поля не в конец текста (а ячейка с курсором на экране — по длине).
Future<void> _caretAt(WidgetTester tester, int offset) async {
  await tester.showKeyboard(_field);
  tester.testTextInput.updateEditingValue(TextEditingValue(text: _text(tester), selection: TextSelection.collapsed(offset: offset)));
  await tester.pump();
}

Future<void> _open(WidgetTester tester) async {
  usePhone(tester);
  await tester.pumpWidget(fakeApp(fakeSession(_adapter()), const AuthScreen()));
  await tester.enterText(find.byType(TextField), _phone);
  await tester.pump();
  await tester.tap(find.text('Получить код'));
  await tester.pumpAndSettle();
}

/// Цифры, нарисованные в ячейках.
String _cells(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: find.byType(Stack), matching: find.byType(Text)))
    .map((t) => t.data ?? '')
    .where((s) => RegExp(r'^\d$').hasMatch(s))
    .join();

void main() {
  setUpAll(loadGilroy);

  testWidgets('«Стереть» при курсоре не в конце стирает последнюю цифру, курсор — в её ячейке', (tester) async {
    await _open(tester);
    await tester.enterText(_field, '123');
    await tester.pump();

    await _caretAt(tester, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(_text(tester), '12', reason: 'стёрта предыдущая цифра, а не ничего');
    expect(_cells(tester), '12');

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(_text(tester), '', reason: 'подряд по всем ячейкам');
  });

  testWidgets('после стирания шестая цифра снова уходит сама', (tester) async {
    await _open(tester);
    await tester.enterText(_field, '12345');
    await tester.pump();
    await _caretAt(tester, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(_text(tester), '1234');

    await tester.enterText(_field, '111111');
    await tester.pumpAndSettle();
    expect(find.text('route:profile_setup'), findsOneWidget);
  });
}
