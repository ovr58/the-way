import 'package:flutter/material.dart';

import '../features/auth/routes.dart';
import '../features/booking/routes.dart';
import '../features/cars/routes.dart';
import '../features/city/routes.dart';
import '../features/driver_bookings/routes.dart';
import '../features/driver_trips/routes.dart';
import '../features/onboarding/routes.dart';
import '../features/passenger_trips/routes.dart';
import '../features/profile/routes.dart';
import '../features/profile_setup/routes.dart';
import '../features/search/routes.dart';
import '../features/system/routes.dart';
import '../features/trip_new/routes.dart';
import 'home_shell.dart';

/// Строитель экрана маршрута: [args] — `RouteSettings.arguments`.
typedef RouteBuilder = Widget Function(BuildContext context, Object? args);

/// Имена всех маршрутов клиента.
abstract final class AppRoutes {
  static const onboarding = 'onboarding';
  static const citySelect = 'city_select';
  static const auth = 'auth';
  static const profileSetup = 'profile_setup';
  static const shell = 'shell';
  static const profile = 'profile';
  static const profileSwitchMode = 'profile/switch_mode';
  static const search = 'search';
  static const searchFilter = 'search/filter';
  static const searchDetails = 'search/details';
  /// Профиль водителя; аргумент — id водителя.
  static const searchDriver = 'search/driver';
  static const bookingNew = 'booking/new';
  static const bookingAccepted = 'booking/accepted';
  static const bookingDeclined = 'booking/declined';
  static const bookingPaid = 'booking/paid';
  static const passengerTrips = 'passenger_trips';
  static const passengerTripsDetails = 'passenger_trips/details';
  static const passengerTripsOrder = 'passenger_trips/order';
  static const driverTrips = 'driver_trips';
  static const driverTripsDetails = 'driver_trips/details';
  static const tripNew = 'trip_new';
  static const tripNewReturn = 'trip_new/return';
  static const tripNewEdit = 'trip_new/edit';
  static const driverBookings = 'driver_bookings';
  static const driverBookingsPassenger = 'driver_bookings/passenger';
  static const driverBookingsNewResponse = 'driver_bookings/new_response';
  static const driverBookingsPassengerPaid = 'driver_bookings/passenger_paid';
  static const cars = 'cars';
  static const carsAdd = 'cars/add';
  static const systemOffline = 'system/offline';
  static const systemError = 'system/error';
  static const systemBlocked = 'system/blocked';
  static const stub = 'stub';
}

/// Маршруты-окна («Пришёл отклик», «Пассажир оплатил»): прозрачные, затемнение рисует само окно, экран позади виден сквозь
/// него — как окна ответов «Пришёл ответ», «Пришёл отказ» (`answerPopupRoute`).
const _windowRoutes = {AppRoutes.driverBookingsNewResponse, AppRoutes.driverBookingsPassengerPaid};

/// Все маршруты: оболочка и таблицы разделов (`features/<раздел>/routes.dart`).
final Map<String, RouteBuilder> appRouteTable = {
  AppRoutes.shell: (context, args) => HomeShell(initialTab: args is int ? args : 0),
  ...onboardingRoutes,
  ...cityRoutes,
  ...authRoutes,
  ...profileSetupRoutes,
  ...profileRoutes,
  ...searchRoutes,
  ...bookingRoutes,
  ...passengerTripsRoutes,
  ...driverTripsRoutes,
  ...tripNewRoutes,
  ...driverBookingsRoutes,
  ...carsRoutes,
  ...systemRoutes,
};

/// Экран маршрута [name] для вложения в другой экран (вкладки оболочки).
Widget buildRoute(BuildContext context, String name, [Object? args]) =>
    appRouteTable[name]!(context, args);

/// `onGenerateRoute` приложения.
Route<dynamic>? onGenerateAppRoute(RouteSettings settings) {
  final builder = appRouteTable[settings.name];
  if (builder == null) return null;
  if (_windowRoutes.contains(settings.name)) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      opaque: false,
      pageBuilder: (context, _, _) => builder(context, settings.arguments),
    );
  }
  return MaterialPageRoute<dynamic>(
    settings: settings,
    builder: (context) => builder(context, settings.arguments),
  );
}

/// Заглушка экрана раздела: имя маршрута. Экраны строк U1–U5 заменяют её в `routes.dart` раздела.
class RoutePlaceholder extends StatelessWidget {
  const RoutePlaceholder(this.name, {super.key});

  final String name;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Stack(children: [const Placeholder(), Center(child: Text(name))]));
}
