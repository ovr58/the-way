import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/app_routes.dart';
import 'package:the_way/src/features/driver_trips/edit/trip_actions.dart' show TripMenuItem;
import 'package:the_way/src/features/driver_bookings/events/driver_event_screen.dart' show DriverEventScreen;
import 'package:the_way/src/features/driver_bookings/routes.dart';
import 'package:the_way/src/theme/app_colors.dart';
import 'package:the_way/src/widgets/app_bottom_sheet.dart';
import 'package:the_way/src/widgets/app_dialog.dart';
import 'package:the_way/src/widgets/confirm_sheet.dart';
import 'package:the_way/src/widgets/app_header.dart';
import 'package:the_way/src/widgets/app_icon.dart';
import 'package:the_way/src/widgets/road_illustration.dart';

import '../../support/expand_checks.dart';
import 'support.dart';

/// Экран целиком: без прокрутки видны все блоки.
void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget route(String name, Object? args) =>
    Builder(builder: (context) => driverBookingsRoutes[name]!(context, args));

Future<MockAdapter> open(
  WidgetTester tester,
  String routeName,
  Object? args,
  Map<String, Object?> routes, {
  List<(String, Object?)>? pushed,
}) async {
  tallScreen(tester);
  final adapter = MockAdapter(routes);
  await tester.pumpWidget(testApp(session: makeSession(adapter), home: route(routeName, args), pushed: pushed));
  await settle(tester);
  return adapter;
}

Map<String, Object?> listRoutes({
  List<Object?>? bookings,
  int? paidTotal = 600,
  bool editLocked = true,
  String status = 'active',
}) =>
    {
      'GET /trips/t1': tripDetails(paidTotal: paidTotal, editLocked: editLocked, status: status),
      'GET /trips/t1/bookings': bookings ??
          [
            booking(id: 'b1', status: 'requested', passengerName: 'Анна П.'),
            booking(id: 'b2', status: 'awaiting_payment', passengerId: 'p2', passengerName: 'Борис К.'),
            booking(id: 'b3', status: 'paid', passengerId: 'p3', passengerName: 'Вера Л.'),
          ],
    };

