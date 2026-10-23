import '../../app/app_routes.dart';
import 'profile_setup_screen.dart';

/// Маршруты раздела «profile_setup».
final Map<String, RouteBuilder> profileSetupRoutes = {
  AppRoutes.profileSetup: (context, args) => const ProfileSetupScreen(),
};
