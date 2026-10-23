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
import 'package:the_way/src/features/driver_trips/data/driver_trips_repository.dart';
import 'package:the_way/src/features/driver_trips/details/driver_trip_details_screen.dart';
import 'package:the_way/src/features/driver_trips/details/trip_details_parts.dart';
import 'package:the_way/src/features/driver_trips/edit/trip_actions.dart';
import 'package:the_way/src/features/driver_trips/list/driver_trips_screen.dart';
import 'package:the_way/src/features/search/details/route_block.dart';
import 'package:the_way/src/theme/app_colors.dart';
import 'package:the_way/src/theme/app_theme.dart';
import 'package:the_way/src/widgets/app_bottom_sheet.dart';
import 'package:the_way/src/widgets/app_button.dart';
import 'package:the_way/src/widgets/app_dialog.dart';
import 'package:the_way/src/widgets/confirm_sheet.dart';
import 'package:the_way/src/widgets/app_header.dart';
import 'package:the_way/src/widgets/app_icon.dart';
import '../../support/expand_checks.dart';
import '../auth/fake_api.dart' show loadGilroy;
import 'package:the_way/src/widgets/road_illustration.dart';

/// Отвечает по таблице `метод путь -> тело`; запросы записываются вместе с параметрами.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.routes);

  final Map<String, Object> routes;
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add('${options.method} ${options.uri.path}${options.uri.hasQuery ? '?${options.uri.query}' : ''}');
    var body = routes['${options.method} ${options.uri.path}'];
    var status = body == null ? 404 : 200;
    if (body is MapEntry<int, Object>) {
      status = body.key;
      body = body.value;
    }
    return ResponseBody.fromString(
      jsonEncode(body ?? {'code': 'not_found', 'message': 'x'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _user({String name = 'Виктор О.', String id = 'd1'}) => {
      'id': id,
      'name': name,
      'rating': {'value': 4.5, 'count': 3},
      'tripsCount': 127,
    };

Map<String, Object?> _stop(int idx, String address) =>
    {'idx': idx, 'cityId': idx + 1, 'cityName': 'Город $idx', 'address': address, 'shortAddress': address};

Map<String, Object?> _tripCard({String status = 'active'}) => {
      'id': 't1',
      'number': 1231,
      'kind': 'ride',
      'from': _stop(0, 'Улица Солнечная, дом 1'),
      'to': _stop(2, 'Улица Лунная, дом 2'),
      'stopsCount': 1,
      'departsAt': '2026-05-16T09:00:00.000Z',
      'arrivesAt': '2026-05-16T12:00:00.000Z',
      'seatsFree': 14,
      'seatsTotal': 24,
      'parcelSeatsFree': 1,
      'parcelSeatsTotal': 3,
      'price': 1200,
      'driver': _user(),
      'extras': <String>[],
      'parcelAllowed': true,
      'parcelSizes': ['S', 'M'],
      'duplicates': 1,
      'registrationOpen': true,
      'bookable': false,
      'parcelBookable': false,
      'effectiveStatus': status,
    };

Map<String, Object?> _driverCard({int paid = 0}) =>
    {..._tripCard(), 'requested': 0, 'awaitingPayment': 0, 'paid': paid, 'parcels': 0, 'responders': <Object>[]};

Map<String, Object?> _tripDetails({bool editLocked = false, int seatsFree = 14, String status = 'active'}) => {
      ..._tripCard(status: status),
      'stops': [_stop(0, 'Улица Солнечная, дом 1'), _stop(1, 'Улица Ленина, дом 5'), _stop(2, 'Улица Лунная, дом 2')],
      'prices': [
        {'fromIdx': 0, 'toIdx': 1, 'price': 400},
        {'fromIdx': 1, 'toIdx': 2, 'price': 900},
      ],
      'priceBoardingMin': 100,
      'extrasPriced': <Object>[],
      'parcelOnlyAllowed': false,
      'bookingMode': 'standard',
      'car': {
        'id': 'c1',
        'brand': 'Solaris',
        'model': 'StarLiner',
        'kind': 'bus',
        'seats': 24,
        'plate': '7841HX-7',
        'status': 'verified',
        'documents': <Object>[],
      },
      'isMine': true,
      'editLocked': editLocked,
      'seatsFree': seatsFree,
      'paidTotal': 600,
    };

Map<String, Object?> _booking({
  String status = 'paid',
  num? segmentKm = 3.2,
  bool parcelOnly = false,
  String? parcelSize,
  bool noReviews = false,
  int passengerTrips = 127,
}) =>
    {
      'id': 'b1',
      'number': 5,
      'status': status,
      'segmentKm': ?segmentKm,
      'seats': 1,
      'fromIdx': 0,
      'toIdx': 1,
      'from': _stop(0, 'Улица Солнечная, дом 1'),
      'to': _stop(1, 'Улица Ленина, дом 5'),
      'segmentPrice': 400,
      'parcelSize': parcelSize ?? (parcelOnly ? 'M' : 'none'),
      'parcelOnly': parcelOnly,
      'extras': <Object>[],
      'priceTotal': 600,
      'createdAt': '2026-05-10T09:00:00.000Z',
      'trip': _tripCard(),
      'passenger': {
        ..._user(name: 'Анна К.', id: 'p1'),
        'tripsCount': passengerTrips,
        if (noReviews) 'rating': {'value': 5, 'count': 0},
      },
    };

Dio _dio(Map<String, Object> routes) => Dio(BaseOptions(baseUrl: 'http://test'))
  ..transformer = SyncTransformer()
  ..httpClientAdapter = _Adapter(routes);

Widget _app(Dio dio, Widget Function(DriverTripsRepository) screen, {List<String>? pushed}) {
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
      home: screen(DriverTripsRepository(session.api)),
    ),
  );
}

/// Ответ Dio идёт через таймеры нулевой длины: прокручиваем часы теста, пока экран не получит данные.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('список: запрос status=active, вкладка «Завершенные» шлёт status=completed', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dio = _dio({
      'GET /trips/mine': [_driverCard(paid: 1)],
    });
    await tester.pumpWidget(_app(dio, (repo) => DriverTripsScreen(repository: repo)));
    await _settle(tester);

    expect(find.text('Заказ №1231'), findsOneWidget);
    expect(find.text('1 отклик'), findsOneWidget);
    // Промежуточные остановки на карточке водителя — «1 остановка», как у пассажира.
    expect(find.text('1 остановка'), findsOneWidget);
    expect((dio.httpClientAdapter as _Adapter).requests, ['GET /trips/mine?status=active']);

    await tester.tap(find.text('Завершенные'));
    await _settle(tester);
    expect((dio.httpClientAdapter as _Adapter).requests.last, 'GET /trips/mine?status=completed');
  });

  testWidgets('пустой список: тексты «Базовые экраны - Поездок нет» и «Создать заказ» ведёт в trip_new', (tester) async {
    final pushed = <String>[];
    final dio = _dio({'GET /trips/mine': <Object>[]});
    await tester.pumpWidget(_app(dio, (repo) => DriverTripsScreen(repository: repo), pushed: pushed));
    await _settle(tester);

    expect(find.text('У вас пока нет поездок'), findsOneWidget);
    await tester.tap(find.text('Создать заказ'));
    await tester.pump();
    expect(pushed, ['${AppRoutes.tripNew}:null']);
  });

  testWidgets('«Завершенные» пусто — «Завершённых поездок пока нет», без «Создать заказ»; «Активные» — как «Базовые экраны - Поездок нет»', (tester) async {
    final dio = _dio({'GET /trips/mine': <Object>[]});
    await tester.pumpWidget(_app(dio, (repo) => DriverTripsScreen(repository: repo)));
    await _settle(tester);
    expect(find.text('Создать заказ'), findsOneWidget);

    await tester.tap(find.text('Завершенные'));
    await _settle(tester);
    expect(find.text('Завершённых поездок пока нет'), findsOneWidget);
    expect(find.text('У вас пока нет поездок'), findsNothing);
    expect(find.text('Создать заказ'), findsNothing);

    await tester.tap(find.text('Активные'));
    await _settle(tester);
    expect(find.text('У вас пока нет поездок'), findsOneWidget);
    expect(find.text('Создать заказ'), findsOneWidget);
  });

  group('детали', () {
    // Настоящие ширины текста: с Ahem проверка переполнения на 360 ничего не значит.
    setUpAll(loadGilroy);

    Future<_Adapter> open(WidgetTester tester,
        {List<Object> bookings = const [], List<String>? pushed, double width = 800}) async {
      tester.view.physicalSize = Size(width, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final dio = _dio({
        'GET /trips/t1': _tripDetails(),
        'GET /trips/t1/bookings': bookings,
      });
      await tester.pumpWidget(_app(dio, (repo) => DriverTripDetailsScreen(tripId: 't1', repository: repo), pushed: pushed));
      await _settle(tester);
      return dio.httpClientAdapter as _Adapter;
    }

    testWidgets('«Детали поездки созданной водителем - Без пассажиров» – «Редактирование - Нельзя выбрать кол-во мест меньше чем УЖЕ занято»: шапка «Поездка» без нижней линии', (tester) async {
      await open(tester);
      expect(tester.widget<AppHeader>(find.byType(AppHeader)).bordered, isFalse);
    });

    testWidgets('«Детали поездки - С пассажирами»: иллюстрация дороги 293×290 вверху карточки маршрута', (tester) async {
      await open(tester);
      final road = find.byType(RoadIllustration);
      expect(road, findsOneWidget);
      expect(tester.getSize(find.descendant(of: road, matching: find.byType(SvgPicture))), const Size(293, 290));
      expect(tester.getRect(road).bottom, lessThanOrEqualTo(tester.getTopLeft(find.byType(RouteBlock)).dy));
    });

    testWidgets('«Детали поездки созданной водителем - Без пассажиров» – «Детали поездки - С пассажирами»: кнопка «N остановок» по нажатию исчезает, на её месте остановка', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('route_stops_chip')), findsOneWidget);
      expect(find.text('Город 1, Улица Ленина, дом 5'), findsNothing);
      await tester.tap(find.byKey(const Key('route_stops_chip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('route_stops_chip')), findsNothing);
      expect(find.text('Город 1, Улица Ленина, дом 5'), findsOneWidget);
    });

    testWidgets('верх — «Стоимость» = paidTotal; «Комиссии» и «К оплате водителю» нет', (tester) async {
      await open(tester);
      expect(find.text('Стоимость'), findsOneWidget);
      expect(find.text('600 ₽'), findsOneWidget);
      expect(find.text('Комиссия'), findsNothing);
      expect(find.text('К оплате водителю'), findsNothing);
      expect(find.text('Повторить поездку'), findsNothing);
      expect(find.text('10 из 24'), findsOneWidget);
      expect(find.text('2 из 3'), findsOneWidget);
      expect(find.text('Пассажиры'), findsNothing);
    });

    testWidgets('«Детали поездки созданной водителем - Без пассажиров» на ширине 320: блок цен без RenderFlex overflowed, список цен раскрывается', (tester) async {
      await open(tester, width: 320);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Смотреть стоимость'));
      await tester.tap(find.text('Смотреть стоимость'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('сверка с кадрами «Детали поездки созданной водителем - Без пассажиров» – «Детали поездки - С пассажирами»: шапка без линии, панель кнопки на фоне экрана, разделитель цен', (tester) async {
      await open(tester);
      expect(tester.widget<AppHeader>(find.byType(AppHeader)).bordered, isFalse);
      final bar = find.ancestor(of: find.text('Отменить поездку'), matching: find.byType(ColoredBox)).first;
      expect(tester.widget<ColoredBox>(bar).color, AppColors.bgScreen);
      expect(find.descendant(of: find.byType(WhiteCard).last, matching: find.byType(Divider)), findsOneWidget);
    });

    testWidgets('блок «Водитель»: кнопка со стрелкой открывает профиль, значок авто — полупрозрачный', (tester) async {
      final pushed = <String>[];
      await open(tester, pushed: pushed);
      final arrow = find.byWidgetPredicate((w) => w is AppIcon && w.name == 'arrows_alt_arrow_right');
      expect(arrow, findsOneWidget);
      await tester.tap(arrow);
      await tester.pump();
      expect(pushed, ['${AppRoutes.profile}:null']);
      final bus = tester.widget<AppIcon>(find.byWidgetPredicate((w) => w is AppIcon && w.name == 'system_bus'));
      expect(bus.color, AppColors.textSecondary);
    });

    testWidgets('«Смотреть стоимость» раскрывает цены отрезков', (tester) async {
      await open(tester);
      expect(find.text('Стоимость поездки'), findsOneWidget);
      expect(find.text('1\u00A0200 ₽'), findsOneWidget);
      expect(find.text('900 ₽'), findsNothing);
      await tester.tap(find.text('Смотреть стоимость'));
      await tester.pump();
      expect(find.text('900 ₽'), findsOneWidget);
    });

    testWidgets('«Смотреть стоимость» — анимация раскрытия 350 мс, как у остановок', (tester) async {
      await open(tester);
      await expectExpandCycle(
        tester,
        chip: const Key('driver_prices_chip'),
        collapse: const Key('driver_prices_collapse'),
        item: find.text('900 ₽'),
      );
    });

    testWidgets('пассажир открывает driver_bookings/passenger с userId и bookingId', (tester) async {
      final pushed = <String>[];
      await open(tester, bookings: [_booking()], pushed: pushed);
      expect(find.text('Пассажиры'), findsOneWidget);
      await tester.tap(find.text('Анна К.'));
      await tester.pump();
      expect(pushed, ['${AppRoutes.driverBookingsPassenger}:{userId: p1, bookingId: b1}']);
    });

    testWidgets('заголовок «Пассажиры» открывает driver_bookings с tripId; по возврату детали перечитываются', (tester) async {
      final pushed = <String>[];
      final adapter = await open(tester, bookings: [_booking()], pushed: pushed);
      await tester.tap(find.text('Пассажиры'));
      await tester.pump();
      expect(pushed, ['${AppRoutes.driverBookings}:t1']);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await _settle(tester);
      expect(adapter.requests.where((r) => r == 'GET /trips/t1'), hasLength(2));
    });

    testWidgets('строка пассажира: расстояние и тип заказа («Детали поездки - С пассажирами»)', (tester) async {
      await open(tester, bookings: [_booking()]);
      expect(find.text('3.2 км'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('order-type-b1')), matching: find.text('Поездка')), findsOneWidget);
    });

    testWidgets('строка пассажира: посылка — «Посылка M», без расстояния, если segmentKm нет', (tester) async {
      await open(tester, bookings: [_booking(parcelOnly: true, segmentKm: null)]);
      expect(find.descendant(of: find.byKey(const ValueKey('order-type-b1')), matching: find.text('Посылка M')), findsOneWidget);
      expect(find.textContaining(' км'), findsNothing);
    });
    testWidgets('строка пассажира на ширине 360: длинная метка и «нет отзывов» не переполняют строку («Детали поездки - С пассажирами»)', (tester) async {
      await open(tester, bookings: [_booking(parcelSize: 'S', noReviews: true, segmentKm: 77.7)], width: 360);
      expect(tester.takeException(), isNull);
      final name = tester.getTopLeft(find.text('Анна К.')).dy;
      final label = tester.getTopLeft(find.text('Поездка + посылка S')).dy;
      final km = tester.getTopLeft(find.text('77.7 км')).dy;
      // Имя и метка — первая строка, рейтинг и расстояние — вторая.
      expect((label - name).abs(), lessThan(12));
      expect(km, greaterThan(name + 12));
    });

    testWidgets('строка пассажира без отзывов — «5, нет отзывов • N поездок», с нулём поездок — без числа',
        (tester) async {
      await open(tester, bookings: [_booking(noReviews: true, passengerTrips: 4)]);
      expect(find.text('5, нет отзывов'), findsOneWidget);
      expect(find.text('4 поездки'), findsOneWidget);
    });

    testWidgets('строка пассажира без отзывов и без поездок — только «5, нет отзывов»', (tester) async {
      await open(tester, bookings: [_booking(noReviews: true, passengerTrips: 0)]);
      expect(find.text('5, нет отзывов'), findsOneWidget);
      expect(find.text('0 поездок'), findsNothing);
    });

    testWidgets('строка пассажира: место + посылка — «Поездка + посылка M»', (tester) async {
      await open(tester, bookings: [_booking(parcelSize: 'M')]);
      expect(
        find.descendant(of: find.byKey(const ValueKey('order-type-b1')), matching: find.text('Поездка + посылка M')),
        findsOneWidget,
      );
    });
  });

  group('меню поездки', () {
    Future<_Adapter> open(
      WidgetTester tester, {
      Map<String, Object> extra = const {},
      Map<String, Object?>? trip,
      List<Object> bookings = const [],
      List<String>? pushed,
    }) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final dio = _dio({
        'GET /trips/t1': trip ?? _tripDetails(),
        'GET /trips/t1/bookings': bookings,
        ...extra,
      });
      await tester.pumpWidget(_app(dio, (repo) => DriverTripDetailsScreen(tripId: 't1', repository: repo), pushed: pushed));
      await _settle(tester);
      return dio.httpClientAdapter as _Adapter;
    }

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byType(AppIconButton).last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('пункты: места, правка, завершить приём; «Передать пассажиров» нет', (tester) async {
      await open(tester);
      await openMenu(tester);
      expect(find.text('Изменить количество мест'), findsOneWidget);
      expect(find.text('Редактировать'), findsOneWidget);
      expect(find.text('Завершить приём пассажиров'), findsOneWidget);
      expect(find.text('Передать пассажиров'), findsNothing);
    });

    testWidgets('editLocked: «Редактировать» открывает окно «Редактирование недоступно»', (tester) async {
      final pushed = <String>[];
      await open(tester, trip: _tripDetails(editLocked: true), pushed: pushed);
      await openMenu(tester);
      await tester.tap(find.text('Редактировать'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Редактирование недоступно'), findsOneWidget);
      expect(find.text('Понятно'), findsOneWidget);
      expect(pushed, isEmpty);
    });

    testWidgets('без блокировки «Редактировать» ведёт в trip_new/edit с tripId', (tester) async {
      final pushed = <String>[];
      await open(tester, pushed: pushed);
      await openMenu(tester);
      await tester.tap(find.text('Редактировать'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(pushed, ['${AppRoutes.tripNewEdit}:t1']);
    });

    final minus = find.byWidgetPredicate((w) => w is AppIcon && w.name == 'essentional_minus_circle');

    testWidgets('места: «Сохранить» неактивна без изменений, после «−» шлёт POST /seats и снэкбар', (tester) async {
      final adapter = await open(tester, extra: {'POST /trips/t1/seats': _tripDetails()});
      await openMenu(tester);
      await tester.tap(find.text('Изменить количество мест'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Количество мест'), findsOneWidget);
      await tester.tap(find.text('Сохранить'));
      await tester.pump();
      expect(adapter.requests.where((r) => r.startsWith('POST')), isEmpty);

      await tester.tap(minus);
      await tester.pump();
      expect(find.text('23'), findsOneWidget);
      await tester.tap(find.text('Сохранить'));
      await _settle(tester);
      expect(adapter.requests, contains('POST /trips/t1/seats'));
      expect(find.text('Изменения сохранены'), findsOneWidget);
    });

    testWidgets('места («Редактирование - Нельзя выбрать кол-во мест меньше чем УЖЕ занято»): на числе занятых «−» неактивен и бледный, ниже не убавить', (tester) async {
      // 24 места, свободно 1 → занято 23: после одного «−» счётчик стоит на нижней границе.
      await open(tester, trip: _tripDetails(seatsFree: 1));
      await openMenu(tester);
      await tester.tap(find.text('Изменить количество мест'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<AppIcon>(minus).color, AppColors.textPrimary);
      await tester.tap(minus);
      await tester.pump();
      expect(find.text('23'), findsOneWidget);
      expect(tester.widget<AppIcon>(minus).color, AppColors.textSecondary);
      await tester.tap(minus);
      await tester.pump();
      expect(find.text('23'), findsOneWidget);
      expect(find.text('22'), findsNothing);
      expect(find.text('Меньше занятого нельзя'), findsNothing);
    });

    testWidgets('места: seats_below_taken показывает «Меньше занятого нельзя»', (tester) async {
      await open(tester, extra: {
        'POST /trips/t1/seats': MapEntry<int, Object>(409, {'code': 'seats_below_taken', 'message': 'x'}),
      });
      await openMenu(tester);
      await tester.tap(find.text('Изменить количество мест'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(minus);
      await tester.pump();
      await tester.tap(find.text('Сохранить'));
      await _settle(tester);
      expect(find.text('Меньше занятого нельзя'), findsOneWidget);
    });

    testWidgets('отмена с пассажирами (editLocked): окно с числом отмен и POST /cancel', (tester) async {
      final adapter = await open(tester, trip: _tripDetails(editLocked: true), bookings: [_booking()], extra: {
        'GET /trips/t1/cancel-preview': {'cancellationsLast30': 2, 'willBlock': false},
        'POST /trips/t1/cancel': {'status': 'cancelled', 'cancellationsLast30': 3},
      });
      await tester.tap(find.text('Отменить поездку'));
      await _settle(tester);
      expect(find.text('Отменить поездку?'), findsOneWidget);
      expect(find.text('Отмена повлияет на аккаунт: отмен за 30 дней — 2'), findsOneWidget);
      // Образец «Новый заказ - Выбор доп услуг»: нижний лист с ручкой, заголовок, текст и две кнопки в ряд — «назад» слева, действие справа.
      expect(find.byType(AppDialog), findsNothing);
      expect(find.byType(ConfirmSheet), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBottomSheet), matching: find.text('Отменить поездку?')), findsOneWidget);
      final back = tester.getCenter(find.descendant(of: find.byType(ConfirmSheet), matching: find.text('Не отменять')));
      final act = tester.getCenter(find.descendant(of: find.byType(ConfirmSheet), matching: find.text('Отменить поездку')));
      expect(back.dy, act.dy);
      expect(back.dx, lessThan(act.dx));
      await tester.tap(find.text('Отменить поездку').last);
      await _settle(tester);
      expect(adapter.requests, contains('POST /trips/t1/cancel'));
      expect(find.text('Аккаунт временно заблокирован'), findsNothing, reason: 'блокировки нет — экрана нет');
    });

    testWidgets('отмена дала блокировку (blockedUntil): после отмены — экран «Бронь отменена» с «Публикация новых поездок…»',
        (tester) async {
      await open(tester, trip: _tripDetails(editLocked: true), bookings: [_booking()], extra: {
        'GET /trips/t1/cancel-preview': {'cancellationsLast30': 1, 'willBlock': true},
        'POST /trips/t1/cancel': {
          'status': 'cancelled',
          'cancellationsLast30': 2,
          'blockedUntil': '2026-11-21T10:00:00.000Z',
        },
      });
      await tester.tap(find.text('Отменить поездку'));
      await _settle(tester);
      await tester.tap(find.text('Отменить поездку').last);
      await _settle(tester);

      expect(find.text('Аккаунт временно заблокирован'), findsOneWidget);
      expect(find.textContaining('Публикация новых поездок'), findsOneWidget);
      await tester.tap(find.text('Понятно'));
      await tester.pumpAndSettle(); // выезд маршрута длится дольше пяти шагов _settle
      expect(find.text('Аккаунт временно заблокирован'), findsNothing);
    });

    testWidgets('завершить приём шлёт POST /close-intake', (tester) async {
      final adapter = await open(tester, extra: {'POST /trips/t1/close-intake': _tripDetails()});
      await openMenu(tester);
      await tester.tap(find.text('Завершить приём пассажиров'));
      await _settle(tester);
      expect(adapter.requests, contains('POST /trips/t1/close-intake'));
    });

    testWidgets('отмена с одними заявками requested (editLocked = false): текст без числа отмен', (tester) async {
      await open(tester, bookings: [_booking(status: 'requested')], extra: {
        'GET /trips/t1/cancel-preview': {'cancellationsLast30': 2, 'willBlock': false},
      });
      await tester.tap(find.text('Отменить поездку'));
      await _settle(tester);
      expect(find.text('Поездка будет отменена'), findsOneWidget);
      expect(find.textContaining('отмен за 30 дней'), findsNothing);
    });

    testWidgets('при intake_closed три пункта на месте, «Завершить приём» неактивен', (tester) async {
      final adapter = await open(tester, trip: _tripDetails(status: 'intake_closed'), extra: {
        'POST /trips/t1/close-intake': _tripDetails(),
      });
      await openMenu(tester);
      expect(find.text('Изменить количество мест'), findsOneWidget);
      expect(find.text('Редактировать'), findsOneWidget);
      expect(find.text('Завершить приём пассажиров'), findsOneWidget);
      final items = tester.widgetList<PopupMenuItem<TripMenuItem>>(find.byType(PopupMenuItem<TripMenuItem>)).toList();
      expect(items.map((i) => i.enabled), [true, true, false]);
      await tester.tap(find.text('Завершить приём пассажиров'));
      await _settle(tester);
      expect(adapter.requests.where((r) => r.startsWith('POST')), isEmpty);
    });

    testWidgets('после возврата из правки снэкбар «Изменения сохранены» не показывается (его показывает U3)', (tester) async {
      await open(tester);
      await openMenu(tester);
      await tester.tap(find.text('Редактировать'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      tester.state<NavigatorState>(find.byType(Navigator)).pop(true);
      await _settle(tester);
      expect(find.text('Изменения сохранены'), findsNothing);
    });

    group('тексты ошибок по коду', () {
      Map<String, Object> failing(String path, int status, String code) => {
            path: MapEntry<int, Object>(status, {'code': code, 'message': 'x'}),
          };

      testWidgets('завершить приём: invalid_transition — свой текст', (tester) async {
        await open(tester, extra: failing('POST /trips/t1/close-intake', 409, 'invalid_transition'));
        await openMenu(tester);
        await tester.tap(find.text('Завершить приём пассажиров'));
        await _settle(tester);
        expect(find.text('Статус поездки уже изменился. Обновите экран'), findsOneWidget);
      });

      testWidgets('завершить приём: неизвестный код — общий текст', (tester) async {
        await open(tester, extra: failing('POST /trips/t1/close-intake', 500, 'internal'));
        await openMenu(tester);
        await tester.tap(find.text('Завершить приём пассажиров'));
        await _settle(tester);
        expect(find.text('Не удалось выполнить действие. Попробуйте ещё раз'), findsOneWidget);
      });

      testWidgets('отмена: forbidden на POST /cancel — свой текст', (tester) async {
        await open(tester, extra: {
          'GET /trips/t1/cancel-preview': {'cancellationsLast30': 0, 'willBlock': false},
          ...failing('POST /trips/t1/cancel', 403, 'forbidden'),
        });
        await tester.tap(find.text('Отменить поездку'));
        await _settle(tester);
        await tester.tap(find.text('Отменить поездку').last);
        await _settle(tester);
        expect(find.text('Это действие вам недоступно'), findsOneWidget);
      });

      testWidgets('отмена: not_found на cancel-preview — свой текст', (tester) async {
        await open(tester, extra: failing('GET /trips/t1/cancel-preview', 404, 'not_found'));
        await tester.tap(find.text('Отменить поездку'));
        await _settle(tester);
        expect(find.text('Поездка не найдена'), findsOneWidget);
      });

      testWidgets('места: invalid_transition — свой текст, не общий', (tester) async {
        await open(tester, extra: failing('POST /trips/t1/seats', 409, 'invalid_transition'));
        await openMenu(tester);
        await tester.tap(find.text('Изменить количество мест'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(minus);
        await tester.pump();
        await tester.tap(find.text('Сохранить'));
        await _settle(tester);
        expect(find.text('Статус поездки уже изменился. Обновите экран'), findsOneWidget);
      });
    });
  });
}
