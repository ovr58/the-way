import '../../app/app_routes.dart';
import 'city_screen.dart';

/// Маршруты раздела «city».
final Map<String, RouteBuilder> cityRoutes = {
  AppRoutes.citySelect: (context, args) => const CityScreen(),
};
