import '../../app/app_routes.dart';
import 'data/driver_bookings_repository.dart';
import 'events/driver_event_screen.dart';
import 'list/driver_bookings_screen.dart';
import 'passenger/passenger_profile_screen.dart';

/// Маршруты раздела «driver_bookings». Аргумент — строка (`tripId`, `bookingId`) или карта с
/// тем же ключом; `driver_bookings/passenger` — карта `{userId, bookingId}`, достаточно одного.
final Map<String, RouteBuilder> driverBookingsRoutes = {
  AppRoutes.driverBookings: (context, args) => DriverBookingsScreen(tripId: singleArg(args, 'tripId')!),
  AppRoutes.driverBookingsPassenger: (context, args) => PassengerProfileScreen(
        userId: args is Map ? args['userId'] as String? : null,
        bookingId: args is Map ? args['bookingId'] as String? : singleArg(args, 'bookingId'),
      ),
  AppRoutes.driverBookingsNewResponse: (context, args) =>
      DriverEventScreen(bookingId: singleArg(args, 'bookingId')!, event: DriverEvent.newResponse),
  AppRoutes.driverBookingsPassengerPaid: (context, args) =>
      DriverEventScreen(bookingId: singleArg(args, 'bookingId')!, event: DriverEvent.passengerPaid),
};
