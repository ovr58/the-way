import 'package:api_client/api_client.dart';

/// Данные заказов пассажиров: только вызовы API. Общий слой экранов пассажира (публикация, «Мои
/// заказы», детали, отмена) и водителя (лента заказов, детали, отклик).
class OrderRepository {
  const OrderRepository(this._api);

  final TheWayApi _api;

  /// `POST /orders` — мастер заказа пассажира.
  Future<OrderDetails> create(OrderInput input) => _api.orders.createOrder(body: input);

  /// `GET /orders` — лента заказов водителя: открытые, не свои; фильтр — как у ленты поездок.
  Future<List<OrderCard>> feed({
    int? fromCityId,
    int? toCityId,
    num? lat,
    num? lng,
    bool? near,
    TripKind? kind,
  }) =>
      _api.orders.searchOrders(
        fromCityId: fromCityId,
        toCityId: toCityId,
        lat: lat,
        lng: lng,
        near: near,
        kind: kind,
      );

  /// `GET /orders/mine` — свои заказы любого статуса, новые сверху.
  Future<List<OrderCard>> mine() => _api.orders.myOrders();

  /// `GET /orders/{id}` — водителю ещё и подходящие свои поездки (`matchingTrips`).
  Future<OrderDetails> details(String orderId) => _api.orders.getOrder(id: orderId);

  /// `POST /orders/{id}/cancel` — пассажир отменяет открытый заказ (в счёт 2/30 не идёт).
  Future<OrderDetails> cancel(String orderId) => _api.orders.cancelOrder(id: orderId);

  /// `POST /orders/{id}/respond` — отклик водителя своей поездкой: бронь «Ожидает оплаты».
  Future<Booking> respond(String orderId, String tripId) =>
      _api.orders.respondToOrder(id: orderId, body: OrderResponseInput(tripId: tripId));
}
