import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';

/// Плашка «подпись + значение» (тема equal-tiles: «Дата и время», «Мест для пассажиров», «Стоимость»,
/// «Номер телефона» — «Детали поездки - Места есть», «Детали поездки - Скролл», «Поездка завершена», «Бронь подтверждена»): белая, рамка `border.default` 1, скругление 8, поля 8,
/// подпись 13/400 и через 4 значение 15/600. Одна на четыре экрана вместо четырёх копий.
class InfoTile extends StatelessWidget {
  const InfoTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSize.pad8),
        decoration: BoxDecoration(color: AppColors.bgSurface, borderRadius: BorderRadius.circular(AppSize.radius8)),
        // Рамка поверх содержимого, а не в расчёте размера: в кадре обводка внутри плашки 58.
        foregroundDecoration: BoxDecoration(
          border: Border.all(color: AppColors.borderDefault, width: AppSize.stroke1),
          borderRadius: BorderRadius.circular(AppSize.radius8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppType.bodyFootnote.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: AppSize.gap4),
            Text(value, style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
          ],
        ),
      );
}

/// Плашки в ряд через 4, поровну по ширине и **равной высоты**: если подпись одной переносится (узкий
/// экран, крупный шрифт), соседняя тянется по ней, а не висит посередине (тема equal-tiles).
class InfoTileRow extends StatelessWidget {
  const InfoTileRow({super.key, required this.children});

  final List<InfoTile> children;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSize.gap4),
              Expanded(child: children[i]),
            ],
          ],
        ),
      );
}
