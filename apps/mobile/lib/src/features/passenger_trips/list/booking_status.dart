import 'package:api_client/api_client.dart';

import '../../../../l10n/app_localizations.dart';

/// Фильтры списка «Мои заказы - Нет заказов»/«Мои заказы - Есть заказы»; «Все» — без фильтра.
enum BookingFilter { all, created, active, completed }

bool _tripOver(Booking b) =>
    b.trip.effectiveStatus == TripStatus.completed || b.trip.effectiveStatus == TripStatus.cancelled;

/// В какую вкладку попадает бронь: «Созданные» — `requested`; «Активные» — `awaiting_payment`
/// и `paid` при действующей поездке; «Завершенные» — отклонённые, отменённые и завершённые.
BookingFilter filterOf(Booking b) {
  if (b.status == BookingStatus.rejected || b.status == BookingStatus.cancelled || _tripOver(b)) {
    return BookingFilter.completed;
  }
  return b.status == BookingStatus.requested ? BookingFilter.created : BookingFilter.active;
}

/// Отклонённое предложение: бронь из заказа отменена до оплаты (отказ пассажира от отклика или отмена
/// поездки водителем) — заказ снова открыт и показан своей карточкой, бронь в списке не нужна. Отменённая
/// оплаченная бронь заказа показывается как обычно.
bool isDeclinedOffer(Booking b) => b.orderId != null && b.status == BookingStatus.cancelled && b.paidAt == null;

bool matches(BookingFilter filter, Booking b) =>
    !isDeclinedOffer(b) && (filter == BookingFilter.all || filterOf(b) == filter);

/// Подпись статуса из таблицы «Подписи статусов». `null` — подписи нет (блок «Найден водитель»
/// на карточке показывается вместо плашки).
String? statusLabel(AppLocalizations l10n, Booking b) {
  switch (b.status) {
    case BookingStatus.rejected:
      return l10n.passengerTripsStatusRejected;
    case BookingStatus.cancelled:
      return l10n.passengerTripsStatusCancelled;
    default:
      break;
  }
  if (b.trip.effectiveStatus == TripStatus.cancelled) return l10n.passengerTripsStatusCancelled;
  if (b.trip.effectiveStatus == TripStatus.completed) return l10n.passengerTripsStatusCompleted;
  return switch (b.status) {
    BookingStatus.requested => l10n.passengerTripsStatusRequested,
    BookingStatus.paid => b.parcelOnly ? l10n.passengerTripsStatusParcelPaid : l10n.passengerTripsStatusPaid,
    _ => null,
  };
}

/// Блок «Найден водитель» вместо плашки: бронь ждёт оплаты и поездка действует.
bool showsDriverFound(Booking b) => b.status == BookingStatus.awaitingPayment && !_tripOver(b);

/// В какую вкладку попадает заказ пассажира: открытый — «Созданные», отменённый и истёкший —
/// «Завершенные»; взятый (`matched`) в списке не показывается — его показывает своя бронь.
BookingFilter? orderFilterOf(OrderCard o) => switch (o.status) {
      OrderStatus.open => BookingFilter.created,
      OrderStatus.cancelled || OrderStatus.expired => BookingFilter.completed,
      _ => null,
    };

bool orderMatches(BookingFilter filter, OrderCard o) {
  final f = orderFilterOf(o);
  return f != null && (filter == BookingFilter.all || f == filter);
}

/// Плашка статуса заказа: «Ищем водителя» (открыт), «Отменён», «Водитель не найден» (истёк).
String orderStatusLabel(AppLocalizations l10n, OrderStatus status) => switch (status) {
      OrderStatus.cancelled => l10n.passengerTripsStatusCancelled,
      OrderStatus.expired => l10n.orderStatusExpired,
      _ => l10n.orderStatusOpen,
    };
