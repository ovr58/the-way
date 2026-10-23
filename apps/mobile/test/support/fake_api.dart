import 'dart:convert';
import 'dart:typed_data';

import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:the_way/l10n/app_localizations.dart';
import 'package:the_way/src/app/session.dart';
import 'package:the_way/src/theme/app_theme.dart';

/// Ответ поддельного сервера: статус и тело (карта или список JSON).
class FakeReply {
  const FakeReply(this.status, [this.body = const <String, Object?>{}]);

  final int status;
  final Object? body;
}

/// Поддельный сервер на месте сети: обработчики по ключу «МЕТОД путь», все запросы записываются.
class FakeServer implements HttpClientAdapter {
  final handlers = <String, FakeReply Function(RequestOptions)>{};
  final requests = <RequestOptions>[];

  void on(String key, FakeReply Function(RequestOptions) handler) => handlers[key] = handler;

  /// Запросы с ключом [key] («POST /trips/t1/bookings»).
  List<RequestOptions> of(String key) =>
      requests.where((r) => '${r.method} ${r.path}' == key).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = handlers['${options.method} ${options.path}'];
    final reply = handler == null
        ? const FakeReply(404, {'code': 'not_found', 'message': 'нет'})
        : handler(options);
    return ResponseBody.fromString(jsonEncode(reply.body), reply.status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// Сессия с API поверх [server]; Dio без изолятов, чтобы ответы приходили в мире теста.
AppSession fakeSession(FakeServer server, {String? token = 'tok', bool geoPromptShown = true}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = server
    ..transformer = SyncTransformer();
  return AppSession(const FlutterSecureStorage(), token: token, geoPromptShown: geoPromptShown)
    ..api = TheWayApi(dio);
}

/// Приложение для проверки экрана: тема, ru-локаль, сессия, маршруты-заглушки.
/// Кнопка с ключом `open` открывает [screen] поверх стартового экрана (экран можно закрыть с
/// результатом); остальные именованные маршруты показывают `route:<имя>`, их аргументы
/// записываются в [opened].
Widget testApp(AppSession session, Widget screen, {Map<String, List<Object?>>? opened}) {
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
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const Key('open'),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<Object?>(builder: (_) => screen)),
                  child: const Text('open'),
                ),
              ),
            ),
          );
        }
        opened?.putIfAbsent(settings.name!, () => []).add(settings.arguments);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Text('route:${settings.name}'),
        );
      },
    ),
  );
}

// ---- JSON-фикстуры ответов --------------------------------------------------------------

Map<String, Object?> stopJson(int idx, String address) =>
    {'idx': idx, 'cityId': idx + 1, 'cityName': 'Город $idx', 'address': address, 'shortAddress': address};

Map<String, Object?> driverJson() => {
      'id': 'd1',
      'name': 'Виктор О.',
      'rating': {'value': 4.5, 'count': 2},
      'tripsCount': 127,
    };

/// Карточка поездки (общая часть `TripCard` и `TripDetails`).
Map<String, Object?> tripCardJson({
  String id = 't1',
  int seatsFree = 3,
  int seatsTotal = 3,
  bool bookable = true,
  bool parcelBookable = false,
  bool registrationOpen = false,
  int duplicates = 1,
  int stops = 4,
}) =>
    {
      'id': id,
      'number': 7,
      'kind': 'ride',
      'from': stopJson(0, 'А-0'),
      'to': stopJson(stops - 1, 'Я-${stops - 1}'),
      'stopsCount': stops - 2,
      'departsAt': '2026-10-22T06:00:00.000Z',
      'arrivesAt': '2026-10-22T15:00:00.000Z',
      'seatsFree': seatsFree,
      'seatsTotal': seatsTotal,
      'parcelSeatsFree': 2,
      'parcelSeatsTotal': 3,
      'price': 1200,
      'driver': driverJson(),
      'extras': ['luggage'],
      'parcelAllowed': parcelBookable,
      'parcelSizes': parcelBookable ? ['S', 'M'] : [],
      'duplicates': duplicates,
      'registrationOpen': registrationOpen,
      'bookable': bookable,
      'parcelBookable': parcelBookable,
      'effectiveStatus': 'active',
    };

/// Детали поездки с [stops] остановками: у каждой промежуточной две цены (Правила поездки и цены).
Map<String, Object?> tripDetailsJson({
  String id = 't1',
  int stops = 4,
  int seatsFree = 3,
  bool bookable = true,
  bool parcelBookable = false,
  bool parcelOnlyAllowed = true,
  String bookingMode = 'standard',
  Map<String, Object?>? myBooking,
  bool isMine = false,
}) {
  // Цены участков соседних точек (`checkPrices` сервера): поровну, в сумме — цена поездки 1200.
  final prices = <Map<String, Object?>>[
    if (stops > 2)
      for (var k = 0; k < stops - 1; k++) {'fromIdx': k, 'toIdx': k + 1, 'price': 1200 ~/ (stops - 1)},
  ];
  return {
    ...tripCardJson(
      id: id,
      stops: stops,
      seatsFree: seatsFree,
      bookable: bookable,
      parcelBookable: parcelBookable,
    ),
    'stops': [
      stopJson(0, 'А-0'),
      for (var i = 1; i < stops - 1; i++) stopJson(i, 'Б-$i'),
      stopJson(stops - 1, 'Я-${stops - 1}'),
    ],
    'prices': prices,
    'priceBoardingMin': 100,
    'extrasPriced': [
      {'kind': 'luggage', 'price': 150},
      {'kind': 'pets', 'price': 100},
      {'kind': 'parcel_s', 'price': 150},
      {'kind': 'parcel_m', 'price': 250},
    ],
    'parcelOnlyAllowed': parcelOnlyAllowed,
    'bookingMode': bookingMode,
    'car': {
      'id': 'c1',
      'brand': 'Toyota',
      'model': 'Camry',
      'kind': 'car',
      'seats': 4,
      'plate': '7777 АА-7',
      'status': 'verified',
      'documents': [],
    },
    'isMine': isMine,
    'editLocked': false,
    'myBooking': myBooking,
  };
}

Map<String, Object?> bookingJson({
  String id = 'b1',
  String status = 'requested',
  String tripId = 't1',
  int stops = 4,
  bool parcelOnly = false,
}) =>
    {
      'id': id,
      'number': 12,
      'status': status,
      'seats': parcelOnly ? 0 : 1,
      'fromIdx': 0,
      'toIdx': stops - 1,
      'from': stopJson(0, 'А-0'),
      'to': stopJson(stops - 1, 'Я-${stops - 1}'),
      'segmentPrice': 1200,
      'parcelSize': 'none',
      'parcelOnly': parcelOnly,
      'extras': [],
      'priceTotal': 1200,
      'createdAt': '2026-10-21T10:00:00.000Z',
      'trip': tripCardJson(id: tripId, stops: stops),
      'passenger': driverJson(),
    };
