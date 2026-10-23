import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';

/// Репозиторий раздела «driver_bookings»: единственное место, где его экраны ходят в API.
class DriverBookingsRepository {
  const DriverBookingsRepository(this._api);

  final TheWayApi _api;

  /// `GET /trips/{id}`: остановки, цены, авто, `paidTotal`.
  Future<TripDetails> trip(String id) => _api.trips.getTrip(id: id);

  /// `GET /trips/{id}/bookings`: заявки поездки без `rejected` и `cancelled`.
  Future<List<Booking>> tripBookings(String tripId) => _api.bookings.tripBookings(id: tripId);

  /// `GET /bookings/{id}`.
  Future<Booking> booking(String id) => _api.bookings.getBooking(id: id);

  /// `POST /bookings/{id}/confirm`.
  Future<Booking> confirm(String id) => _api.bookings.confirmBooking(id: id);

  /// `POST /bookings/{id}/reject`.
  Future<Booking> reject(String id) => _api.bookings.rejectBooking(id: id);

  /// `GET /trips/{id}/cancel-preview`: сколько отмен за 30 дней уже в счёте.
  Future<CancelPreview> cancelPreview(String tripId) => _api.trips.tripCancelPreview(id: tripId);

  /// `POST /trips/{id}/cancel`.
  Future<CancelResult> cancelTrip(String tripId) => _api.trips.cancelTrip(id: tripId);

  /// `GET /users/{id}/public`: телефон приходит только после принятия заявки.
  Future<UserBrief> user(String id) => _api.users.getPublicUser(id: id);
}

/// Код ошибки из ответа сервера `{code, message}`; `null` — ошибка не из ответа сервера.
String? apiErrorCode(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['code'] is String) return data['code'] as String;
  }
  return null;
}

/// Аргумент маршрута: строка — сам [key], карта — значение по ключу.
String? singleArg(Object? args, String key) {
  if (args is String) return args;
  if (args is Map && args[key] is String) return args[key] as String;
  return null;
}
