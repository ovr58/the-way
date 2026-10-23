import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';

/// Раскладка экрана-уведомления `notification-elements` («Заказ - Оплата прошла», «Бронь отменена»): по центру иллюстрация,
/// заголовок, текст и необязательная плашка, внизу панель кнопок.
class NotificationLayout extends StatelessWidget {
  const NotificationLayout({
    super.key,
    required this.badge,
    required this.title,
    required this.body,
    this.notice,
    required this.buttons,
  });

  final Widget badge;
  final String title;
  final String body;
  final Widget? notice;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgScreen,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSize.pad16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        badge,
                        const SizedBox(height: AppSize.gap8),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: AppType.title2.copyWith(color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(height: AppSize.gap8),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            body,
                            textAlign: TextAlign.center,
                            style: AppType.body2.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                        if (notice != null) ...[const SizedBox(height: AppSize.gap8), notice!],
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSize.pad16),
                child: Column(children: buttons),
              ),
            ],
          ),
        ),
      );
}
