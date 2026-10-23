import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import 'dashed_line.dart';

/// Конец маршрута: пустой квадрат (мастер, правка, обратная поездка — «Новый заказ - Маршрут», «Редактирование - Изменений нет» – «Обратное направление - Дата и время выставлены», «Редактирование - Изменений нет», «Редактирование - Изменения есть») или
/// залитый (маршрут пассажира — «Профиль пассажира после принятия заявки», «Отлик»).
enum RouteEnd { hollow, filled }

/// Значок строки: начало — залитый квадрат, остановка — залитый круг, конец — квадрат по [RouteEnd].
enum RoutePoint { start, stop, end }

/// Маршрут «строками-полями» (тема route-dots): поля [fields] столбцом через 8, слева столбик 10 без
/// зазора до полей (кадр: столбик 10 + поля 333 = 343). Точки стоят по центрам строк: начало — залитый
/// квадрат, остановка — залитый круг, конец — по [end]; между точками — пунктир толщиной 2 ([DashedLine]).
/// Высоту строки задаёт само поле (52 по кадру), а не подсчёт `IntrinsicHeight`: он завышает высоту поля
/// ввода, и между полями выходило 21–37 вместо 8.
class RouteFields extends StatelessWidget {
  const RouteFields({super.key, required this.fields, this.end = RouteEnd.hollow, this.points, this.below, this.belowIndex});

  final List<Widget> fields;
  final RouteEnd end;

  /// Значки строк, если они не следуют из места строки: пара цен «старт → остановка» (шаг цен).
  final List<RoutePoint>? points;

  /// Блок прямо под строкой [belowIndex] (подсказки адреса под полем ввода); пунктир идёт мимо него.
  final Widget? below;
  final int? belowIndex;

  // Точка маршрута в кадре — 10×10; такой ступени в шкале размеров нет.
  static const _point = 10.0;

  Widget _dot(int i, int last) {
    final point = points?[i] ?? (i == 0 ? RoutePoint.start : i == last ? RoutePoint.end : RoutePoint.stop);
    final isEnd = point == RoutePoint.end;
    final hollow = isEnd && end == RouteEnd.hollow;
    return Container(
      width: _point,
      height: _point,
      decoration: BoxDecoration(
        color: hollow ? null : AppColors.textPrimary,
        border: hollow ? Border.all(color: AppColors.textPrimary, width: AppSize.stroke2) : null,
        borderRadius: BorderRadius.circular(point == RoutePoint.stop ? AppSize.radiusFull : AppSize.radius2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = fields.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i <= last; i++) ...[
          Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(left: _point, bottom: i == last ? 0 : AppSize.gap8),
                child: fields[i],
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _point,
                child: LayoutBuilder(
                  builder: (context, box) {
                    // Центр точки — центр поля: промежуток 8 под полем к строке не относится.
                    final above = (box.maxHeight - (i == last ? 0 : AppSize.gap8) - _point) / 2;
                    return Column(
                      children: [
                        SizedBox(height: above, child: i == 0 ? null : const DashedLine()),
                        _dot(i, last),
                        if (i != last) const Expanded(child: DashedLine()),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          if (i == belowIndex && below != null)
            Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: _point, top: i == last ? AppSize.gap8 : 0, bottom: i == last ? 0 : AppSize.gap8),
                  child: below,
                ),
                // Пунктир 2 по центру столбика, как между полями: растянутый на ширину 10 он рисовал квадраты.
                if (i != last) const Positioned(left: 0, top: 0, bottom: 0, width: _point, child: Center(child: DashedLine())),
              ],
            ),
        ],
      ],
    );
  }
}
