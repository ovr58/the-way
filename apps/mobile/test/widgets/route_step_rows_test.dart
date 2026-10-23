import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/trip_new/steps/route_step.dart';
import 'package:the_way/src/features/trip_new/wizard_controller.dart';
import 'package:the_way/src/theme/app_colors.dart';
import 'package:the_way/src/widgets/app_input.dart';

import '../features/trip_new/support.dart';
import '../support/gilroy.dart';

/// Маршрут «строками-полями» (тема route-dots: «Новый заказ - Маршрут», «Редактирование - Изменений нет» – «Обратное направление - Дата и время выставлены», «Редактирование - Изменений нет», «Редактирование - Изменения есть», «Профиль пассажира после принятия заявки», «Отлик»): поля по 52,
/// между ними 8; слева столбик 10 без зазора до полей (кадр: столбик 10 + поля 333 = 343); центры
/// точек — по центрам строк (26 + 60·N); начало — квадрат, остановка — круг, конец — пустой квадрат
/// (мастер, правка, обратная) или залитый (маршрут пассажира «Профиль пассажира после принятия заявки», «Отлик»).
void main() {
  setUpAll(loadGilroy);

  void view(WidgetTester tester) {
    tester.view.physicalSize = const Size(375 * 2, 812 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  /// Точки маршрута — квадраты и круги 10×10 цвета text.primary.
  List<Rect> dots(WidgetTester tester) => find
      .byWidgetPredicate((w) =>
          w is Container &&
          w.constraints?.maxWidth == 10 &&
          w.constraints?.maxHeight == 10 &&
          w.decoration is BoxDecoration &&
          ((w.decoration! as BoxDecoration).color == AppColors.textPrimary || (w.decoration! as BoxDecoration).border != null))
      .evaluate()
      .map((e) => tester.getRect(find.byWidget(e.widget)))
      .toList();

  testWidgets('мастер «Новый заказ - Маршрут»: три поля через 8, точки по центрам полей', (tester) async {
    view(tester);
    final controller = WizardController(repositoryOf(FakeAdapter({})))..addStop();
    await tester.pumpWidget(app(RouteStep(controller: controller)));
    await tester.pumpAndSettle();
    // Первые три поля — маршрут; ниже на шаге — дата, время и цена.
    final fields = find.byType(AppInput).evaluate().take(3).map((e) => tester.getRect(find.byWidget(e.widget))).toList();
    for (var i = 1; i < fields.length; i++) {
      expect(fields[i].top - fields[i - 1].bottom, 8, reason: 'промежуток между полями $i');
    }
    for (final f in fields) {
      expect(f.height, 52);
    }
    final points = dots(tester);
    expect(points, hasLength(3));
    for (var i = 0; i < 3; i++) {
      expect(points[i].center.dy, fields[i].center.dy, reason: 'точка $i по центру поля');
      expect(fields[i].left - points[i].right, 0, reason: 'поле вплотную к столбику, как в кадре');
    }
  });

}
