import 'dart:convert';
import 'dart:typed_data';

import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/l10n/app_localizations.dart';
import 'package:the_way/src/app/app_routes.dart';
import 'package:the_way/src/app/session.dart';
import 'package:the_way/src/theme/app_theme.dart';

/// Поддельный сервер: ответ — по ключу `МЕТОД путь`; запросы записываются.
class MockAdapter implements HttpClientAdapter {
  MockAdapter(this.routes);

  /// `'GET /trips/t1'` → тело ответа (`Map`, `List`) или `(options) → тело`; `(status, body)` — свой код.
  final Map<String, Object?> routes;
  final requests = <RequestOptions>[];

  List<String> get log => [for (final r in requests) '${r.method} ${r.path}'];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final key = '${options.method} ${options.path}';
    if (!routes.containsKey(key)) {
      return ResponseBody.fromString(jsonEncode({'code': 'not_found', 'message': key}), 404,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    }
    var body = routes[key];
    if (body is Function) body = body(options);
    var status = 200;
    if (body is (int, Object?)) {
      status = body.$1;
      body = body.$2;
    }
    return ResponseBody.fromString(jsonEncode(body), status,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

/// Сессия с API поверх [adapter] (без перехватчиков навигации).
AppSession makeSession(MockAdapter adapter) {
  final session = AppSession(const FlutterSecureStorage(), token: 'tok');
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
  session.api = TheWayApi(dio);
  return session;
}

/// Приложение-обёртка: тема, русская локаль, сессия, `onGenerateRoute` пишет открытые маршруты.
Widget testApp({
  required AppSession session,
  required Widget home,
  List<(String, Object?)>? pushed,
  Map<String, RouteBuilder>? extraRoutes,
  RouteFactory? onGenerateRoute,
}) {
  return AppSessionScope(
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
      onGenerateRoute: onGenerateRoute ?? (settings) {
        pushed?.add((settings.name!, settings.arguments));
        final builder = extraRoutes?[settings.name];
        return MaterialPageRoute<dynamic>(
          settings: settings,
          builder: (context) => builder != null
              ? builder(context, settings.arguments)
              : Scaffold(body: Text('route:${settings.name}')),
        );
      },
    ),
  );
}

/// Даёт ответам поддельного сервера дойти до экрана: настоящий асинхронный мир + кадры.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// --- Данные ответов -------------------------------------------------------------------------

Map<String, Object?> rating({double value = 4.5, int count = 2}) => {'value': value, 'count': count};

Map<String, Object?> userBrief({
  String id = 'u1',
  String name = 'Виктор О.',
  String? phone,
  int tripsCount = 120,
  double ratingValue = 4.8,
  int ratingCount = 3,
}) =>
    {
      'id': id,
      'name': name,
      'rating': rating(value: ratingValue, count: ratingCount),
      'tripsCount': tripsCount,
      'phone': ?phone,
    };

Map<String, Object?> stop(int idx, String city, String address) =>
    {'idx': idx, 'cityId': idx + 1, 'cityName': city, 'address': address, 'shortAddress': address};

Map<String, Object?> car() => {
      'id': 'c1',
      'brand': 'Toyota',
      'model': 'Camry',
      'kind': 'car',
      'seats': 4,
      'plate': '7841HX-7',
      'status': 'verified',
      'documents': <Object?>[],
    };

final _stops = [
  stop(0, 'Ярославль', 'Улица Солнечная, дом 1'),
  stop(1, 'Ростов', 'Улица Ленина, дом 5'),
  stop(2, 'Москва', 'Улица Лунная, дом 2'),
];

Map<String, Object?> tripCard({String id = 't1', String status = 'active'}) => {
      'id': id,
      'number': 7,
      'kind': 'ride',
      'from': _stops.first,
      'to': _stops.last,
      'stopsCount': 1,
      'departsAt': '2026-10-25T05:00:00.000Z',
      'arrivesAt': '2026-10-25T15:00:00.000Z',
      'seatsFree': 2,
      'seatsTotal': 4,
      'parcelSeatsFree': 1,
      'parcelSeatsTotal': 3,
      'price': 1200,
      'driver': userBrief(id: 'd1', name: 'Водитель Д.'),
      'extras': ['luggage'],
      'parcelAllowed': true,
      'parcelSizes': ['S', 'M'],
      'duplicates': 1,
      'registrationOpen': true,
      'bookable': true,
      'parcelBookable': true,
      'effectiveStatus': status,
    };

/// [editLocked] — серверный признак «в поездке есть принятые пассажиры» (заявки не только `requested`).
Map<String, Object?> tripDetails({int? paidTotal = 600, bool editLocked = true, String status = 'active'}) => {
      ...tripCard(status: status),
      'stops': _stops,
      'prices': [
        {'fromIdx': 0, 'toIdx': 1, 'price': 400},
        {'fromIdx': 1, 'toIdx': 2, 'price': 800},
      ],
      'priceBoardingMin': 100,
      'extrasPriced': <Object?>[],
      'parcelOnlyAllowed': true,
      'bookingMode': 'standard',
      'car': car(),
      'isMine': true,
      'editLocked': editLocked,
      'paidTotal': ?paidTotal,
    };

Map<String, Object?> booking({
  String id = 'b1',
  String status = 'requested',
  String passengerId = 'p1',
  String passengerName = 'Анна П.',
  String? phone,
  int seats = 2,
  String parcelSize = 'none',
  bool parcelOnly = false,
  String? parcelComment,
  int priceTotal = 800,
  num? segmentKm,
}) =>
    {
      'id': id,
      'number': 11,
      'status': status,
      'seats': seats,
      'fromIdx': 0,
      'toIdx': 2,
      'from': _stops.first,
      'to': _stops.last,
      'segmentPrice': 400,
      'parcelSize': parcelSize,
      'parcelOnly': parcelOnly,
      'parcelComment': ?parcelComment,
      'extras': <Object?>[],
      'priceTotal': priceTotal,
      'segmentKm': ?segmentKm,
      'createdAt': '2026-10-21T10:00:00.000Z',
      'trip': tripCard(),
      'passenger': userBrief(id: passengerId, name: passengerName, phone: phone),
    };
