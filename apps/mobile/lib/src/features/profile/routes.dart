import '../../app/app_routes.dart';
import 'profile_screen.dart';
import 'switch_mode_screen.dart';

/// Маршруты раздела «profile»: вкладка «Профиль» и выбор роли.
final Map<String, RouteBuilder> profileRoutes = {
  AppRoutes.profile: (context, args) => const ProfileScreen(),
  AppRoutes.profileSwitchMode: (context, args) => const SwitchModeScreen(),
};
