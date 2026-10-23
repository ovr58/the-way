import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/cars/data/car_catalog.dart';
import 'package:the_way/src/widgets/app_button.dart';

import 'add_car_test.dart' show field, open, pickBrand;

/// «Другая модель»: свободный ввод 1–40 символов вместо модели из каталога.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => rootBundle.loadString(CarCatalog.asset));

  /// Кнопка «Готово» шторки свободного ввода.
  AppButton done(WidgetTester tester) =>
      tester.widget<AppButton>(find.widgetWithText(AppButton, 'Готово'));

  testWidgets('нет в списке → «Другая модель» → ввод названия → оно в поле «Модель»', (tester) async {
    await open(tester);
    await pickBrand(tester, 'gaz', 'ГАЗ');
    await tester.tap(field('Модель'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cars-search')), 'qqqzzz');
    await tester.pumpAndSettle();
    expect(find.text('Ничего не найдено'), findsOneWidget);

    await tester.tap(find.text('Другая модель'));
    await tester.pumpAndSettle();
    final input = find.descendant(of: find.byKey(const Key('cars-other-model')), matching: find.byType(TextField));
    await tester.enterText(input, '   ');
    await tester.pump();
    expect(done(tester).onPressed, isNull);

    await tester.enterText(input, 'Ё' * 45);
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text.length, 40);

    await tester.enterText(input, ' Валдай ');
    await tester.pump();
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field('Модель')).controller!.text, 'Валдай');
  });
}
