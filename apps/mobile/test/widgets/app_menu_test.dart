import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/widgets/app_button.dart';

import '../screens/shot.dart';
import '../screens/world.dart';

/// Меню «⋯» по кадру «Редактирование - Пассажиры есть»: выпадает под кнопкой, кнопка и заголовок видны; ширина 307, правый край
/// по полю 16; строки по 46, текст 17 целиком; нажатие на «⋯» ещё раз меню закрывает.
void main() {
  shotInit();

  Future<ShotWorld> open(WidgetTester tester) async {
    shotSurface(tester, height: 882);
    final world = ShotWorld(mode: UserMode.driver)
      ..routes['GET /trips/t1'] = tripDetails(isMine: true, seatsTotal: 4, seatsFree: 2, carJson: myCars.first, paidTotal: 600)
      ..routes['GET /trips/t1/bookings'] = <Object?>[];
    await world.open(tester, route: 'driver_trips/details', args: 't1');
    return world;
  }

  Finder dots() => find.byType(AppIconButton).last;

  /// Меню — столбец строк: его верх и края — у первой строки (полей вокруг строк в кадре нет).
  Rect menuOf(WidgetTester tester) =>
      tester.getRect(find.ancestor(of: find.text('Изменить количество мест'), matching: find.byType(InkWell)).first);

  testWidgets('меню под кнопкой «⋯», 307 в ширину, у правого поля 16', (tester) async {
    final world = await open(tester);
    final button = tester.getRect(dots());
    await world.tap(tester, dots());
    final menu = menuOf(tester);
    expect(menu.top, greaterThanOrEqualTo(button.bottom));
    expect(menu.width, 307);
    expect(menu.right, 375 - 16);
    expect(find.text('Поездка'), findsOneWidget);
    debugDisableShadows = true; // shotSettle включает тени; проверка среды в конце теста ждёт исходное
  });

  testWidgets('строки 46, текст «Завершить приём пассажиров» без обрезки', (tester) async {
    final world = await open(tester);
    await world.tap(tester, dots());
    for (final text in ['Изменить количество мест', 'Редактировать', 'Завершить приём пассажиров']) {
      final row = find.ancestor(of: find.text(text), matching: find.byType(InkWell)).first;
      expect(tester.getSize(row).height, 46, reason: text);
      final label = tester.renderObject<RenderParagraph>(find.text(text));
      expect(label.didExceedMaxLines, isFalse, reason: text);
    }
    debugDisableShadows = true; // shotSettle включает тени; проверка среды в конце теста ждёт исходное
  });

  testWidgets('второе нажатие на «⋯» закрывает меню', (tester) async {
    final world = await open(tester);
    await world.tap(tester, dots());
    expect(find.text('Редактировать'), findsOneWidget);
    await tester.tapAt(tester.getCenter(dots()));
    await shotSettle(tester);
    expect(find.text('Редактировать'), findsNothing);
    debugDisableShadows = true; // shotSettle включает тени; проверка среды в конце теста ждёт исходное
  });
}
