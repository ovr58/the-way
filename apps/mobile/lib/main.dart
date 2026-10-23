import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'src/app/api_config.dart';
import 'src/app/app.dart';
import 'src/app/http.dart';
import 'src/app/session.dart';
import 'src/widgets/app_image.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await AppSession.restore(const FlutterSecureStorage());
  final routeObserver = RouteNameObserver();
  // Отдельный Dio без перехватчиков: сообщение об ошибке не должно порождать новые.
  final reporter = ClientLogReporter(
    dio: Dio(BaseOptions(baseUrl: apiUrl, connectTimeout: const Duration(seconds: 5))),
    screen: () => routeObserver.current,
  );
  session.api = TheWayApi(createDio(
      session: session,
      reporter: reporter,
      navigation: NavigationHooks(navigatorKey: navigatorKey, currentRoute: () => routeObserver.current),
    ));

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reporter.report('${details.exceptionAsString()}\n${details.stack ?? ''}');
  };
  // Неудачи загрузки картинок с API — в журнал клиента.
  AppImage.onLoadError = (message) => reporter.report(message, level: ClientLogLevel.warn);
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.report('$error\n$stack');
    return true;
  };

  runApp(TheWayApp(session: session, routeObserver: routeObserver));
}
