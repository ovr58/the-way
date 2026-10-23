import 'package:api_client/api_client.dart';

/// Аргумент маршрута `trip_new`, кроме строки `templateId` (шаблон маршрута — как раньше).
///
/// Шов строк Б2 и Б3 плана `passenger-order_2026-10-22.md`: класс заводит шаг Б1.1, маршрут по нему
/// разводит Б2 (`routes.dart`, мастер), Б3 только открывает `AppRoutes.tripNew` с [TripNewArgs.respond].
class TripNewArgs {
  /// Мастер заказа пассажира: «+» нижней панели и «+ Создать заказ» («Мои заказы - Нет заказов») в режиме пассажира.
  const TripNewArgs.passengerOrder() : order = null;

  /// Отклик водителя новой поездкой: мастер поездки, заполненный из [order]; публикация
  /// уходит с `orderId`.
  const TripNewArgs.respond(OrderDetails this.order);

  /// Заказ, на который водитель откликается новой поездкой; `null` — мастер заказа пассажира.
  final OrderDetails? order;

  bool get isPassengerOrder => order == null;
}
