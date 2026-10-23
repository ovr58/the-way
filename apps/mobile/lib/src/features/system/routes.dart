import '../../app/app_routes.dart';
import 'blocked_screen.dart';
import 'error_screen.dart';
import 'offline_screen.dart';
import 'stub_screen.dart';

Future<void> _noRetry() async {}

/// Маршруты раздела «system». `retry` — `Future<void> Function()` повтора запроса; `stub`
/// принимает `title` (String).
final Map<String, RouteBuilder> systemRoutes = {
  AppRoutes.systemOffline: (context, args) =>
      OfflineScreen(onRetry: args is Future<void> Function() ? args : _noRetry),
  AppRoutes.systemError: (context, args) =>
      ErrorScreen(onRetry: args is Future<void> Function() ? args : _noRetry),
  AppRoutes.systemBlocked: (context, args) => const BlockedScreen(),
  AppRoutes.stub: (context, args) => StubScreen(title: args is String ? args : null),
};
