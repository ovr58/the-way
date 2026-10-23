import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/app_localizations.dart';
import 'app_routes.dart';
import '../theme/app_theme.dart';
import 'session.dart';

/// Глобальный ключ навигатора: перехватчики и обработчики ошибок открывают экраны без контекста.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Следит за стеком маршрутов (имя верхнего — для `screen` в `POST /client-logs` и для проверки
/// «системный экран уже открыт»). Стек, а не последнее событие: `pushNamedAndRemoveUntil` сначала
/// кладёт новый маршрут, потом убирает старые.
class RouteNameObserver extends NavigatorObserver {
  final List<Route<dynamic>> _stack = [];

  /// Имя верхнего маршрута; `null`, пока ни одного нет.
  String? get current => _stack.isEmpty ? null : _stack.last.settings.name;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _stack.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _stack.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _stack.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) {
      _stack[i] = newRoute;
    } else if (newRoute != null) {
      _stack.add(newRoute);
    }
  }
}

/// Корень приложения.
class TheWayApp extends StatelessWidget {
  const TheWayApp({super.key, required this.session, required this.routeObserver});

  final AppSession session;
  final RouteNameObserver routeObserver;

  /// Первый экран: нет токена и онбординг не пройден — `onboarding`, нет токена — `auth`, иначе `shell`.
  String get initialRoute {
    if (session.isSignedIn) return AppRoutes.shell;
    return session.onboardingDone ? AppRoutes.auth : AppRoutes.onboarding;
  }

  @override
  Widget build(BuildContext context) {
    return AppSessionScope(
      session: session,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [routeObserver],
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        theme: buildTheme(),
        debugShowCheckedModeBanner: false,
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        initialRoute: initialRoute,
        onGenerateRoute: onGenerateAppRoute,
      ),
    );
  }
}
