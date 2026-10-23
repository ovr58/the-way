import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_size.dart';
import '../../theme/app_type.dart';
import '../../widgets/app_button.dart';
import '../../widgets/success_badge.dart';
import 'limit_screen.dart';

/// «Заказ опубликован!» заказа пассажира — раскладка «Новый заказ - Заказ создан» без блока лимитов и без «Добавить обратный
/// маршрут»: значок, заголовок, текст по центру высоты; «Смотреть мои заказы» — оболочка, вкладка «Мои
/// заказы» (раздел по режиму профиля — у пассажира его заказы).
class OrderCreatedScreen extends StatelessWidget {
  const OrderCreatedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
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
                        const SuccessBadge(),
                        const SizedBox(height: AppSize.gap8),
                        Text(
                          l10n.tripNewCreatedTitle,
                          textAlign: TextAlign.center,
                          style: AppType.title2.copyWith(color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: AppSize.gap8),
                        Text(
                          l10n.orderCreatedBody,
                          textAlign: TextAlign.center,
                          style: AppType.body2.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                color: AppColors.bgSurface,
                padding: const EdgeInsets.all(AppSize.pad16),
                child: AppButton(
                  label: l10n.tripNewCreatedOrders,
                  size: AppButtonSize.medium,
                  onPressed: () => openDriverTrips(navigator),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
