import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';

import '../../../../l10n/app_localizations.dart';

/// Данные раздела «booking»: итог, создание и оплата брони, события. Только вызовы API.
class BookingRepository {
  const BookingRepository(this._api);

  final TheWayApi _api;

  /// `GET /trips/{id}/quote` — итог считает сервер.
  Future<Quote> quote(
    String tripId, {
    required int fromIdx,
    required int toIdx,
    required int seats,
    ParcelSize parcelSize = ParcelSize.none,
    List<ServiceKind> extras = const [],
  }) =>
      _api.bookings.quoteBooking(
        id: tripId,
        fromIdx: fromIdx,
        toIdx: toIdx,
        seats: seats,
        parcelSize: parcelSize == ParcelSize.none ? null : parcelSize,
        extras: extras.isEmpty ? null : extras.map((e) => e.json).join(','),
      );

  Future<Booking> create(String tripId, BookingInput input) =>
      _api.bookings.createBooking(id: tripId, body: input);

  /// `POST /bookings/{id}/pay` — оплата одним нажатием.
  Future<Booking> pay(String bookingId) => _api.bookings.payBooking(id: bookingId);

  /// `GET /bookings/{id}/cancel-preview` — счёт отмен за 30 дней, блокировку и возврат считает сервер.
  Future<CancelPreview> cancelPreview(String bookingId) => _api.bookings.bookingCancelPreview(id: bookingId);

  /// `POST /bookings/{id}/cancel` — итог отмены: возврат и срок блокировки.
  Future<CancelResult> cancel(String bookingId) => _api.bookings.cancelBooking(id: bookingId);

  Future<List<Update>> updates() => _api.bookings.listUpdates();

  Future<void> markSeen(String bookingId) => _api.bookings.markUpdateSeen(bookingId: bookingId);
}

/// Код ошибки сервера (`{code, message}`) из исключения Dio; `null`, если это не ответ API.
String? apiErrorCode(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['code'] is String) return data['code'] as String;
  }
  return null;
}

/// Текст ошибки брони или оплаты по коду (текст сервера клиент не показывает).
String bookingErrorText(AppLocalizations l10n, String? code) => switch (code) {
      'no_seats' => l10n.bookingErrNoSeats,
      'trip_unavailable' => l10n.bookingErrUnavailable,
      'booking_exists' => l10n.bookingErrExists,
      _ => l10n.bookingErrGeneric,
    };
