import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_routes.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/notification_layout.dart';
import '../../../widgets/success_badge.dart';

/// «Бронь отменена» «Бронь отменена»: сумма и срок возврата за оплаченную бронь. «На главную» — вкладка «Поездки»
/// оболочки.
class BookingCancelledScreen extends StatelessWidget {
  const BookingCancelledScreen({super.key, required this.amount, required this.days});

  final int amount;
  final int days;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NotificationLayout(
      badge: const SuccessBadge(),
      title: l10n.cancelDone,
      body: l10n.cancelDoneRefund(amount, days),
      buttons: [
        AppButton(
          key: const Key('cancelled_home'),
          label: l10n.cancelHome,
          onPressed: () =>
              Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.shell, (_) => false, arguments: 0),
        ),
      ],
    );
  }
}
