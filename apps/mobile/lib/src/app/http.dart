import 'dart:math';

import 'package:api_client/api_client.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../features/system/temp_blocked_screen.dart';
import 'api_config.dart';
import 'app_routes.dart';
import 'session.dart';

/// HTTP-клиент приложения. Экраны ходят только через `TheWayApi` поверх этого [Dio]; голого
/// `http` и своего [Dio] у экранов нет.
///
/// Перехватчики: токен в каждый запрос, `traceparent`, сообщение серверу об ошибках сети
/// и 5xx ([ErrorReportInterceptor]).
Dio createDio({
  required AppSession session,
  ClientLogReporter? reporter,
  NavigationHooks? navigation,
  HttpClientAdapter? adapter,
  String baseUrl = apiUrl,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  dio.interceptors.add(_TokenInterceptor(session));
  dio.interceptors.add(TraceparentInterceptor());
  if (navigation != null) dio.interceptors.add(NavigationInterceptor(dio, session, navigation));
  if (reporter != null) dio.interceptors.add(ErrorReportInterceptor(reporter));
  return dio;
}

/// Чем перехватчик переходов открывает экраны: навигатор приложения и имя текущего маршрута.
class NavigationHooks {
  const NavigationHooks({required this.navigatorKey, required this.currentRoute});

  final GlobalKey<NavigatorState> navigatorKey;
  final String? Function() currentRoute;
}

/// Правила переходов по ответам сервера:
/// - 401 вне `/auth/*` — токен снимается без запроса к серверу, переход на `auth`;
/// - 403 `account_blocked` — `system/blocked`;
/// - 403 `blocked` на публикацию, обратную поездку, отклик на заказ (экран водителя), бронь или заказ
///   пассажира (экран пассажира) —
///   `system/temp_blocked` поверх текущего, второй раз не открывается;
/// - нет сети или таймаут на действии (POST, PATCH, PUT, DELETE) — `system/offline`, 5xx на
///   действии — `system/error`; аргумент маршрута — повтор того же запроса;
/// - ошибки загрузки (GET) показывает сам экран; открытый системный экран повторно не открывается.
/// Ошибка в любом случае уходит вызывающему.
class NavigationInterceptor extends Interceptor {
  NavigationInterceptor(this._dio, this._session, this._hooks);

  final Dio _dio;
  final AppSession _session;
  final NavigationHooks _hooks;

  static const _actions = {'POST', 'PATCH', 'PUT', 'DELETE'};

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    final navigator = _hooks.navigatorKey.currentState;
    if (navigator != null && !options.path.startsWith('/auth/')) {
      final status = err.response?.statusCode;
      final data = err.response?.data;
      final code = data is Map ? data['code'] : null;
      final current = _hooks.currentRoute();
      final systemOpen = current != null && current.startsWith('system/');
      if (status == 401) {
        if (_session.token != null) {
          _session.logout(remote: false);
          navigator.pushNamedAndRemoveUntil(AppRoutes.auth, (_) => false);
        }
      } else if (status == 403 && code == 'account_blocked') {
        if (current != AppRoutes.systemBlocked) {
          navigator.pushNamedAndRemoveUntil(AppRoutes.systemBlocked, (_) => false);
        }
      } else if (status == 403 && code == 'blocked') {
        final role = _blockedRole(options);
        if (role != null && current != TempBlockedScreen.routeName) {
          navigator.push(TempBlockedScreen.route(role));
        }
      } else if (_actions.contains(options.method) && !systemOpen) {
        Future<void> retry() async {
          await _dio.fetch<dynamic>(options);
        }

        if (_isOffline(err)) {
          navigator.pushNamed(AppRoutes.systemOffline, arguments: retry);
        } else if (status != null && status >= 500) {
          navigator.pushNamed(AppRoutes.systemError, arguments: retry);
        }
      }
    }
    handler.next(err);
  }

  /// Чей текст у экрана блокировки: публикация, обратная поездка и отклик на заказ — водителя, бронь и
  /// заказ пассажира — пассажира; остальные пути экран не
  /// открывают.
  TempBlockedRole? _blockedRole(RequestOptions options) {
    if (options.method != 'POST') return null;
    final path = options.path;
    if (path == '/trips' ||
        RegExp(r'^/trips/[^/]+/reverse$').hasMatch(path) ||
        RegExp(r'^/orders/[^/]+/respond$').hasMatch(path)) {
      return TempBlockedRole.driver;
    }
    if (path == '/orders' || RegExp(r'^/trips/[^/]+/bookings$').hasMatch(path)) return TempBlockedRole.passenger;
    return null;
  }

  bool _isOffline(DioException err) =>
      err.type == DioExceptionType.connectionError ||
      err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.sendTimeout ||
      err.type == DioExceptionType.receiveTimeout;
}

class _TokenInterceptor extends Interceptor {
  _TokenInterceptor(this._session);

  final AppSession _session;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _session.token;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}

final _random = Random.secure();

String _hex(int bytes) =>
    List.generate(bytes, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

/// Новый `traceparent` по W3C: `00-<32 hex>-<16 hex>-01`.
String newTraceparent() => '00-${_hex(16)}-${_hex(8)}-01';

/// `trace_id` из заголовка `traceparent`.
String traceIdOf(String traceparent) => traceparent.split('-')[1];

/// Ставит на каждый запрос новый `traceparent`: сервер связывает строки лога с запросом клиента.
class TraceparentInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['traceparent'] = newTraceparent();
    handler.next(options);
  }
}

/// Шлёт ошибки клиента в `POST /client-logs`. Не ждёт ответа и никогда не бросает.
class ClientLogReporter {
  ClientLogReporter({required Dio dio, required this.screen, Future<String> Function()? appVersion, Future<String> Function()? device})
      : _api = TheWayApi(dio),
        _appVersion = appVersion ?? _readAppVersion,
        _device = device ?? _readDevice;

  /// Имя текущего маршрута.
  final String? Function() screen;

  final TheWayApi _api;
  final Future<String> Function() _appVersion;
  final Future<String> Function() _device;

  static Future<String> _readAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  static Future<String> _readDevice() async {
    final info = await DeviceInfoPlugin().androidInfo;
    return '${info.model}, Android ${info.version.release}';
  }

  /// Отправляет сообщение [message]; [traceId] — запроса, с которым связана ошибка.
  void report(String message, {String? traceId, ClientLogLevel level = ClientLogLevel.error}) {
    _send(message, traceId, level);
  }

  Future<void> _send(String message, String? traceId, ClientLogLevel level) async {
    try {
      await _api.logs.writeClientLog(
        body: ClientLogBody(
          level: level,
          message: message.length > 1000 ? message.substring(0, 1000) : message,
          screen: screen(),
          traceId: traceId,
          appVersion: await _appVersion(),
          device: await _device(),
        ),
      );
    } catch (_) {
      // Журнал не должен ломать приложение.
    }
  }
}

/// Сообщает серверу об 5xx, таймаутах и сбоях сети (кроме самого `/client-logs`).
class ErrorReportInterceptor extends Interceptor {
  ErrorReportInterceptor(this._reporter);

  final ClientLogReporter _reporter;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    if (options.path != '/client-logs' && _isReportable(err)) {
      final trace = options.headers['traceparent'];
      _reporter.report(
        '${options.method} ${options.path}: ${err.response?.statusCode ?? err.type.name}',
        traceId: trace is String ? traceIdOf(trace) : null,
      );
    }
    handler.next(err);
  }

  bool _isReportable(DioException err) {
    final code = err.response?.statusCode;
    if (code != null) return code >= 500;
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;
  }
}
