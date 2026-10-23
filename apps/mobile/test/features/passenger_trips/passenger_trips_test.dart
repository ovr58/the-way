import 'dart:convert';
import 'dart:typed_data';

import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/l10n/app_localizations.dart';
import 'package:the_way/src/app/app_routes.dart';
import 'package:the_way/src/app/session.dart';
import 'package:the_way/src/features/passenger_trips/data/passenger_trips_repository.dart';
import 'package:the_way/src/features/passenger_trips/details/booking_details_screen.dart';
import 'package:the_way/src/features/passenger_trips/list/booking_card.dart';
import 'package:the_way/src/features/passenger_trips/list/booking_status.dart';
import 'package:the_way/src/features/passenger_trips/list/passenger_trips_screen.dart';
import 'package:the_way/src/theme/app_theme.dart';
import 'package:the_way/src/widgets/app_header.dart';
import 'package:the_way/src/widgets/app_icon.dart';
import 'package:the_way/src/widgets/road_illustration.dart';

import '../../support/gilroy.dart';

/// Отвечает по таблице `метод путь -> тело`; запросы записываются.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.routes);

  final Map<String, Object> routes;
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final key = '${options.method} ${options.path}';
    requests.add(key);
    var body = routes[key];
    var status = 200;
    if (body is MapEntry<int, Object>) {
      status = body.key;
      body = body.value;
    }
    if (body == null) {
      return ResponseBody.fromString('{"code":"not_found","message":"x"}', 404, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
    }
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _user({String? phone, String name = 'Виктор О.'}) => {
      'id': 'd1',
      'name': name,
      'rating': {'value': 4.5, 'count': 3},
      'tripsCount': 127,
      'phone': ?phone,
    };

Map<String, Object?> _stop(int idx, String address) =>
    {'idx': idx, 'cityId': idx + 1, 'cityName': 'Город $idx', 'address': address, 'shortAddress': address};

Map<String, Object?> _tripCard({String status = 'active', String? phone}) => {
      'id': 't1',
      'number': 7,
      'kind': 'ride',
      'from': _stop(0, 'Улица Солнечная, дом 1'),
      'to': _stop(1, 'Улица Лунная, дом 2'),
      'stopsCount': 0,
      'departsAt': '2026-05-16T09:00:00.000Z',
      'arrivesAt': '2026-05-16T12:00:00.000Z',
      'seatsFree': 3,
      'seatsTotal': 4,
      'parcelSeatsFree': 0,
      'parcelSeatsTotal': 0,
      'price': 1200,
      'driver': _user(phone: phone),
      'extras': <String>[],
      'parcelAllowed': false,
      'parcelSizes': <String>[],
      'duplicates': 1,
      'registrationOpen': true,
      'bookable': false,
      'parcelBookable': false,
      'effectiveStatus': status,
    };

Map<String, Object?> _booking({
  String id = 'b1',
  int number = 1231,
  String status = 'paid',
  String tripStatus = 'active',
  int seats = 1,
  bool parcelOnly = false,
  String? phone,
}) =>
    {
      'id': id,
      'number': number,
      'status': status,
      'seats': seats,
      'fromIdx': 0,
      'toIdx': 1,
      'from': _stop(0, 'Улица Солнечная, дом 1'),
      'to': _stop(1, 'Улица Лунная, дом 2'),
      'segmentPrice': 400,
      'parcelSize': parcelOnly ? 'S' : 'none',
      'parcelOnly': parcelOnly,
      'extras': <Object>[],
      'priceTotal': 600,
      'createdAt': '2026-05-10T09:00:00.000Z',
      'trip': _tripCard(status: tripStatus, phone: phone),
      'passenger': _user(name: 'Пассажир'),
    };

Map<String, Object?> _tripDetails({String? phone}) => {
      ..._tripCard(phone: phone),
      'stops': [_stop(0, 'Улица Солнечная, дом 1'), _stop(1, 'Улица Ленина, дом 5'), _stop(2, 'Улица Лунная, дом 2')],
      'prices': <Object>[],
      'priceBoardingMin': 100,
      'extrasPriced': <Object>[],
      'parcelOnlyAllowed': false,
      'bookingMode': 'standard',
      'car': {
        'id': 'c1',
        'brand': 'Toyota',
        'model': 'Camry',
        'kind': 'car',
        'seats': 4,
        'plate': '7777 АА-7',
        'status': 'verified',
        'documents': <Object>[],
      },
      'isMine': false,
      'editLocked': false,
    };

Widget _app(Dio dio, Widget Function(PassengerTripsRepository) screen, {List<String>? pushed}) {
  final session = AppSession(const FlutterSecureStorage(), token: 'tok')..api = TheWayApi(dio);
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
      onGenerateRoute: (s) {
        pushed?.add('${s.name}:${s.arguments}');
        return MaterialPageRoute<void>(settings: s, builder: (_) => Text('route:${s.name}'));
      },
      home: screen(PassengerTripsRepository(session.api)),
    ),
  );
}

