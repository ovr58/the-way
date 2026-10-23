import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/success_badge.dart';

/// «Место забронировано» («Заказ - Оплата прошла»): оплата прошла. «Мои поездки» ведёт в «Мои заказы» пассажира
/// (вкладка 1 оболочки), «Написать водителю» — в заглушку чата.
class BookingPaidScreen extends StatelessWidget {
  const BookingPaidScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSize.pad16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SuccessBadge(),
                      const SizedBox(height: AppSize.gap8),
                      Text(
                        l10n.bookingPaidTitle,
                        textAlign: TextAlign.center,
                        style: AppType.title2.copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: AppSize.gap8),
                      Text(
                        l10n.bookingPaidBody,
                        textAlign: TextAlign.center,
                        style: AppType.body2.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSize.pad16),
              child: Column(
                children: [
                  AppButton(
                    key: const Key('paid_trips'),
                    label: l10n.bookingPaidTrips,
                    size: AppButtonSize.medium,
                    onPressed: () => Navigator.of(context)
                        .pushNamedAndRemoveUntil(AppRoutes.shell, (_) => false, arguments: 1),
                  ),
                  const SizedBox(height: AppSize.gap8),
                  AppButton(
                    key: const Key('paid_write'),
                    label: l10n.tripDetailsWrite,
                    size: AppButtonSize.medium,
                    kind: AppButtonKind.outline,
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.stub, arguments: l10n.systemStubChat),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
