import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/trip_new/steps/type_step.dart';
import 'package:the_way/src/theme/app_colors.dart';
import 'package:the_way/src/widgets/app_button.dart';

import '../screens/shot.dart';
import '../screens/world.dart';

/// Кнопка «+ …» пустых списков («Мои заказы - Нет заказов», «Базовые экраны - Поездок нет», «Транспортные средства»): одна на всё приложение — зелёная, плюс 14 слева,
/// ширина по тексту, 42 в высоту. «Создать заказ» делает то же, что «+» нижней панели.
void main() {
  shotInit();

  testWidgets('вид по кадру «Транспортные средства»: 42 в высоту, ширина по тексту, плюс 14 слева от подписи', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: AppAddButton(label: 'Добавить ТС', onPressed: () {}))),
    ));
    final button = find.byType(AppAddButton);
    expect(tester.getSize(button).height, 42);
    expect(tester.getSize(button).width, lessThan(160));
    final plus = find.descendant(of: button, matching: find.byType(SvgPicture));
    expect(tester.getSize(plus), const Size(14, 14));
    expect(tester.getTopRight(plus).dx, lessThan(tester.getTopLeft(find.text('Добавить ТС')).dx));
    final material = tester.widget<Material>(find.descendant(of: button, matching: find.byType(Material)).first);
    expect(material.color, AppColors.accentPrimary);
  });

  testWidgets('«Мои заказы - Нет заказов»: у пассажира «Создать заказ» на пустом списке открывает мастер заказа', (tester) async {
    shotSurface(tester);
    final world = ShotWorld()
      ..routes['GET /bookings/mine'] = <Object?>[]
      ..routes['GET /orders/mine'] = <Object?>[];
    await world.open(tester, args: 1);
    await world.tap(tester, find.widgetWithText(AppAddButton, 'Создать заказ'));
    expect(find.byType(TypeStep), findsOneWidget);
    expect(find.text('Шаг 1 из 3'), findsOneWidget);
    debugDisableShadows = true; // shotSettle включает тени; проверка среды в конце теста ждёт исходное
  });

  testWidgets('«Базовые экраны - Поездок нет»: у водителя «Создать заказ» на пустом списке открывает мастер поездки', (tester) async {
    shotSurface(tester);
    final world = ShotWorld(mode: UserMode.driver)..routes['GET /trips/mine'] = <Object?>[];
    await world.open(tester, args: 1);
    await world.tap(tester, find.widgetWithText(AppAddButton, 'Создать заказ'));
    expect(find.byType(TypeStep), findsOneWidget);
    debugDisableShadows = true; // shotSettle включает тени; проверка среды в конце теста ждёт исходное
  });
}
