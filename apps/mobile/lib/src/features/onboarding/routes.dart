import '../../app/app_routes.dart';
import 'onboarding_screen.dart';

/// Маршруты раздела «onboarding».
final Map<String, RouteBuilder> onboardingRoutes = {
  AppRoutes.onboarding: (context, args) => const OnboardingScreen(),
};
