import '../../app/app_routes.dart';
import 'details/booking_details_screen.dart';
import 'list/passenger_trips_screen.dart';
import 'order/order_details_screen.dart';

/// Маршруты раздела «passenger_trips» (U4.1): список броней и заказов, деталь брони (`bookingId`), деталь
/// заказа пассажира (`orderId`, Б2.4).
final Map<String, RouteBuilder> passengerTripsRoutes = {
  AppRoutes.passengerTrips: (context, args) => const PassengerTripsScreen(),
  AppRoutes.passengerTripsDetails: (context, args) => BookingDetailsScreen(bookingId: args as String),
  AppRoutes.passengerTripsOrder: (context, args) => OrderDetailsScreen(orderId: args as String),
};
