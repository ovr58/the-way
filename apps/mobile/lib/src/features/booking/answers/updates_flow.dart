import 'package:api_client/api_client.dart';
import 'package:flutter/widgets.dart';

import '../../../app/app_routes.dart';
import '../../../app/session.dart';
import '../data/booking_changes.dart';
import '../data/booking_repository.dart';
import 'answer_popups.dart';

/// Идущая проверка: таймер оболочки, возврат на передний план и ручное обновление зовут её независимо —
/// второй вызов присоединяется к идущему, одно событие не показывается дважды.
Future<void>? _inFlight;

/// Сбрасывает идущую проверку (тест оставляет проверку незавершённой).
@visibleForTesting
void resetUpdatesCheck() => _inFlight = null;

/// Проверка событий (`GET /updates`): её зовёт `checkUpdates` — автообновление оболочки раз в 30 с на
/// переднем плане, возврат приложения и ручное обновление списков.
///
/// События показываются по одному: следующее — после закрытия экрана предыдущего (`await`);
/// `POST /updates/{id}/seen` уходит после показа. События водителя приходят в любом режиме.
Future<void> runUpdatesCheck(BuildContext context) {
  final pending = _inFlight;
  if (pending != null) return pending;
  late final Future<void> run;
  run = _check(context).whenComplete(() {
    if (identical(_inFlight, run)) _inFlight = null;
  });
  _inFlight = run;
  return run;
}

Future<void> _check(BuildContext context) async {
  final session = AppSession.of(context);
  if (!session.isSignedIn) return;
  final repo = BookingRepository(session.api);
  final List<Update> updates;
  try {
    updates = await repo.updates();
  } catch (_) {
    return; // Нет сети или токен снят: следующая проверка — по таймеру или при открытии.
  }
  for (final update in updates) {
    if (!context.mounted) return;
    await _show(context, update);
    try {
      await repo.markSeen(update.bookingId);
    } catch (_) {
      // Событие придёт снова при следующей проверке.
    }
  }
  // Были события — видимые списки («Мои заказы», заявки водителя, лента заказов) перечитываются.
  if (updates.isNotEmpty) notifyBookingsChanged();
}

Future<void> _show(BuildContext context, Update update) async {
  final navigator = Navigator.of(context);
  switch (update.kind) {
    case UpdateKind.driverAccepted:
      final paid = await navigator.push(answerPopupRoute(AppRoutes.bookingAccepted, update.bookingId));
      // Окно «Пришёл ответ» закрылось оплатой: «Заказ - Оплата прошла» — следующий экран, следующее событие ждёт и его.
      if (paid == true) await navigator.pushNamed(AppRoutes.bookingPaid, arguments: update.bookingId);
      return;
    case UpdateKind.driverRejected:
      await navigator.push(answerPopupRoute(AppRoutes.bookingDeclined, update.bookingId));
      return;
    case UpdateKind.newRequest:
      await navigator.pushNamed(AppRoutes.driverBookingsNewResponse, arguments: update.bookingId);
      return;
    case UpdateKind.passengerPaid:
      await navigator.pushNamed(AppRoutes.driverBookingsPassengerPaid, arguments: update.bookingId);
      return;
    case UpdateKind.$unknown:
      return;
  }
}
