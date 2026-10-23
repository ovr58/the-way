import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/l10n/app_localizations.dart';
import 'package:the_way/src/app/session.dart';
import 'package:the_way/src/theme/app_theme.dart';

/// Ответ мока: код HTTP и тело (JSON).
class FakeReply {
  const FakeReply(this.status, [this.body]);

  final int status;
  final Object? body;
}

/// Запрос, дошедший до мока.
class FakeRequest {
  FakeRequest(this.method, this.path, this.data, this.query);

  final String method;
  final String path;
  final Object? data;
  final Map<String, dynamic> query;
}

/// Мок сети для виджет-тестов: ответы по ключу `МЕТОД /путь`, журнал запросов.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.routes);

  final Map<String, FakeReply Function(FakeRequest request)> routes;
  final List<FakeRequest> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final request = FakeRequest(options.method, options.path, options.data, options.queryParameters);
    requests.add(request);
    final handler = routes['${options.method} ${options.path}'];
    final reply = handler == null ? const FakeReply(404, {'code': 'not_found', 'message': 'нет маршрута'}) : handler(request);
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> meJson({String? name, String mode = 'passenger', Map<String, Object?>? city, int trips = 0, int reviews = 0}) => {
      'id': 'u1',
      'phone': '+375257774420',
      'name': name,
      'mode': mode,
      'city': city,
      'rating': {'value': reviews == 0 ? 5 : 4.8, 'count': reviews},
      'tripsCount': trips,
      'cancellationsLast30': 0,
    };

/// Сессия с моком сети.
AppSession fakeSession(FakeAdapter adapter) {
  FlutterSecureStorage.setMockInitialValues({}); // без платформенного канала запись в хранилище не завершается
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
  return AppSession(const FlutterSecureStorage())..api = TheWayApi(dio);
}

/// Приложение для теста: [home], сессия в дереве; любой другой маршрут — текст `route:<имя>`.
Widget fakeApp(AppSession session, Widget home) => AppSessionScope(
      session: session,
      child: MaterialApp(
        theme: buildTheme(),
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text('route:${settings.name}')),
        ),
      ),
    );

/// Экран 375×812, как в кадрах: переполнение вёрстки роняет тест.
void usePhone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1125, 2436)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Подгружает Gilroy: в тестах без неё любой текст рисуется шрифтом Ahem (буква = квадрат) и ширины
/// не похожи на настоящие.
Future<void> loadGilroy() async {
  final loader = FontLoader('Gilroy');
  for (final weight in ['Regular', 'Medium', 'Semibold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Gilroy-$weight.ttf'));
  }
  await loader.load();
}
