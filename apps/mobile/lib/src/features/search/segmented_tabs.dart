import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_size.dart';
import '../../theme/app_type.dart';

/// Две вкладки-таблетки «Автомобили / Автобусы» (слой `roles-switch` «Базовые экраны - Поездки есть»): серая подложка
/// с рамкой, выбранная вкладка залита зелёным. Те же вкладки — «Поездки / Посылки» в фильтре.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  
  /// Выбранная вкладка; `null` — ни одна не выбрана (фильтр «Поездки / Посылки» по умолчанию).
  final int? index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSize.pad4),
      decoration: BoxDecoration(
        color: AppColors.bgControl,
        borderRadius: BorderRadius.circular(AppSize.radius8),
        border: Border.all(color: AppColors.borderMuted, width: AppSize.stroke1),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Material(
                color: i == index ? AppColors.accentPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSize.radius4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSize.radius4),
                  onTap: () => onChanged(i),
                  child: Container(
                    height: AppSize.height40,
                    alignment: Alignment.center,
                    child: Text(
                      labels[i],
                      style: AppType.body2.copyWith(
                        color: i == index ? AppColors.textOnAccent : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
