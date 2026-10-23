import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/theme/app_colors.dart';
import 'package:the_way/src/theme/app_size.dart';
import 'package:the_way/src/widgets/dashed_line.dart';
import 'package:the_way/src/widgets/route_fields.dart';

/// Маршрут «строками-полями» (тема route-dots: «Новый заказ - Маршрут», «Редактирование - Изменений нет» – «Обратное направление - Дата и время выставлены», «Редактирование - Изменений нет», «Редактирование - Изменения есть», «Профиль пассажира после принятия заявки», «Отлик»): поля по 52,
/// между ними 8; слева столбик 10 без зазора до полей (кадр: столбик 10 + поля 333 = 343); центры
/// точек — по центрам строк (26 + 60·N); начало — квадрат, остановка — круг, конец — пустой квадрат
/// (мастер, правка, обратная) или залитый (маршрут пассажира «Профиль пассажира после принятия заявки», «Отлик»).
void main() {
  Widget field(String text) => Container(height: 52, color: AppColors.bgSurface, child: Text(text));

  testWidgets('пунктир вдоль блока под полем (подсказки адреса) — тонкий, как между полями', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RouteFields(
          fields: [field('А'), field('Б')],
          belowIndex: 0,
          below: const SizedBox(height: 200, child: Text('подсказки')),
        ),
      ),
    ));
    final widths = tester.widgetList(find.byType(DashedLine)).map((w) => tester.getSize(find.byWidget(w)).width).toSet();
    expect(widths, {AppSize.stroke2});
  });

  testWidgets('конец маршрута пассажира («Профиль пассажира после принятия заявки») — залитый квадрат', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RouteFields(end: RouteEnd.filled, fields: [field('А'), field('Б')])),
    ));
    final end = tester.widget<Container>(find
        .byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 10)
        .last);
    expect((end.decoration! as BoxDecoration).color, AppColors.textPrimary);
  });

  testWidgets('конец маршрута мастера («Новый заказ - Маршрут») — пустой квадрат с обводкой 2', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RouteFields(fields: [field('А'), field('Б')]))));
    final end = tester.widget<Container>(find
        .byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 10)
        .last);
    final decoration = end.decoration! as BoxDecoration;
    expect(decoration.color, isNull);
    expect((decoration.border! as Border).top.width, 2);
  });

  testWidgets('points задаёт значки пары цен: остановка — круг, конец — пустой квадрат', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RouteFields(points: const [RoutePoint.stop, RoutePoint.end], fields: [field('А'), field('Б')])),
    ));
    final dots = tester
        .widgetList<Container>(find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 10))
        .map((c) => c.decoration! as BoxDecoration)
        .toList();
    expect(dots.first.borderRadius, BorderRadius.circular(AppSize.radiusFull));
    expect(dots.first.color, AppColors.textPrimary);
    expect(dots.last.color, isNull);
    expect(dots.last.borderRadius, BorderRadius.circular(AppSize.radius2));
  });
}
