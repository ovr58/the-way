import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/theme/app_colors.dart';
import 'package:the_way/src/widgets/app_button.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

Material _material(WidgetTester tester) =>
    tester.widget<Material>(find.descendant(of: find.byType(AppButton), matching: find.byType(Material)).first);

void main() {
  dangerTests();

  // Кадры «Вход - Ввод номера (номер введён)», «Вход - Ввод номера (фокус)», «Создание профиля - Ввод имя», «Создание профиля - Загрузка фото», «Новый заказ - Маршрут»: неактивная основная кнопка — заливка bg.screen, контур border.default 1,
  // подпись text.secondary (#0c0c0c @ 0.5); непрозрачность не меняется.
  testWidgets('неактивная основная кнопка: заливка экрана, серый контур и серая подпись', (tester) async {
    await tester.pumpWidget(_app(const AppButton(label: 'Далее', onPressed: null)));
    final material = _material(tester);
    expect(material.color, AppColors.bgScreen);
    final side = (material.shape! as RoundedRectangleBorder).side;
    expect(side.color, AppColors.borderDefault);
    expect(side.width, 1);
    expect(tester.widget<Text>(find.text('Далее')).style?.color, AppColors.textSecondary);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('активная основная кнопка — зелёная заливка и белая подпись', (tester) async {
    await tester.pumpWidget(_app(AppButton(label: 'Далее', onPressed: () {})));
    final material = _material(tester);
    expect(material.color, AppColors.accentPrimary);
    expect((material.shape! as RoundedRectangleBorder).side, BorderSide.none);
    expect(tester.widget<Text>(find.text('Далее')).style?.color, AppColors.textOnAccent);
  });

  testWidgets('неактивная кнопка не нажимается', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(AppButton(label: 'Далее', onPressed: null, loading: false)));
    await tester.tap(find.text('Далее'));
    expect(taps, 0);
  });

  testWidgets('загрузка: кнопка остаётся зелёной со счётчиком', (tester) async {
    await tester.pumpWidget(_app(AppButton(label: 'Далее', onPressed: () {}, loading: true)));
    expect(_material(tester).color, AppColors.accentPrimary);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

// Кадры «Детали поездки - Лимит отмен», «Детали поездки - Отмена брони», «Детали поездки - Лимит отмен»: красная кнопка «Да, отменить» — заливка status.error #EB4245 и белая подпись;
// контурный вариант — обводка 1 и подпись того же цвета, заливки нет.
void dangerTests() {
  testWidgets('danger — красная заливка и белая подпись', (tester) async {
    await tester.pumpWidget(_app(AppButton(label: 'Да, отменить', kind: AppButtonKind.danger, onPressed: () {})));
    final material = _material(tester);
    expect(material.color, const Color(0xFFEB4245));
    expect((material.shape! as RoundedRectangleBorder).side, BorderSide.none);
    expect(tester.widget<Text>(find.text('Да, отменить')).style?.color, AppColors.textOnAccent);
  });

  testWidgets('dangerOutline — красная обводка 1, красная подпись, заливки нет', (tester) async {
    await tester.pumpWidget(_app(AppButton(label: 'Отменить бронь', kind: AppButtonKind.dangerOutline, onPressed: () {})));
    final material = _material(tester);
    expect(material.color, Colors.transparent);
    final side = (material.shape! as RoundedRectangleBorder).side;
    expect(side.color, const Color(0xFFEB4245));
    expect(side.width, 1);
    expect(tester.widget<Text>(find.text('Отменить бронь')).style?.color, const Color(0xFFEB4245));
  });
}
