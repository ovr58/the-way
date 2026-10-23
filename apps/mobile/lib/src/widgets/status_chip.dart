import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';

/// Плашка статуса (`status-label` на «Мои заказы - Есть заказы»): зелёная обводка 1, скругление в таблетку, текст 13.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSize.pad12, vertical: AppSize.pad4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.accentPrimary, width: AppSize.stroke1),
          borderRadius: BorderRadius.circular(AppSize.radiusFull),
        ),
        child: Text(label, style: AppType.bodyFootnote.copyWith(color: AppColors.textPrimary)),
      );
}
