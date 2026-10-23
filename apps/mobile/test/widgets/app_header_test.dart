import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/theme/app_colors.dart';
import 'package:the_way/src/widgets/app_header.dart';

/// Шапка в кадрах: нижняя линия `border.default` есть у 99 из 135 кадров с шапкой («Вход - Просмотр условий использования», «Вход - СМС код (неправильный код)» – «Создание профиля - Базовый экран», «Новый заказ - Тип заказа» – «Новый заказ - Выбор авто - выбрано авто»,
/// «Базовые экраны - Поездок нет» – «Фильтр», «Заказ - Оплата прошла» – «Базовые экраны - Идёт регистрация пассажиров», «Мои заказы - Нет заказов», «Мои заказы - Есть заказы», «Бронь отменена», «Базовые экраны - Поездок нет», «Профиль - Профиль пассажира» – «Профиль пассажира после принятия заявки», «Пришёл отклик» – «Ошибка»), нет у 36 («Вход - Ввод номера (данные введены)» – «Вход - Базовый экран», «Детали поездки - Мест нет»,
/// «Детали поездки - Лимит отмен» – «Экран поездки после оплаты», «Детали поездки - Бронь есть» – «Детали поездки - Отмена брони», «Детали поездки - Лимит отмен», «Детали поездки созданной водителем - Без пассажиров» – «Редактирование - Нельзя выбрать кол-во мест меньше чем УЖЕ занято», «Редактирование - Пассажиры есть» – «Отлик», «Аккаунт заблокирован»). Значение по умолчанию — по большинству.
void main() {
  Border? border(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(find.descendant(of: find.byType(AppHeader), matching: find.byType(DecoratedBox)).first);
    return (box.decoration as BoxDecoration).border as Border?;
  }

  testWidgets('по умолчанию — нижняя линия border.default 1', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AppHeader(title: 'Профиль'))));
    final b = border(tester)!;
    expect(b.bottom.color, AppColors.borderDefault);
    expect(b.bottom.width, 1);
    expect(b.top, BorderSide.none);
  });

  testWidgets('bordered: false — без линии, как в кадрах-исключениях', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AppHeader(title: 'Поездка', bordered: false))));
    expect(border(tester), isNull);
  });
}
