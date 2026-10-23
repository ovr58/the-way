import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/session.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/notice_plaque.dart';
import '../../system/temp_blocked_screen.dart';
import '../data/booking_changes.dart';
import '../data/booking_repository.dart';
import 'booking_cancelled_screen.dart';
import 'cancel_popup.dart';

/// Отмена брони пассажиром: предпросмотр → окно по статусу брони и предпросмотру →
/// отмена → итог. Три входа (детали поездки, детали брони, окно «Водитель принял заявку») только
/// вызывают эту функцию. Счёт отмен и блокировку считает сервер (`CancelPreview`), клиент выбирает
/// окно.
///
/// [fromAnswer] — вход из окна «Пришёл ответ»: окно «Пришёл ответ» с текстом кадра. Результат `true` — состояние брони на
/// сервере изменилось (отменена, либо она уже не в том статусе — `invalid_transition`): экран входа
/// перечитывает бронь; `false` — бронь не тронута.
Future<bool> runBookingCancel(
  BuildContext context,
  String bookingId,
  BookingStatus status, {
  bool fromAnswer = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repo = BookingRepository(AppSession.of(context).api);
  void hint(String text) => messenger.showSnackBar(SnackBar(content: Text(text)));

  final CancelPreview preview;
  try {
    preview = await repo.cancelPreview(bookingId);
  } catch (e) {
    hint(_errorText(l10n, e));
    return false;
  }
  if (!context.mounted) return false;

  // В счёт ли отмена, решает сервер (`CancelPreview.counts`): не в счёт — заявка, которую водитель не
  // принял, и отказ от отклика на заказ до оплаты. Старый ответ без `counts` — прежнее правило.
  final requested = status == BookingStatus.requested;
  final free = preview.counts == null ? requested : !preview.counts!;
  final blocks = !free && preview.willBlock;
  final refund = status == BookingStatus.paid ? preview.refundAmount : null;

  final first = await showCancelPopup(
    context,
    _firstWindow(l10n, preview, requested: requested, free: free, blocks: blocks, fromAnswer: fromAnswer, refund: refund),
  );
  if (!first) return false;
  if (blocks) {
    if (!context.mounted) return false;
    final second = await showCancelPopup(
      context,
      CancelPopup(
        title: l10n.cancelSecondTitle,
        body: l10n.cancelSecondBody,
        extras: [NoticePlaque(l10n.cancelSecondNotice)],
        keepLabel: l10n.cancelKeep,
        confirmLabel: l10n.cancelSecondConfirm,
      ),
    );
    if (!second) return false;
  }

  final CancelResult result;
  try {
    result = await repo.cancel(bookingId);
  } catch (e) {
    hint(_errorText(l10n, e));
    final changed = apiErrorCode(e) == 'invalid_transition';
    if (changed) notifyBookingsChanged();
    return changed;
  }

  final blocked = result.blockedUntil != null;
  if (blocked) await navigator.push(TempBlockedScreen.route(TempBlockedRole.passenger));
  final paidBack = result.refund;
  if (paidBack != null) {
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => BookingCancelledScreen(amount: paidBack.amount, days: paidBack.days)),
    );
  } else if (!blocked) {
    hint(l10n.cancelDone);
  }
  notifyBookingsChanged();
  return true;
}

Widget _firstWindow(
  AppLocalizations l10n,
  CancelPreview preview, {
  required bool requested,
  required bool free,
  required bool blocks,
  required bool fromAnswer,
  required int? refund,
}) {
  if (free) {
    // Окно «Отменить заявку?» без счётчика; у брони из заказа — свой текст: водитель уже откликнулся.
    return CancelPopup(
      title: l10n.cancelRequestTitle,
      body: requested ? l10n.cancelRequestBody : l10n.orderDeclineBody,
      image: true,
      keepLabel: l10n.cancelRequestBack,
      confirmLabel: l10n.cancelRequestConfirm,
      confirmKind: AppButtonKind.outline,
    );
  }
  final counter = CancelInfoBlock(count: preview.cancellationsLast30, refundAmount: refund);
  if (blocks) {
    return CancelPopup(
      title: l10n.cancelTitle,
      body: l10n.cancelWarning,
      extras: [counter],
      keepLabel: l10n.cancelKeep,
      confirmLabel: l10n.cancelConfirm,
    );
  }
  if (fromAnswer) {
    return CancelPopup(
      title: l10n.cancelTitle,
      body: l10n.cancelAcceptedBody,
      note: l10n.cancelWarning,
      extras: [counter],
      image: true,
      keepLabel: l10n.cancelRequestBack,
      confirmLabel: l10n.cancelDeclineRequest,
      confirmKind: AppButtonKind.outline,
    );
  }
  return CancelPopup(
    title: l10n.cancelTitle,
    body: l10n.cancelWarning,
    extras: [counter],
    keepLabel: l10n.cancelKeep,
    confirmLabel: refund != null ? l10n.cancelConfirmRefund : l10n.cancelConfirm,
  );
}

String _errorText(AppLocalizations l10n, Object error) {
  final code = apiErrorCode(error);
  return code == 'invalid_transition' ? l10n.cancelErrChanged : bookingErrorText(l10n, code);
}
