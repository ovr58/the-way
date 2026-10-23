import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/l10n/app_localizations.dart';
import 'package:the_way/src/app/app.dart';
import 'package:the_way/src/app/http.dart';
import 'package:the_way/src/app/session.dart';
import 'package:the_way/src/theme/app_theme.dart';

/// На любой запрос отвечает 403 с кодом [code]; запросы записываются.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.code);

  final String code;
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add('${options.method} ${options.path}');
    return ResponseBody.fromString(jsonEncode({'code': code, 'message': 'x'}), 403, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;

  Future<void> start(WidgetTester tester, {String code = 'blocked'}) async {
    final observer = RouteNameObserver();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [observer],
      theme: buildTheme(),
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: Text('home')),
    ));
    dio = createDio(
      session: AppSession(const FlutterSecureStorage(), token: 'tok'),
      adapter: _Adapter(code),
      baseUrl: 'http://test',
      navigation: NavigationHooks(navigatorKey: navigatorKey, currentRoute: () => observer.current),
    );
  }

  Future<void> post(WidgetTester tester, String path) async {
    // Dio декодирует тело в изоляте — нужен настоящий, а не поддельный асинхронный мир теста.
    await tester.runAsync(() async {
      try {
        await dio.post<dynamic>(path);
      } on DioException {
        // перехватчик передаёт ошибку вызывающему
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('403 blocked на бронь: экран «Аккаунт временно заблокирован» с «Бронирование новых поездок…»',
      (tester) async {
    await start(tester);
    await post(tester, '/trips/1/bookings');

    expect(find.text('Аккаунт временно заблокирован'), findsOneWidget);
    expect(find.textContaining('Бронирование новых поездок'), findsOneWidget);
  });

  testWidgets('403 blocked на публикацию и на обратную поездку: «Публикация новых поездок…»', (tester) async {
    for (final path in ['/trips', '/trips/1/reverse']) {
      await start(tester);
      await post(tester, path);

      expect(find.text('Аккаунт временно заблокирован'), findsOneWidget, reason: path);
      expect(find.textContaining('Публикация новых поездок'), findsOneWidget, reason: path);
      await tester.pumpWidget(const SizedBox());
    }
  });

  // Заказ пассажира и отклик водителя — того же рода, что бронь и
  // публикация поездки.
  testWidgets('403 blocked на заказ пассажира: «Бронирование новых поездок…»', (tester) async {
    await start(tester);
    await post(tester, '/orders');

    expect(find.text('Аккаунт временно заблокирован'), findsOneWidget);
    expect(find.textContaining('Бронирование новых поездок'), findsOneWidget);
  });

  testWidgets('403 blocked на отклик водителя: «Публикация новых поездок…»', (tester) async {
    await start(tester);
    await post(tester, '/orders/o1/respond');

    expect(find.text('Аккаунт временно заблокирован'), findsOneWidget);
    expect(find.textContaining('Публикация новых поездок'), findsOneWidget);
  });

  testWidgets('второй 403 подряд: экран один', (tester) async {
    await start(tester);
    await post(tester, '/trips/1/bookings');
    await post(tester, '/trips/1/bookings');

    expect(find.text('Аккаунт временно заблокирован'), findsOneWidget);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('403 blocked на другой путь: экран не открывается', (tester) async {
    await start(tester);
    await post(tester, '/bookings/1/pay');

    expect(find.text('Аккаунт временно заблокирован'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('другой код на бронь (account_blocked не в счёт): экран «Бронь отменена» не открывается', (tester) async {
    await start(tester, code: 'no_seats');
    await post(tester, '/trips/1/bookings');

    expect(find.text('Аккаунт временно заблокирован'), findsNothing);
  });
}
