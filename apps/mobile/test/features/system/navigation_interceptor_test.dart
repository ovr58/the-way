import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/app.dart';
import 'package:the_way/src/app/app_routes.dart';
import 'package:the_way/src/app/http.dart';
import 'package:the_way/src/app/session.dart';

/// Отвечает по сценарию: статус, статус с телом или сбой соединения; запросы записываются.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.script);

  final List<Object> script; // int | {status, body} | DioExceptionType
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    final step = script.removeAt(0);
    if (step is DioExceptionType) {
      throw DioException(requestOptions: options, type: step);
    }
    final status = step is int ? step : (step as Map)['status'] as int;
    final body = step is Map ? jsonEncode(step['body']) : '{}';
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late List<String> pushed;
  late Object? lastArgs;
  late RouteNameObserver observer;
  late AppSession session;
  late _Adapter adapter;

  Future<Dio> start(WidgetTester tester, List<Object> script) async {
    pushed = [];
    lastArgs = null;
    observer = RouteNameObserver();
    session = AppSession(const FlutterSecureStorage(), token: 'tok');
    adapter = _Adapter(script);
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [observer],
      initialRoute: AppRoutes.shell,
      onGenerateRoute: (s) {
        pushed.add(s.name!);
        lastArgs = s.arguments;
        return MaterialPageRoute<void>(settings: s, builder: (_) => Text('route:${s.name}'));
      },
    ));
    pushed.clear();
    return createDio(
      session: session,
      adapter: adapter,
      baseUrl: 'http://test',
      navigation: NavigationHooks(navigatorKey: navigatorKey, currentRoute: () => observer.current),
    );
  }

  Future<void> call(WidgetTester tester, Dio dio, String method, String path) async {
    // Dio декодирует тело в изоляте — нужен настоящий, а не поддельный асинхронный мир теста.
    await tester.runAsync(() async {
      try {
        await dio.request<dynamic>(path, options: Options(method: method));
      } on DioException {
        // перехватчик передаёт ошибку вызывающему
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('401 вне /auth: токен снят без запроса выхода, переход на auth', (tester) async {
    final dio = await start(tester, [401]);
    await call(tester, dio, 'GET', '/trips');
    expect(session.token, isNull);
    expect(pushed, [AppRoutes.auth]);
    expect(adapter.requests, ['GET /trips']);
  });

  testWidgets('401 на /auth/verify: перехватчик не трогает', (tester) async {
    final dio = await start(tester, [401]);
    await call(tester, dio, 'POST', '/auth/verify');
    expect(session.token, 'tok');
    expect(pushed, isEmpty);
  });

  testWidgets('403 account_blocked: system/blocked один раз', (tester) async {
    final blocked = {
      'status': 403,
      'body': {'code': 'account_blocked', 'message': 'x'},
    };
    final dio = await start(tester, [blocked, blocked]);
    await call(tester, dio, 'GET', '/trips');
    await call(tester, dio, 'GET', '/me');
    expect(pushed, [AppRoutes.systemBlocked]);
  });

  testWidgets('403 forbidden: перехватчик не трогает', (tester) async {
    final dio = await start(tester, [
      {
        'status': 403,
        'body': {'code': 'forbidden', 'message': 'x'},
      },
    ]);
    await call(tester, dio, 'POST', '/bookings/1/confirm');
    expect(pushed, isEmpty);
  });

  testWidgets('нет сети: на GET ничего, на POST — system/offline', (tester) async {
    final dio = await start(tester, [DioExceptionType.connectionError, DioExceptionType.connectionError]);
    await call(tester, dio, 'GET', '/trips');
    expect(pushed, isEmpty);
    await call(tester, dio, 'POST', '/trips');
    expect(pushed, [AppRoutes.systemOffline]);
  });

  testWidgets('5xx на PATCH: system/error', (tester) async {
    final dio = await start(tester, [500]);
    await call(tester, dio, 'PATCH', '/me');
    expect(pushed, [AppRoutes.systemError]);
  });

  testWidgets('системный экран уже открыт: второй не открывается', (tester) async {
    final dio = await start(tester, [DioExceptionType.connectionError, 500]);
    await call(tester, dio, 'POST', '/trips');
    await call(tester, dio, 'POST', '/trips');
    expect(pushed, [AppRoutes.systemOffline]);
  });

  testWidgets('повтор из аргумента маршрута шлёт тот же запрос', (tester) async {
    final dio = await start(tester, [DioExceptionType.connectionTimeout, 200]);
    await call(tester, dio, 'POST', '/trips');
    await tester.runAsync(() => (lastArgs! as Future<void> Function())());
    expect(adapter.requests, ['POST /trips', 'POST /trips']);
  });
}
