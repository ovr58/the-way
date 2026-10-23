import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';
import 'app_icon.dart';

/// Жёлтая плашка-предупреждение со значком («Бронь отменена» `block-notice`, «Детали поездки - Лимит отмен» `cancel-notice`): заливка
/// #EBC942 @ 0.12, обводка 1 `accent.warning`, радиус 12, поля 12.
class NoticePlaque extends StatelessWidget {
  const NoticePlaque(this.text, {super.key});

  final String text;

  // Заливка кадра; токена с таким цветом в палитре нет.
  static const _fill = Color(0x1FEBC942);

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSize.pad12),
        decoration: BoxDecoration(
          color: _fill,
          borderRadius: BorderRadius.circular(AppSize.radius12),
          border: Border.all(color: AppColors.accentWarning, width: AppSize.stroke1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppIcon('essentional_danger_circle', size: AppSize.icon24, color: AppColors.accentWarning),
            const SizedBox(width: AppSize.gap10),
            Expanded(child: Text(text, style: AppType.body2.copyWith(color: AppColors.textPrimary))),
          ],
        ),
      );
}
