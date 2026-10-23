import '../../app/app_routes.dart';
import 'add/add_car_screen.dart';
import 'list/cars_screen.dart';

/// Маршруты раздела «cars». `cars/add` закрывается, вернув `carId` созданного авто.
final Map<String, RouteBuilder> carsRoutes = {
  AppRoutes.cars: (context, args) => const CarsScreen(),
  AppRoutes.carsAdd: (context, args) => const AddCarScreen(),
};