void main() {
  group('список заявок («Редактирование - Пассажиры есть» – «Бронь отклонена»)', () {
    testWidgets('«Редактирование - Пассажиры есть» – «Отлик»: шапка без нижней линии', (tester) async {
      await open(tester, AppRoutes.driverBookings, 't1', listRoutes());
      expect(tester.widget<AppHeader>(find.byType(AppHeader)).bordered, isFalse);
    });

    testWidgets('«Редактирование - Пассажиры есть»: иллюстрация дороги 293×169 вверху карточки маршрута, над первым адресом', (tester) async {
      await open(tester, AppRoutes.driverBookings, 't1', listRoutes());
      final road = find.byType(RoadIllustration);
      expect(road, findsOneWidget);
      expect(tester.getSize(find.descendant(of: road, matching: find.byType(SvgPicture))), const Size(293, 169));
      expect(tester.getRect(road).bottom, lessThan(tester.getTopLeft(find.text('Ярославль, Улица Солнечная, дом 1')).dy));
    });

    testWidgets('подписи статусов по таблице «Подписи статусов»', (tester) async {
      await open(tester, AppRoutes.driverBookings, 't1', listRoutes());
      expect(find.text('Анна П.'), findsOneWidget);
      expect(find.text('Не подтверждён'), findsOneWidget); // через «ё», как «Подтверждён» рядом и CONTEXT.md

      expect(find.text('Ожидает оплаты'), findsOneWidget);
      expect(find.text('Подтверждён'), findsOneWidget);
    });

    testWidgets('цены: верх — paidTotal, низ — priceFull, комиссии нет', (tester) async {
      await open(tester, AppRoutes.driverBookings, 't1', listRoutes(paidTotal: 600));
      expect(find.text('Стоимость'), findsOneWidget);
      expect(find.text('600 ₽'), findsOneWidget);
      expect(find.text('Стоимость поездки'), findsOneWidget);
      expect(find.text('1\u00A0200 ₽'), findsOneWidget);
      expect(find.text('Комиссия'), findsNothing);
      expect(find.text('К оплате водителю'), findsNothing);
    });

    testWidgets('«Смотреть стоимость» раскрывает цены отрезков', (tester) async {
      await open(tester, AppRoutes.driverBookings, 't1', listRoutes());
      expect(find.text('Ярославль, Улица Солнечная, дом 1 - Ростов, Улица Ленина, дом 5'), findsNothing);
      await tester.tap(find.text('Смотреть стоимость'));
      await tester.pump();
      expect(find.text('Ярославль, Улица Солнечная, дом 1 - Ростов, Улица Ленина, дом 5'), findsOneWidget);
      expect(find.text('400 ₽'), findsOneWidget);
      expect(find.text('Ростов, Улица Ленина, дом 5 - Москва, Улица Лунная, дом 2'), findsOneWidget);
      expect(find.text('800 ₽'), findsOneWidget);
    });

    testWidgets('«Смотреть стоимость» — анимация раскрытия 350 мс, как у остановок', (tester) async {
      await open(tester, AppRoutes.driverBookings, 't1', listRoutes());
      await expectExpandCycle(
        tester,
        chip: const Key('booking_prices_chip'),
        collapse: const Key('booking_prices_collapse'),
        item: find.text('400 ₽'),
      );
    });

    testWidgets('без заявок — надпись, без paidTotal — 0 ₽', (tester) async {
      await open(tester, AppRoutes.driverBookings, 't1', listRoutes(bookings: [], paidTotal: null));
      expect(find.text('Заявок пока нет'), findsOneWidget);
      expect(find.text('0 ₽'), findsOneWidget);
    });

    testWidgets('нажатие на принятую заявку открывает профиль пассажира', (tester) async {
      final pushed = <(String, Object?)>[];
      await open(tester, AppRoutes.driverBookings, 't1', listRoutes(), pushed: pushed);
      await tester.tap(find.text('Борис К.'));
      await tester.pumpAndSettle();
      expect(pushed.single.$1, AppRoutes.driverBookingsPassenger);
      expect(pushed.single.$2, {'userId': 'p2', 'bookingId': 'b2'});
    });

    testWidgets('ошибка загрузки — экран с повтором', (tester) async {
      await open(tester, AppRoutes.driverBookings, 't1', {'GET /trips/t1': (500, {'code': 'internal', 'message': 'x'})});
      expect(find.text('Обновить'), findsOneWidget);
    });

    testWidgets('«Прибытие» со значком часов, как на «Детали поездки - С пассажирами» и в кадрах «Редактирование - Пассажиры есть» – «Отлик»', (tester) async {
      await open(tester, AppRoutes.driverBookings, 't1', listRoutes());
      expect(find.textContaining('Прибытие ~'), findsOneWidget);
      final clock = find.byWidgetPredicate((w) => w is AppIcon && w.name == 'time_history');
      expect(clock, findsOneWidget);
      // Значок стоит в одной строке с надписью, слева от неё.
      final icon = tester.getCenter(clock);
      final label = tester.getCenter(find.textContaining('Прибытие ~'));
      expect((icon.dy - label.dy).abs(), lessThan(4));
      expect(icon.dx, lessThan(tester.getTopLeft(find.textContaining('Прибытие ~')).dx));
    });
  });

  group('меню поездки в шапке «Пассажиры» («Редактирование - Пассажиры есть»)', () {
    final menuButton = find.byWidgetPredicate((w) => w is AppIcon && w.name == 'system_menu_dots');

    testWidgets('«⋯» открывает то же меню, что в деталях: три пункта', (tester) async {
      await open(tester, AppRoutes.driverBookings, 't1', listRoutes());
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();
      expect(find.text('Изменить количество мест'), findsOneWidget);
      expect(find.text('Редактировать'), findsOneWidget);
      expect(find.text('Завершить приём пассажиров'), findsOneWidget);
      expect(find.text('Передать пассажиров'), findsNothing);
    });

    testWidgets('«Завершить приём» шлёт POST /close-intake и перечитывает заявки', (tester) async {
      final adapter = await open(tester, AppRoutes.driverBookings, 't1', {
        ...listRoutes(),
        'POST /trips/t1/close-intake': tripDetails(status: 'intake_closed'),
      });
      await tester.tap(menuButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Завершить приём пассажиров'));
      await settle(tester);
      expect(adapter.log, contains('POST /trips/t1/close-intake'));
      expect(adapter.log.where((r) => r == 'GET /trips/t1'), hasLength(2));
    });

    testWidgets('приём закрыт: три пункта на месте, «Завершить приём» неактивен', (tester) async {
      await open(tester, AppRoutes.driverBookings, 't1', listRoutes(status: 'intake_closed'));
      await tester.tap(menuButton);
      await tester.pumpAndSettle();
      final items = tester.widgetList<PopupMenuItem<TripMenuItem>>(find.byType(PopupMenuItem<TripMenuItem>)).toList();
      expect(items.map((i) => i.enabled), [true, true, false]);
    });

    testWidgets('поездка не действующая (завершена) — меню в шапке нет', (tester) async {
      await open(tester, AppRoutes.driverBookings, 't1', listRoutes(status: 'completed'));
      expect(find.text('Поездка'), findsOneWidget);
      expect(menuButton, findsNothing);
    });
  });

  group('отмена поездки («Редактирование - Пассажиры есть»)', () {
    Finder dialogText(String text) => find.descendant(of: find.byType(ConfirmSheet), matching: find.text(text));
    final cancelRoutes = {
      'GET /trips/t1/cancel-preview': {'cancellationsLast30': 1, 'willBlock': false},
      'POST /trips/t1/cancel': {'status': 'cancelled', 'cancellationsLast30': 2},
    };

    testWidgets('с пассажирами: окно про счёт отмен, POST /cancel, возврат к деталям с результатом', (tester) async {
      final pushed = <(String, Object?)>[];
      Object? result;
      tallScreen(tester);
      final adapter = MockAdapter({...listRoutes(), ...cancelRoutes});
      await tester.pumpWidget(testApp(
        session: makeSession(adapter),
        pushed: pushed,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await Navigator.of(context)
                .push<Object?>(MaterialPageRoute(builder: (_) => route(AppRoutes.driverBookings, 't1'))),
            child: const Text('к пассажирам'),
          ),
        ),
      ));
      await tester.tap(find.text('к пассажирам'));
      await settle(tester);
      await tester.tap(find.text('Отменить поездку'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(adapter.log, contains('GET /trips/t1/cancel-preview'));
      expect(find.text('Отмена повлияет на аккаунт: отмен за 30 дней — 1'), findsOneWidget);
      // Образец «Новый заказ - Выбор доп услуг»: нижний лист с ручкой, заголовок, текст и две кнопки в ряд — «назад» слева, действие справа.
      expect(find.byType(AppDialog), findsNothing);
      expect(find.byType(ConfirmSheet), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBottomSheet), matching: find.text('Отменить поездку?')), findsOneWidget);
      final back = tester.getCenter(find.descendant(of: find.byType(ConfirmSheet), matching: find.text('Назад')));
      final act = tester.getCenter(find.descendant(of: find.byType(ConfirmSheet), matching: find.text('Отменить поездку')));
      expect(back.dy, act.dy);
      expect(back.dx, lessThan(act.dx));
      expect(adapter.log, isNot(contains('POST /trips/t1/cancel')));
      await tester.tap(dialogText('Отменить поездку'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(adapter.log, contains('POST /trips/t1/cancel'));
      expect(pushed, isEmpty, reason: 'новый экран деталей не кладётся поверх старого');
      expect(result, true);
      expect(find.text('к пассажирам'), findsOneWidget);
    });

    testWidgets('отмена дала блокировку (blockedUntil): возврат к деталям и поверх них экран «Бронь отменена» водителя',
        (tester) async {
      Object? result;
      tallScreen(tester);
      final adapter = MockAdapter({
        ...listRoutes(),
        ...cancelRoutes,
        'POST /trips/t1/cancel': {
          'status': 'cancelled',
          'cancellationsLast30': 2,
          'blockedUntil': '2026-11-21T10:00:00.000Z',
        },
      });
      await tester.pumpWidget(testApp(
        session: makeSession(adapter),
        pushed: <(String, Object?)>[],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await Navigator.of(context)
                .push<Object?>(MaterialPageRoute(builder: (_) => route(AppRoutes.driverBookings, 't1'))),
            child: const Text('к пассажирам'),
          ),
        ),
      ));
      await tester.tap(find.text('к пассажирам'));
      await settle(tester);
      await tester.tap(find.text('Отменить поездку'));
      await settle(tester);
      await tester.pumpAndSettle();
      await tester.tap(dialogText('Отменить поездку'));
      await settle(tester);
      await tester.pumpAndSettle();

      expect(result, true);
      expect(find.text('Аккаунт временно заблокирован'), findsOneWidget);
      expect(find.textContaining('Публикация новых поездок'), findsOneWidget);
      await tester.tap(find.text('Понятно'));
      await tester.pumpAndSettle();
      expect(find.text('Аккаунт временно заблокирован'), findsNothing);
      expect(find.text('к пассажирам'), findsOneWidget);
    });

    testWidgets('только непринятые заявки (editLocked: false) — окно без предупреждения', (tester) async {
      await open(tester, AppRoutes.driverBookings, 't1', {
        ...listRoutes(bookings: [booking(id: 'b1', status: 'requested')], editLocked: false),
        ...cancelRoutes,
      });
      await tester.tap(find.text('Отменить поездку'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('Отмена повлияет'), findsNothing);
      expect(find.text('Пассажиров нет, отмена не повлияет на аккаунт.'), findsOneWidget);
    });

    testWidgets('предупреждение даёт серверный editLocked, а не статусы заявок', (tester) async {
      await open(tester, AppRoutes.driverBookings, 't1', {
        ...listRoutes(bookings: [booking(id: 'b1', status: 'requested')], editLocked: true),
        ...cancelRoutes,
      });
      await tester.tap(find.text('Отменить поездку'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.text('Отмена повлияет на аккаунт: отмен за 30 дней — 1'), findsOneWidget);
    });

    testWidgets('без пассажиров — простой текст', (tester) async {
      await open(tester, AppRoutes.driverBookings, 't1', {...listRoutes(bookings: [], editLocked: false), ...cancelRoutes});
      await tester.tap(find.text('Отменить поездку'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('Отмена повлияет'), findsNothing);
      expect(find.text('Пассажиров нет, отмена не повлияет на аккаунт.'), findsOneWidget);
    });

    testWidgets('«Назад» в окне ничего не отменяет', (tester) async {
      final adapter = await open(tester, AppRoutes.driverBookings, 't1', {...listRoutes(), ...cancelRoutes});
      await tester.tap(find.text('Отменить поездку'));
      await settle(tester);
      await tester.pumpAndSettle();
      await tester.tap(dialogText('Назад'));
      await tester.pumpAndSettle();
      expect(adapter.log.where((e) => e.startsWith('POST')), isEmpty);
    });

    testWidgets('завершённую или отменённую поездку отменить нельзя — кнопки нет', (tester) async {
      await open(tester, AppRoutes.driverBookings, 't1', {
        ...listRoutes(),
        'GET /trips/t1': {...tripDetails(), 'effectiveStatus': 'completed'},
      });
      expect(find.text('Отменить поездку'), findsNothing);
    });

    testWidgets('приём закрыт (intake_closed) — кнопка есть', (tester) async {
      await open(tester, AppRoutes.driverBookings, 't1', {
        ...listRoutes(),
        'GET /trips/t1': {...tripDetails(), 'effectiveStatus': 'intake_closed'},
      });
      expect(find.text('Отменить поездку'), findsOneWidget);
    });
  });

  group('отклик одной заявки («Отлик»)', () {
    Future<MockAdapter> openResponse(WidgetTester tester, Map<String, Object?> extra, {String? comment}) async {
      var calls = 0;
      final adapter = await open(tester, AppRoutes.driverBookings, 't1', {
        ...listRoutes(bookings: [
          booking(id: 'b1', status: 'requested', parcelSize: 'M', parcelComment: comment, phone: '+79990000000'),
        ]),
        'GET /trips/t1/bookings': (RequestOptions o) {
          calls++;
          return calls == 1
              ? [booking(id: 'b1', status: 'requested', parcelSize: 'M', parcelComment: comment, phone: '+79990000000')]
              : <Object?>[];
        },
        ...extra,
      });
      await tester.tap(find.text('Анна П.'));
      await tester.pumpAndSettle();
      return adapter;
    }

    testWidgets('кнопки, цена брони, без телефона', (tester) async {
      await openResponse(tester, {});
      expect(find.text('Подтвердить бронь'), findsOneWidget);
      expect(find.text('Отклонить бронь'), findsOneWidget);
      // «Стоимость» и «Стоимость поездки» = priceTotal этой брони.
      expect(find.text('800 ₽'), findsNWidgets(2));
      expect(find.text('Номер телефона'), findsNothing);
      expect(find.text('+79990000000'), findsNothing);
      expect(find.text('Маршрут пассажира'), findsOneWidget);
    });

    final menuButton = find.byWidgetPredicate((w) => w is AppIcon && w.name == 'system_menu_dots');

    testWidgets('«Отлик»: «⋯» в шапке — то же меню поездки; действие перечитывает поездку', (tester) async {
      final adapter = await openResponse(tester, {'POST /trips/t1/close-intake': tripDetails(status: 'intake_closed')});
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();
      expect(find.text('Изменить количество мест'), findsOneWidget);
      expect(find.text('Редактировать'), findsOneWidget);
      await tester.tap(find.text('Завершить приём пассажиров'));
      await settle(tester);
      expect(adapter.log, contains('POST /trips/t1/close-intake'));
      expect(adapter.log.where((r) => r == 'GET /trips/t1'), hasLength(2));
      expect(find.text('Подтвердить бронь'), findsOneWidget);
    });

    testWidgets('«Отлик»: две иллюстрации дороги — 293×169 над маршрутом поездки и 293×85 над маршрутом пассажира', (tester) async {
      await openResponse(tester, {});
      final road = find.byType(RoadIllustration);
      expect(road, findsNWidgets(2));
      final pictures = find.descendant(of: road, matching: find.byType(SvgPicture));
      expect(tester.getSize(pictures.at(0)), const Size(293, 169));
      expect(tester.getSize(pictures.at(1)), const Size(293, 85));
      expect(tester.getTopLeft(road.at(1)).dy, greaterThan(tester.getBottomLeft(find.text('Маршрут пассажира')).dy - 1));
    });

    testWidgets('«Редактирование - Пассажиры есть», «Отлик»: кнопка «N остановок» по нажатию исчезает, на её месте остановка', (tester) async {
      await openResponse(tester, {});
      expect(find.byKey(const Key('route_stops_chip')), findsOneWidget);
      expect(find.text('Ростов, Улица Ленина, дом 5'), findsNothing);
      await tester.tap(find.byKey(const Key('route_stops_chip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('route_stops_chip')), findsNothing);
      expect(find.text('Ростов, Улица Ленина, дом 5'), findsOneWidget);
      });

    testWidgets('комментарий к посылке виден под маршрутом пассажира', (tester) async {
      await openResponse(tester, {}, comment: 'Коробка 5 кг');
      expect(find.text('Коробка 5 кг'), findsOneWidget);
      expect(find.text('Посылка M'), findsOneWidget);
    });

    testWidgets('без комментария строки комментария нет', (tester) async {
      await openResponse(tester, {});
      expect(find.text('Комментарий — Вид посылки'), findsNothing);
    });

    testWidgets('«Подтвердить бронь» шлёт confirm, снэкбар, список обновляется', (tester) async {
      final adapter = await openResponse(tester, {'POST /bookings/b1/confirm': booking(status: 'awaiting_payment')});
      await tester.tap(find.text('Подтвердить бронь'));
      await settle(tester);
      expect(adapter.log, contains('POST /bookings/b1/confirm'));
      expect(find.text('Бронь подтверждена'), findsOneWidget);
      expect(adapter.log.where((e) => e == 'GET /trips/t1/bookings').length, 2);
      expect(find.text('Заявок пока нет'), findsOneWidget);
    });

    testWidgets('«Отклонить бронь» шлёт reject и показывает снэкбар', (tester) async {
      final adapter = await openResponse(tester, {'POST /bookings/b1/reject': booking(status: 'rejected')});
      await tester.tap(find.text('Отклонить бронь'));
      await settle(tester);
      expect(adapter.log, contains('POST /bookings/b1/reject'));
      expect(find.text('Бронь отклонена'), findsOneWidget);
    });

    testWidgets('отказ сервера: текст по коду, экран остаётся', (tester) async {
      await openResponse(tester, {
        'POST /bookings/b1/confirm': (409, {'code': 'no_seats', 'message': 'нет мест'}),
      });
      await tester.tap(find.text('Подтвердить бронь'));
      await settle(tester);
      expect(find.text('Свободных мест не осталось.'), findsOneWidget);
      expect(find.text('Подтвердить бронь'), findsOneWidget);
    });
  });

  group('профиль пассажира («Профиль пассажира до принятия заявки», «Профиль пассажира после принятия заявки», «Профиль - Профиль пассажира», «Профиль - Профиль пассажира до оплаты»)', () {
    Map<String, Object?> profile({required String status, String? phone, String name = 'Анна П.'}) => {
          'GET /bookings/b1': booking(status: status),
          'GET /users/p1/public': userBrief(id: 'p1', name: name, phone: phone, tripsCount: 120, ratingValue: 4.8),
        };

    testWidgets('до принятия («Профиль пассажира до принятия заявки»): без телефона и маршрута, есть «Написать»', (tester) async {
      await open(tester, AppRoutes.driverBookingsPassenger, {'userId': 'p1', 'bookingId': 'b1'}, profile(status: 'requested'));
      expect(find.text('Профиль пассажира'), findsOneWidget);
      expect(find.text('Анна П.'), findsOneWidget);
      expect(find.text('4,8'), findsOneWidget);
      expect(find.text('120 поездок'), findsOneWidget);
      expect(find.text('Номер телефона'), findsNothing);
      expect(find.text('Маршрут пассажира'), findsNothing);
      expect(find.text('Написать'), findsOneWidget);
    });

    testWidgets('профиль пассажира без отзывов — «5, нет отзывов» и число поездок, если они есть', (tester) async {
      Map<String, Object?> noReviews(int trips) => {
            ...profile(status: 'requested'),
            'GET /users/p1/public': userBrief(id: 'p1', name: 'Анна П.', tripsCount: trips, ratingValue: 5, ratingCount: 0),
          };
      await open(tester, AppRoutes.driverBookingsPassenger, {'userId': 'p1', 'bookingId': 'b1'}, noReviews(7));
      expect(find.text('5, нет отзывов'), findsOneWidget);
      expect(find.text('7 поездок'), findsOneWidget);
    });

    testWidgets('профиль пассажира без отзывов и без поездок — только «5, нет отзывов»', (tester) async {
      await open(tester, AppRoutes.driverBookingsPassenger, {'userId': 'p1', 'bookingId': 'b1'}, {
        ...profile(status: 'requested'),
        'GET /users/p1/public': userBrief(id: 'p1', name: 'Анна П.', tripsCount: 0, ratingValue: 5, ratingCount: 0),
      });
      expect(find.text('5, нет отзывов'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^\d+ поезд')), findsNothing);
    });

    testWidgets('шапка как в кадре: стрелка «назад» зелёная, меню «⋯» нет', (tester) async {
      await open(tester, AppRoutes.driverBookingsPassenger, {'userId': 'p1', 'bookingId': 'b1'}, profile(status: 'requested'));
      final icons = tester.widgetList<AppIcon>(find.byType(AppIcon)).toList();
      final back = icons.singleWhere((i) => i.name == 'arrows_alt_arrow_left');
      expect(back.color, AppColors.accentPrimary);
      expect(icons.where((i) => i.name.contains('menu_dots')), isEmpty);
    });

    testWidgets('после принятия («Профиль пассажира после принятия заявки»): телефон и маршрут пассажира из брони, без иллюстрации дороги', (tester) async {
      await open(tester, AppRoutes.driverBookingsPassenger, {'userId': 'p1', 'bookingId': 'b1'},
          profile(status: 'awaiting_payment', phone: '+79000000011'));
      expect(find.text('Номер телефона'), findsOneWidget);
      // Номер группами, как в кадре «Профиль пассажира после принятия заявки» «+7 000 000 00 00».
      expect(find.text('+7 900 000 00 11'), findsOneWidget);
      expect(find.text('Маршрут пассажира'), findsOneWidget);
      expect(find.text('Точка посадки'), findsOneWidget);
      expect(find.text('Ярославль, Улица Солнечная, дом 1'), findsOneWidget);
      expect(find.text('Москва, Улица Лунная, дом 2'), findsOneWidget);
      expect(find.text('Написать'), findsOneWidget);
      expect(find.byType(RoadIllustration), findsNothing); // в «Профиль пассажира после принятия заявки» дороги нет
    });

    testWidgets('без брони, телефон известен («Профиль - Профиль пассажира»): без маршрута, «Написать в чат»', (tester) async {
      await open(tester, AppRoutes.driverBookingsPassenger, {'userId': 'p1'},
          {'GET /users/p1/public': userBrief(id: 'p1', phone: '+79000000011')});
      expect(find.text('+7 900 000 00 11'), findsOneWidget);
      expect(find.text('Маршрут пассажира'), findsNothing);
      expect(find.text('Написать в чат'), findsOneWidget);
    });

    testWidgets('без брони и без телефона («Профиль - Профиль пассажира до оплаты»): кнопки нет', (tester) async {
      await open(tester, AppRoutes.driverBookingsPassenger, {'userId': 'p1'}, {'GET /users/p1/public': userBrief(id: 'p1')});
      expect(find.text('Номер телефона'), findsNothing);
      expect(find.text('Написать'), findsNothing);
      expect(find.text('Написать в чат'), findsNothing);
    });

    testWidgets('«Написать» открывает «Чат появится позже»', (tester) async {
      final pushed = <(String, Object?)>[];
      await open(tester, AppRoutes.driverBookingsPassenger, {'userId': 'p1', 'bookingId': 'b1'}, profile(status: 'requested'),
          pushed: pushed);
      await tester.tap(find.text('Написать'));
      await tester.pumpAndSettle();
      expect(pushed.single, (AppRoutes.stub, 'Чат появится позже'));
    });
  });

  group('события водителя («Пришёл отклик», «Пассажир оплатил»)', () {
    testWidgets('«Новый отклик» ведёт на заявки поездки брони', (tester) async {
      final pushed = <(String, Object?)>[];
      await open(tester, AppRoutes.driverBookingsNewResponse, 'b1', {'GET /bookings/b1': booking()}, pushed: pushed);
      expect(find.text('Новый отклик'), findsOneWidget);
      expect(find.text('Пассажир хочет присоединиться к вашей поездке. Ожидается ваше решение.'), findsOneWidget);
      await tester.tap(find.text('Перейти к отклику'));
      await tester.pumpAndSettle();
      expect(pushed.single, (AppRoutes.driverBookings, 't1'));
    });

    testWidgets('«Пассажир оплатил поездку» ведёт к поездке брони', (tester) async {
      final pushed = <(String, Object?)>[];
      await open(tester, AppRoutes.driverBookingsPassengerPaid, {'bookingId': 'b1'}, {'GET /bookings/b1': booking(status: 'paid')},
          pushed: pushed);
      expect(find.text('Пассажир оплатил поездку'), findsOneWidget);
      await tester.tap(find.text('Перейти к поездке'));
      await tester.pumpAndSettle();
      expect(pushed.single, (AppRoutes.driverTripsDetails, 't1'));
    });

    testWidgets('окно — прозрачный маршрут: экран позади виден сквозь затемнение (как «Пришёл ответ», «Пришёл отказ»)', (tester) async {
      tallScreen(tester);
      final adapter = MockAdapter({'GET /bookings/b1': booking()});
      await tester.pumpWidget(testApp(
        session: makeSession(adapter),
        home: const Scaffold(body: Text('лента позади')),
        onGenerateRoute: onGenerateAppRoute,
      ));
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(AppRoutes.driverBookingsNewResponse, arguments: 'b1');
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.text('Новый отклик'), findsOneWidget);
      expect(find.text('лента позади'), findsOneWidget);
      // Фон окна прозрачный: ленту закрывает только затемнение.
      final scaffold = find.descendant(of: find.byType(DriverEventScreen), matching: find.byType(Scaffold));
      expect(tester.widget<Scaffold>(scaffold).backgroundColor, Colors.transparent);
    });

    test('маршруты окон «Пришёл отклик», «Пассажир оплатил» непрозрачны = false, обычные экраны — true', () {
      bool opaque(String name) =>
          (onGenerateAppRoute(RouteSettings(name: name, arguments: 'b1'))! as TransitionRoute<dynamic>).opaque;
      expect(opaque(AppRoutes.driverBookingsNewResponse), isFalse);
      expect(opaque(AppRoutes.driverBookingsPassengerPaid), isFalse);
      expect(opaque(AppRoutes.driverBookings), isTrue);
    });

    testWidgets('бронь не загрузилась — ошибка с повтором, а не пустое окно', (tester) async {
      await open(tester, AppRoutes.driverBookingsNewResponse, 'b1', {});
      expect(find.text('Обновить'), findsOneWidget);
      expect(find.text('Перейти к отклику'), findsNothing);
    });
  });
}