Dio _dio(Map<String, Object> routes) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..transformer = SyncTransformer()
    ..httpClientAdapter = _Adapter(routes);
  return dio;
}

Booking _b(String status, {String tripStatus = 'active'}) =>
    Booking.fromJson(_booking(status: status, tripStatus: tripStatus));

/// Ответ Dio идёт через таймеры нулевой длины: прокручиваем часы теста, пока экран не получит данные.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  test('фильтры раскладывают брони по вкладкам', () {
    expect(filterOf(_b('requested')), BookingFilter.created);
    expect(filterOf(_b('awaiting_payment')), BookingFilter.active);
    expect(filterOf(_b('paid')), BookingFilter.active);
    expect(filterOf(_b('paid', tripStatus: 'completed')), BookingFilter.completed);
    expect(filterOf(_b('rejected')), BookingFilter.completed);
    expect(filterOf(_b('cancelled')), BookingFilter.completed);
  });

  testWidgets('список: подписи статусов, блок «Найден водитель» и фильтр «Созданные»', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dio = _dio({
      'GET /orders/mine': <Object>[],
      'GET /bookings/mine': [
        _booking(id: 'b1', number: 1, status: 'paid'),
        _booking(id: 'b2', number: 2, status: 'paid', parcelOnly: true, seats: 0),
        _booking(id: 'b3', number: 3, status: 'awaiting_payment'),
        _booking(id: 'b4', number: 4, status: 'requested'),
        _booking(id: 'b5', number: 5, status: 'paid', tripStatus: 'completed'),
      ],
    });
    await tester.pumpWidget(_app(dio, (repo) => PassengerTripsScreen(repository: repo)));
    await _settle(tester);

    expect(find.text('Заказ №1'), findsOneWidget);
    expect(find.text('Место забронировано'), findsOneWidget);
    expect(find.text('Посылка забронирована'), findsOneWidget);
    expect(find.text('Ожидает подтверждения'), findsOneWidget);
    expect(find.text('Завершен'), findsWidgets); // плашка и фильтр
    expect(find.textContaining('Найден водитель'), findsOneWidget);
    expect(find.text('600 ₽'), findsWidgets);

    await tester.tap(find.text('Созданные'));
    await tester.pump();
    expect(find.text('Заказ №4'), findsOneWidget);
    expect(find.text('Заказ №1'), findsNothing);
  });

  testWidgets('адрес на карточке брони — короткий (PN-2), полный не показывается', (tester) async {
    final json = _booking()..['from'] = {..._stop(0, 'Россия, Ярославская область, Ярославль, Фрунзенский, 150001, Портовая набережная 10'), 'shortAddress': 'Портовая набережная, 10'};
    await tester.pumpWidget(_app(_dio({}), (_) => BookingCard(booking: Booking.fromJson(json))));
    expect(find.text('Город 0, Портовая набережная, 10'), findsOneWidget);
    expect(find.text('Россия, Ярославская область, Ярославль, Фрунзенский, 150001, Портовая набережная 10'), findsNothing);
  });

  // Кнопка «+ Создать заказ» есть, как в кадре «Мои заказы - Нет заказов» (принятое решение 2026-10-22, отменяет прежнее «кнопки
  // нет»); что она делает у пассажира — test/widgets/app_add_button_test.dart.
  testWidgets('пустой список — тексты кадра «Мои заказы - Нет заказов» и кнопка «Создать заказ»', (tester) async {
    await tester.pumpWidget(_app(_dio({'GET /bookings/mine': <Object>[], 'GET /orders/mine': <Object>[]}), (repo) => PassengerTripsScreen(repository: repo)));
    await _settle(tester);
    expect(find.text('У вас пока нет заказов'), findsOneWidget);
    expect(find.text('Создать заказ'), findsOneWidget);
  });

  testWidgets('«Завершенные» пусто — «Завершённых поездок пока нет», без «Создать заказ»', (tester) async {
    await tester.pumpWidget(_app(_dio({'GET /bookings/mine': <Object>[], 'GET /orders/mine': <Object>[]}), (repo) => PassengerTripsScreen(repository: repo)));
    await _settle(tester);
    await tester.tap(find.text('Завершенные'));
    await tester.pumpAndSettle();
    expect(find.text('Завершённых поездок пока нет'), findsOneWidget);
    expect(find.text('У вас пока нет заказов'), findsNothing);
    expect(find.text('Создать заказ'), findsNothing);
  });

  Future<void> openDetails(WidgetTester tester, String? phone, String status) async {
    final dio = _dio({
      'GET /bookings/b1': _booking(status: status, phone: phone),
      'GET /trips/t1': _tripDetails(phone: phone),
    });
    await tester.pumpWidget(_app(dio, (repo) => BookingDetailsScreen(bookingId: 'b1', repository: repo)));
    await _settle(tester);
  }

  testWidgets('детали: телефон водителя при phone ≠ null, у оплаченной брони активной поездки есть «Отменить бронь»', (tester) async {
    await openDetails(tester, '+7 000 000 00 00', 'paid');
    expect(find.text('Номер телефона'), findsOneWidget);
    expect(find.text('+7 000 000 00 00'), findsOneWidget);
    expect(find.text('Отменить бронь'), findsOneWidget);
    expect(find.text('Стоимость поездки'), findsOneWidget);
    expect(find.text('1\u00A0200 ₽'), findsOneWidget);
    expect(find.text('400 ₽'), findsOneWidget);
    expect(find.text('Оплатить'), findsNothing);
  });

  // Номер с сервера приходит в E.164 без пробелов; показ — группами, как в «Личных данных» и профиле пассажира.
  testWidgets('детали: телефон водителя показан группами «+7 900 111 22 33»', (tester) async {
    await openDetails(tester, '+79001112233', 'paid');
    expect(find.text('+7 900 111 22 33'), findsOneWidget);
    expect(find.text('+79001112233'), findsNothing);
  });

  testWidgets('детали: стрелка у водителя открывает профиль водителя', (tester) async {
    final pushed = <String>[];
    final dio = _dio({
      'GET /bookings/b1': _booking(status: 'paid'),
      'GET /trips/t1': _tripDetails(),
    });
    await tester.pumpWidget(_app(dio, (repo) => BookingDetailsScreen(bookingId: 'b1', repository: repo), pushed: pushed));
    await _settle(tester);
    final arrow = find.byWidgetPredicate((w) => w is AppIcon && w.name == 'arrows_alt_arrow_right');
    await tester.ensureVisible(arrow);
    await tester.tap(arrow);
    await tester.pump();
    expect(pushed, ['${AppRoutes.searchDriver}:d1']);
  });

  testWidgets('«Детали поездки - Лимит отмен»: иллюстрация дороги 293×169 вверху карточки маршрута', (tester) async {
    await openDetails(tester, null, 'requested');
    final road = find.byType(RoadIllustration);
    expect(road, findsOneWidget);
    expect(tester.getSize(find.descendant(of: road, matching: find.byType(SvgPicture))), const Size(293, 169));
    expect(tester.getTopLeft(road).dy, greaterThan(tester.getBottomLeft(find.text('Маршрут')).dy - 1));
    expect(tester.getRect(road).bottom, lessThanOrEqualTo(tester.getTopLeft(find.textContaining('Улица Солнечная')).dy));
  });

  testWidgets('«Детали поездки - Лимит отмен»: кнопка «N остановок» по нажатию исчезает, на её месте остановка', (tester) async {
    await openDetails(tester, null, 'requested');
    expect(find.byKey(const Key('route_stops_chip')), findsOneWidget);
    expect(find.text('Город 1, Улица Ленина, дом 5'), findsNothing);
    await tester.tap(find.byKey(const Key('route_stops_chip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('route_stops_chip')), findsNothing);
    expect(find.text('Город 1, Улица Ленина, дом 5'), findsOneWidget);
  });

  testWidgets('«Детали поездки - Бронь есть» – «Детали поездки - Отмена брони»: шапка деталей брони без нижней линии', (tester) async {
    await openDetails(tester, null, 'requested');
    expect(tester.widget<AppHeader>(find.byType(AppHeader)).bordered, isFalse);
  });

  // Принятое решение 2026-10-22: в деталях брони — свободные места поездки, как в ленте и деталях поездки
  // (отход от «Экран поездки после оплаты», «Детали поездки - Бронь есть» – «Детали поездки - Скролл», где «Мест для пассажиров N из M» — занято).
  testWidgets('детали: «Мест свободно» — свободно из всего (3 из 4), а не занято', (tester) async {
    await openDetails(tester, null, 'paid');
    expect(find.text('Мест свободно'), findsOneWidget);
    expect(find.text('3 из 4'), findsOneWidget);
    expect(find.text('Мест для пассажиров'), findsNothing);
    expect(find.text('1 из 4'), findsNothing);
  });

  // Одно правило на экране (принятое решение 2026-10-22): строка посылок — тоже свободно из всего, как места.
  testWidgets('детали: строка посылок — «S, M» и свободно из всего (1 из 3)', (tester) async {
    final dio = _dio({
      'GET /bookings/b1': _booking(status: 'paid'),
      'GET /trips/t1': {
        ..._tripDetails(),
        'parcelAllowed': true,
        'parcelSizes': ['S', 'M'],
        'parcelSeatsTotal': 3,
        'parcelSeatsFree': 1,
      },
    });
    await tester.pumpWidget(_app(dio, (repo) => BookingDetailsScreen(bookingId: 'b1', repository: repo)));
    await _settle(tester);
    expect(find.text('S, M'), findsOneWidget);
    expect(find.text('1 из 3'), findsOneWidget);
    expect(find.text('2 из 3'), findsNothing);
  });

  testWidgets('детали: без телефона строки «Номер телефона» нет', (tester) async {
    await openDetails(tester, null, 'requested');
    expect(find.text('Номер телефона'), findsNothing);
  });

  testWidgets('«Оплатить» при awaiting_payment вызывает pay и открывает booking/paid', (tester) async {
    final pushed = <String>[];
    final adapterRoutes = <String, Object>{
      'GET /bookings/b1': _booking(status: 'awaiting_payment', phone: '+7 000 000 00 00'),
      'GET /trips/t1': _tripDetails(phone: '+7 000 000 00 00'),
      'POST /bookings/b1/pay': _booking(status: 'paid'),
    };
    final dio = _dio(adapterRoutes);
    await tester.pumpWidget(_app(dio, (repo) => BookingDetailsScreen(bookingId: 'b1', repository: repo), pushed: pushed));
    await _settle(tester);

    await tester.tap(find.text('Оплатить'));
    await _settle(tester);
    expect((dio.httpClientAdapter as _Adapter).requests, contains('POST /bookings/b1/pay'));
    expect(pushed, ['${AppRoutes.bookingPaid}:b1']);

    // Возврат с «Оплачено» перезагружает детали (регрессия: setState с Future в замыкании).
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await _settle(tester);
    expect((dio.httpClientAdapter as _Adapter).requests.where((r) => r == 'GET /bookings/b1'), hasLength(2));
    expect(tester.takeException(), isNull);
    expect(find.text('Не удалось оплатить бронь. Попробуйте ещё раз'), findsNothing);
  });

  group('тексты ошибок оплаты по коду', () {
    Future<void> payWith(WidgetTester tester, Object payResponse) async {
      final dio = _dio({
        'GET /bookings/b1': _booking(status: 'awaiting_payment', phone: '+7 000 000 00 00'),
        'GET /trips/t1': _tripDetails(phone: '+7 000 000 00 00'),
        'POST /bookings/b1/pay': payResponse,
      });
      await tester.pumpWidget(_app(dio, (repo) => BookingDetailsScreen(bookingId: 'b1', repository: repo)));
      await _settle(tester);
      await tester.tap(find.text('Оплатить'));
      await _settle(tester);
    }

    testWidgets('invalid_transition — свой текст', (tester) async {
      await payWith(tester, MapEntry<int, Object>(409, {'code': 'invalid_transition', 'message': 'x'}));
      expect(find.text('Статус брони уже изменился. Обновите экран'), findsOneWidget);
    });

    testWidgets('trip_unavailable — свой текст', (tester) async {
      await payWith(tester, MapEntry<int, Object>(409, {'code': 'trip_unavailable', 'message': 'x'}));
      expect(find.text('Поездка больше недоступна'), findsOneWidget);
    });

    testWidgets('неизвестный код — общий текст', (tester) async {
      await payWith(tester, MapEntry<int, Object>(500, {'code': 'internal', 'message': 'x'}));
      expect(find.text('Не удалось оплатить бронь. Попробуйте ещё раз'), findsOneWidget);
    });
  });

  group('«Мои заказы - Есть заказы» ряд фильтров (настоящий Gilroy)', () {
    setUpAll(loadGilroy);

    for (final width in [375.0, 360.0]) {
      testWidgets('четыре фильтра не переполняют ряд на ширине ${width.toInt()}', (tester) async {
        tester.view.physicalSize = Size(width * 2, 812 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_app(_dio({'GET /bookings/mine': <Object>[], 'GET /orders/mine': <Object>[]}), (repo) => PassengerTripsScreen(repository: repo)));
        await _settle(tester);
        expect(find.text('Завершенные'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Последний чип целиком внутри поля 16 справа.
        final last = find.ancestor(of: find.text('Завершенные'), matching: find.byType(Container)).first;
        expect(tester.getBottomRight(last).dx, lessThanOrEqualTo(width - 16 + 0.01));
      });
    }

    testWidgets('чип по кадру: ширина = текст + 24, высота 34', (tester) async {
      tester.view.physicalSize = const Size(750, 1624);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(_dio({'GET /bookings/mine': <Object>[], 'GET /orders/mine': <Object>[]}), (repo) => PassengerTripsScreen(repository: repo)));
      await _settle(tester);
      final chip = find.ancestor(of: find.text('Все'), matching: find.byType(Container)).first;
      expect(tester.getSize(chip).height, 34);
      expect(tester.getSize(chip).width, closeTo(tester.getSize(find.text('Все')).width + 24, 0.01));
    });
  });

  testWidgets('строка «Ваша бронь: N мест, услуги» с суммой брони — последней в блоке цен', (tester) async {
    final dio = _dio({
      'GET /bookings/b1': {
        ..._booking(status: 'paid', seats: 2),
        'extras': [
          {'kind': 'luggage', 'price': 200},
          {'kind': 'pets', 'price': 100},
        ],
        'priceTotal': 1100,
      },
      'GET /trips/t1': _tripDetails(),
    });
    await tester.pumpWidget(_app(dio, (repo) => BookingDetailsScreen(bookingId: 'b1', repository: repo)));
    await _settle(tester);
    final row = find.text('Ваша бронь: 2 места, багаж, животное');
    expect(row, findsOneWidget);
    expect(find.text('1\u00A0100 ₽'), findsOneWidget);
    expect(tester.getTopLeft(row).dy, greaterThan(tester.getTopLeft(find.text('Между остановками')).dy));
  });

  testWidgets('посылка без места — «Ваша бронь: посылка S»', (tester) async {
    final dio = _dio({
      'GET /bookings/b1': {..._booking(status: 'paid', seats: 0, parcelOnly: true), 'extras': [{'kind': 'parcel_s', 'price': 400}]},
      'GET /trips/t1': _tripDetails(),
    });
    await tester.pumpWidget(_app(dio, (repo) => BookingDetailsScreen(bookingId: 'b1', repository: repo)));
    await _settle(tester);
    expect(find.text('Ваша бронь: посылка S'), findsOneWidget);
  });

  testWidgets('бронь на весь маршрут — строки «Между остановками» нет', (tester) async {
    final dio = _dio({
      'GET /bookings/b1': _booking(status: 'paid'),
      'GET /trips/t1': {..._tripDetails(), 'stops': [_stop(0, 'Улица Солнечная, дом 1'), _stop(1, 'Улица Лунная, дом 2')]},
    });
    await tester.pumpWidget(_app(dio, (repo) => BookingDetailsScreen(bookingId: 'b1', repository: repo)));
    await _settle(tester);
    expect(find.text('Стоимость поездки'), findsOneWidget);
    expect(find.text('Между остановками'), findsNothing);
    expect(find.text('Ваша бронь: 1 место'), findsOneWidget);
  });

  // Кадр «Детали поездки - Скролл»: блок цен — «Стоимость поездки → Стоимость перевозки посылки → Между остановками»,
  // между строками линия #e4e5e6.
  testWidgets('детали брони с посылкой («Детали поездки - Скролл»): порядок цен как в кадре, линии между строками', (tester) async {
    final dio = _dio({
      'GET /bookings/b1': {
        ..._booking(status: 'paid'),
        'parcelSize': 'S',
        'extras': [
          {'kind': 'parcel_s', 'price': 400},
        ],
      },
      'GET /trips/t1': _tripDetails(),
    });
    await tester.pumpWidget(_app(dio, (repo) => BookingDetailsScreen(bookingId: 'b1', repository: repo)));
    await _settle(tester);

    double y(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(y('Стоимость поездки'), lessThan(y('Стоимость перевозки посылки')));
    expect(y('Стоимость перевозки посылки'), lessThan(y('Между остановками')));
    final lines = find.descendant(of: find.byKey(const Key('booking_prices')), matching: find.byType(Divider));
    expect(lines, findsNWidgets(3)); // + строка «Ваша бронь»
    expect(tester.widget<Divider>(lines.first).color, const Color(0xFFE4E5E6));
    expect(tester.getRect(lines.first).top, greaterThan(y('Стоимость поездки')));
    expect(tester.getRect(lines.first).bottom, lessThanOrEqualTo(y('Стоимость перевозки посылки')));
  });
}
