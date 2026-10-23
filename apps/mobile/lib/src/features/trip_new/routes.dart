import '../../app/app_routes.dart';
import 'edit_trip_screen.dart';
import 'return_trip_screen.dart';
import 'steps/type_step.dart';
import 'trip_new_args.dart';

/// Маршруты раздела «trip_new»: мастер поездки, обратная поездка, правка.
final Map<String, RouteBuilder> tripNewRoutes = {
  // Аргумент — `templateId` шаблона маршрута (необязательный) или [TripNewArgs]: мастер заказа пассажира,
  // отклик водителя новой поездкой.
  AppRoutes.tripNew: (context, args) => TypeStep(
        templateId: args is String ? args : null,
        args: args is TripNewArgs ? args : null,
      ),
  // Аргумент — `tripId` исходной поездки.
  AppRoutes.tripNewReturn: (context, args) => ReturnTripScreen(tripId: args as String),
  // Аргумент — `tripId` правимой поездки.
  AppRoutes.tripNewEdit: (context, args) => EditTripScreen(tripId: args as String),
};
