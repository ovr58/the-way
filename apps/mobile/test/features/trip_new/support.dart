import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/l10n/app_localizations.dart';
import 'package:the_way/src/features/trip_new/data/trip_new_repository.dart';
import 'package:the_way/src/theme/app_theme.dart';
import 'package:the_way/src/widgets/app_input.dart';

/// Ответ мока: тело JSON и код.
class FakeReply {
  const FakeReply(this.body, [this.status = 200]);
  final Object? body;
  final int status;
}

/// Мок `Dio`: ответы по `METHOD /path`, запросы копятся в [calls].
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.routes);

  final Map<String, FakeReply Function(RequestOptions options)> routes;
  final List<RequestOptions> calls = [];

  Iterable<RequestOptions> callsTo(String key) =>
      calls.where((o) => '${o.method} ${o.path}' == key);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    final handler = routes['${options.method} ${options.path}'];
    final reply = handler == null
        ? const FakeReply({'code': 'not_found', 'message': 'нет'}, 404)
        : handler(options);
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

TripNewRepository repositoryOf(FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
  return TripNewRepository(TheWayApi(dio));
}

Widget app(Widget home) => MaterialApp(
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
      // Именованные переходы мастера (оболочка, детали поездки) в тестах — плашка с именем.
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(body: Text('route:${settings.name}')),
      ),
    );

Map<String, Object?> suggestion(String label, {String place = 'Ярославль'}) => {
      'label': label,
      'shortLabel': label,
      'lat': 57.62,
      'lng': 39.89,
      'place': {'name': place, 'region': 'Ярославская область'},
    };

Map<String, Object?> cityJson(int id, String name, [String region = 'Ярославская область']) =>
    {'id': id, 'name': name, 'region': region, 'lat': 57.62, 'lng': 39.89};

Map<String, Object?> carJson({String id = 'car1', int seats = 4, String status = 'verified'}) => {
      'id': id,
      'brand': 'Toyota',
      'model': 'Camry',
      'kind': 'car',
      'seats': seats,
      'plate': '7841HX-7',
      'status': status,
      'documents': <Object?>[],
    };

Map<String, Object?> _stopJson(int idx, int cityId, String name, String address) =>
    {'idx': idx, 'cityId': cityId, 'cityName': name, 'address': address, 'shortAddress': address};

/// Поездка водителя из трёх остановок: Ярославль — Рыбинск — Углич, выезд 04.06.2026 08:00 МСК.
Map<String, Object?> tripJson({
  String id = 'trip1',
  int seatsTotal = 3,
  String? reverseOf,
  bool editLocked = false,
  String middleAddress = 'Центр',
  String departsAt = '2026-06-04T05:00:00.000Z',
}) {
  final from = _stopJson(0, 1, 'Ярославль', 'Победы 1');
  final to = _stopJson(2, 3, 'Углич', 'Рынок');
  return {
    'id': id,
    'number': 7,
    'kind': 'ride',
    'from': from,
    'to': to,
    'stopsCount': 1,
    'departsAt': departsAt,
    'arrivesAt': '2026-06-04T07:00:00.000Z',
    'seatsFree': seatsTotal,
    'seatsTotal': seatsTotal,
    'parcelSeatsFree': 0,
    'parcelSeatsTotal': 0,
    'price': 1200,
    'driver': {
      'id': 'u1',
      'rating': {'value': 5, 'count': 0},
      'tripsCount': 0,
    },
    'extras': <Object?>[],
    'parcelAllowed': false,
    'parcelSizes': <Object?>[],
    'duplicates': 1,
    'registrationOpen': false,
    'bookable': false,
    'parcelBookable': false,
    'effectiveStatus': 'active',
    'stops': [from, _stopJson(1, 2, 'Рыбинск', middleAddress), to],
    'prices': [
      {'fromIdx': 0, 'toIdx': 1, 'price': 500},
      {'fromIdx': 1, 'toIdx': 2, 'price': 700},
    ],
    'priceBoardingMin': 300,
    'extrasPriced': [
      {'kind': 'pets', 'price': 150},
    ],
    'parcelOnlyAllowed': false,
    'bookingMode': 'standard',
    'car': carJson(),
    'isMine': true,
    'editLocked': editLocked,
    'reverseOf': ?reverseOf,
  };
}

/// Высокий экран: форма мастера длиннее тестового окна 800×600, а `tap` вне окна не попадает.
void tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Нажатие на поле-выбор по его подписи: подпись над значением — отдельный текст, не касание.
Future<void> tapField(WidgetTester tester, String label, {int index = 0}) =>
    tester.tap(find.byWidgetPredicate((w) => w is AppInput && w.label == label).at(index));
