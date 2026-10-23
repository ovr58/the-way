import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';
import 'app_button.dart';
import 'app_icon.dart';

/// Шапка экрана («Top Navigation» высотой 60): слева «назад» (если [onBack]), заголовок по
/// центру, справа [trailing]. Статус-бар даёт `SafeArea`.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.title, this.onBack, this.trailing, this.bordered = true});

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Нижняя линия `border.default` (у части кадров её нет).
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        border: bordered
            ? const Border(bottom: BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1))
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppSize.height60,
          child: Row(
            children: [
              SizedBox(
                width: AppSize.height56,
                child: onBack == null
                    ? null
                    : Center(
                        child: AppIconButton(
                          onPressed: onBack,
                          child: const AppIcon('arrows_alt_arrow_left', size: AppSize.icon24),
                        ),
                      ),
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppType.title3.copyWith(color: AppColors.textPrimary),
                ),
              ),
              SizedBox(width: AppSize.height56, child: trailing == null ? null : Center(child: trailing)),
            ],
          ),
        ),
      ),
    );
  }
}
