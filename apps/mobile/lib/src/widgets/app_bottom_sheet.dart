import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';

/// Нижний лист (`Button Sheet`, «Создание профиля - Загрузка фото», «Добавление нового ТС»): серый фон, скругление сверху 16, ручка 43×5,
/// заголовок 17/700, поля 16. Показывается поверх `overlay.scrim`.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;

  /// Справа от заголовка («Очистить» в фильтре, «Фильтр»).
  final Widget? trailing;

  static Future<T?> show<T>(BuildContext context, {required String title, required Widget child}) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: AppColors.overlayScrim,
        builder: (_) => AppBottomSheet(title: title, child: child),
      );

  // Ручка листа в кадре — 43×5.
  static const _handleWidth = 43.0;
  static const _handleHeight = 5.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSize.radius16)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSize.pad16, AppSize.pad8, AppSize.pad16, AppSize.pad8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: _handleWidth,
                  height: _handleHeight,
                  decoration: BoxDecoration(
                    color: AppColors.bgGrabber,
                    borderRadius: BorderRadius.circular(AppSize.radius16),
                  ),
                ),
              ),
              const SizedBox(height: AppSize.gap8),
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: AppType.titlesHeadline.copyWith(color: AppColors.textPrimary)),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: AppSize.gap16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
