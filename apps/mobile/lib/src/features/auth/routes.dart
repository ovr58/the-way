import '../../app/app_routes.dart';
import 'auth_screen.dart';

/// Маршруты раздела «auth»: вход по номеру («Вход - Базовый экран»); ввод кода и условия открываются поверх него.
final Map<String, RouteBuilder> authRoutes = {
  AppRoutes.auth: (context, args) => const AuthScreen(),
};
