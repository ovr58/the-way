import 'package:api_client/api_client.dart';

/// Поездка водителя вместе с бронями: детали показывают список пассажиров («Детали поездки - С пассажирами»).
class DriverTripData {
  const DriverTripData(this.trip, this.bookings);

  final TripDetails trip;
  final List<Booking> bookings;
}

/// Данные раздела «Мои заказы» водителя: список поездок, детали с пассажирами и действия меню.
class DriverTripsRepository {
  DriverTripsRepository(this._api);

  final TheWayApi _api;

  /// Поездки водителя: «Активные» — действующие и с закрытым приёмом, «Завершенные» — остальные.
  Future<List<DriverTripCard>> mine(ListStatus status) => _api.trips.myTrips(status: status);

  Future<DriverTripData> details(String tripId) async {
    final trip = await _api.trips.getTrip(id: tripId);
    final bookings = await _api.bookings.tripBookings(id: tripId);
    return DriverTripData(trip, bookings);
  }

  Future<TripDetails> setSeats(String tripId, int seatsTotal) =>
      _api.trips.setTripSeats(id: tripId, body: SeatsInput(seatsTotal: seatsTotal));

  Future<TripDetails> closeIntake(String tripId) => _api.trips.closeTripIntake(id: tripId);

  Future<CancelPreview> cancelPreview(String tripId) => _api.trips.tripCancelPreview(id: tripId);

  Future<CancelResult> cancel(String tripId) => _api.trips.cancelTrip(id: tripId);
}
