import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_icon.dart';

/// Шапка экранов выбора города и создания профиля («Создание профиля - Данные заполнены» – «Создание профиля - Базовый экран»): значок слева без действия,
/// заголовок по центру, линия снизу.
class LeadingIconHeader extends StatelessWidget {
  const LeadingIconHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bgScreen,
        border: Border(bottom: BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppSize.height60,
          child: Row(
            children: [
              SizedBox(
                width: AppSize.height56,
                child: Center(
                  child: Container(
                    width: AppSize.height40,
                    height: AppSize.height40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.bgSurfaceAlt, shape: BoxShape.circle),
                    child: const AppIcon('users_user_id', size: AppSize.icon24, color: AppColors.textSecondary),
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
              const SizedBox(width: AppSize.height56),
            ],
          ),
        ),
      ),
    );
  }
}
