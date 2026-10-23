import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/theme/app_colors.dart';
import 'package:the_way/src/widgets/app_input.dart';

Widget _app(Widget child) => MaterialApp(
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );

final _box = find.descendant(of: find.byType(AppInput), matching: find.byType(Container)).first;

Rect _value(WidgetTester tester) => tester.getRect(find.byType(EditableText));

Color _border(WidgetTester tester) {
  final box = tester.widget<Container>(_box);
  return ((box.foregroundDecoration! as BoxDecoration).border! as Border).top.color;
}

void main() {
  // Кадры «Создание профиля - Данные заполнены», «Добавление нового ТС» (с значением) и «Вход - Ввод номера (номер введён)» (в фокусе): подпись 12 над значением 15, рамка 52.
  testWidgets('заполненное поле: подпись над значением, прямоугольники не пересекаются («Создание профиля - Данные заполнены»)', (tester) async {
    final controller = TextEditingController(text: 'Анастасия');
    await tester.pumpWidget(_app(AppInput(label: 'Имя', controller: controller)));
    final label = tester.getRect(find.text('Имя'));
    final value = _value(tester);
    expect(label.overlaps(value), isFalse, reason: 'подпись $label, значение $value');
    expect(label.bottom, lessThanOrEqualTo(value.top + 0.5));
    expect(tester.getSize(_box).height, 52);
    expect(_border(tester), AppColors.borderDefault);
  });

  testWidgets('пустое поле без фокуса: подпись внутри как подсказка 15, пример не показан («Вход - Базовый экран»)', (tester) async {
    await tester.pumpWidget(_app(const AppInput(label: 'Номер телефона', hintText: '+375 25 777 44 20')));
    expect(find.text('Номер телефона'), findsOneWidget);
    expect(find.text('+375 25 777 44 20'), findsNothing);
    expect(tester.getSize(_box).height, 52);
  });

  testWidgets('пустое поле в фокусе: подпись над примером, не налезает («Вход - Ввод номера (номер введён)», «Вход - Ввод номера (фокус)»)', (tester) async {
    await tester.pumpWidget(_app(const AppInput(label: 'Номер телефона', hintText: '+375 25 777 44 20')));
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    final label = tester.getRect(find.text('Номер телефона'));
    final hint = tester.getRect(find.text('+375 25 777 44 20'));
    expect(label.overlaps(hint), isFalse, reason: 'подпись $label, пример $hint');
    expect(label.bottom, lessThanOrEqualTo(hint.top + 0.5));
    expect(tester.getSize(_box).height, 52);
    expect(_border(tester), AppColors.borderStrong);
  });

  testWidgets('ввод в пустое поле поднимает подпись, фокус при этом не теряется', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_app(AppInput(label: 'Имя', controller: controller)));
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'Анна');
    await tester.pump();
    expect(controller.text, 'Анна');
    expect(tester.getRect(find.text('Имя')).overlaps(_value(tester)), isFalse);
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
  });

  testWidgets('без своего контроллера значение тоже поднимает подпись', (tester) async {
    await tester.pumpWidget(_app(AppInput(label: 'Имя', onChanged: (_) {})));
    await tester.enterText(find.byType(EditableText), 'Анна');
    await tester.pump();
    expect(tester.getRect(find.text('Имя')).overlaps(_value(tester)), isFalse);
  });

  testWidgets('ошибка: рамка красная, строка ошибки под рамкой', (tester) async {
    await tester.pumpWidget(_app(const AppInput(label: 'Имя', errorText: 'Нужно имя')));
    expect(_border(tester), AppColors.statusError);
    expect(tester.getTopLeft(find.text('Нужно имя')).dy, greaterThanOrEqualTo(tester.getRect(find.byType(EditableText)).bottom));
  });
}
