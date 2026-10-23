/// Что бронируется: место («Бронирование», «Бронирование - С доп услугами») или посылка («Бронирование», «Бронирование - С доп услугами»).
enum BookingFormMode { seat, parcel }

/// Аргументы маршрута `booking/new`: поездка, режим и, при желании, заранее выбранные точки.
class BookingNewArgs {
  const BookingNewArgs({required this.tripId, required this.mode, this.fromIdx, this.toIdx});

  final String tripId;
  final BookingFormMode mode;
  final int? fromIdx;
  final int? toIdx;
}

/// Чем закончилась форма брони, когда она закрылась на детали поездки (`Navigator.pop`).
class BookingOutcome {
  /// Заявка отправлена (снэкбар «Заявка отправлена»).
  const BookingOutcome.requested()
      : payFailed = false,
        payErrorCode = null;

  /// Бронь создана, но оплата не прошла: бронь остаётся «Ожидает оплаты»; [payErrorCode] —
  /// код ошибки сервера (`null`, если определить не удалось).
  const BookingOutcome.payFailed(this.payErrorCode) : payFailed = true;

  final bool payFailed;
  final String? payErrorCode;
}
