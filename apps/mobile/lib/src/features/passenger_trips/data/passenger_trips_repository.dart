import 'package:api_client/api_client.dart';

import '../../orders/data/order_repository.dart';

/// Бронь вместе с поездкой целиком: в `Booking.trip` нет авто и остановок, а детали их показывают.
class BookingDetailsData {
  const BookingDetailsData(this.booking, this.trip);

  final Booking booking;
  final TripDetails trip;
}

/// Данные раздела «Мои заказы» пассажира: все брони и заказы, деталь брони, оплата, деталь и
/// отмена заказа.
class PassengerTripsRepository {
  PassengerTripsRepository(this._api);

  final TheWayApi _api;

  /// Все брони пассажира, новые сверху; фильтры раскладывает клиент.
  Future<List<Booking>> mine() => _api.bookings.myBookings();

  /// Заказы пассажира любого статуса, новые сверху (`GET /orders/mine`).
  Future<List<OrderCard>> orders() => OrderRepository(_api).mine();

  Future<OrderDetails> order(String orderId) => OrderRepository(_api).details(orderId);

  Future<OrderDetails> cancelOrder(String orderId) => OrderRepository(_api).cancel(orderId);

  Future<BookingDetailsData> details(String bookingId) async {
    final booking = await _api.bookings.getBooking(id: bookingId);
    final trip = await _api.trips.getTrip(id: booking.trip.id);
    return BookingDetailsData(booking, trip);
  }

  Future<Booking> pay(String bookingId) => _api.bookings.payBooking(id: bookingId);
}
