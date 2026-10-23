import '../../app/app_routes.dart';
import 'details/driver_trip_details_screen.dart';
import 'list/driver_trips_screen.dart';

/// Маршруты раздела «driver_trips» (U4.2): список поездок водителя и детали поездки (`tripId`).
final Map<String, RouteBuilder> driverTripsRoutes = {
  AppRoutes.driverTrips: (context, args) => const DriverTripsScreen(),
  AppRoutes.driverTripsDetails: (context, args) => DriverTripDetailsScreen(tripId: args as String),
};
