import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_routes.dart';
import '../../../app/session.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_button.dart';
import '../../search/filter/popup_card.dart';
import '../cancel/cancel_flow.dart';
import '../data/booking_changes.dart';
import '../data/booking_repository.dart';

/// Прозрачный маршрут окна ответа: `booking/accepted` или `booking/declined` с `bookingId`,
/// затемнение сзади. Его же показывает `checkUpdates` (`await` — до закрытия окна). Результат
/// `true` — окно «Пришёл ответ» закрыто оплатой: «Заказ - Оплата прошла» открывает вызывающий, чтобы `await` дожидался и его.
Route<bool> answerPopupRoute(String name, String bookingId) => PageRouteBuilder<bool>(
      settings: RouteSettings(name: name, arguments: bookingId),
      opaque: false,
      barrierColor: AppColors.overlayScrim,
      pageBuilder: (context, _, _) => name == AppRoutes.bookingAccepted
          ? AcceptedPopup(bookingId: bookingId)
          : const DeclinedPopup(),
    );

/// «Пришёл ответ» «Водитель принял заявку»: «Перейти к оплате» оплачивает бронь сразу и открывает
/// «Заказ - Оплата прошла». «Отказаться от заявки» — окно отмены «Пришёл ответ» (`runBookingCancel`); после отмены окно закрывается
/// без значения: `true` значит «оплачено» и открывает «Заказ - Оплата прошла».
class AcceptedPopup extends StatefulWidget {
  const AcceptedPopup({super.key, required this.bookingId});

  final String bookingId;

  @override
  State<AcceptedPopup> createState() => _AcceptedPopupState();
}

class _AcceptedPopupState extends State<AcceptedPopup> {
  bool _paying = false;
  bool _declining = false;

  Future<void> _pay() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = BookingRepository(AppSession.of(context).api);
    setState(() => _paying = true);
    try {
      await repo.pay(widget.bookingId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      messenger.showSnackBar(SnackBar(content: Text(bookingErrorText(l10n, apiErrorCode(e)))));
      return;
    }
    notifyBookingsChanged();
    navigator.pop(true);
  }

  Future<void> _decline() async {
    final navigator = Navigator.of(context);
    setState(() => _declining = true);
    final cancelled =
        await runBookingCancel(context, widget.bookingId, BookingStatus.awaitingPayment, fromAnswer: true);
    if (!mounted) return;
    if (cancelled) {
      navigator.pop();
    } else {
      setState(() => _declining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: PopupCard(
          title: l10n.answersAcceptedTitle,
          body: l10n.answersAcceptedBody,
          actions: [
            AppButton(
              key: const Key('accepted_pay'),
              label: l10n.bookingPay,
              size: AppButtonSize.medium,
              loading: _paying,
              onPressed: _declining ? null : _pay,
            ),
            AppButton(
              key: const Key('accepted_decline'),
              label: l10n.cancelDeclineRequest,
              size: AppButtonSize.medium,
              kind: AppButtonKind.outline,
              onPressed: _paying || _declining ? null : _decline,
            ),
          ],
        ),
      ),
    );
  }
}

/// «Пришёл отказ» «Водитель отклонил заявку»: «Ок» закрывает окно.
class DeclinedPopup extends StatelessWidget {
  const DeclinedPopup({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: PopupCard(
          title: l10n.answersDeclinedTitle,
          body: l10n.answersDeclinedBody,
          actions: [
            AppButton(
              key: const Key('declined_ok'),
              label: l10n.answersOk,
              size: AppButtonSize.medium,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
