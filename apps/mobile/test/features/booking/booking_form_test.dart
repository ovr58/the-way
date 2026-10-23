import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/app_routes.dart';
import 'package:the_way/src/features/booking/new/booking_form_screen.dart';
import 'package:the_way/src/features/booking/new/booking_new_args.dart';
import 'package:the_way/src/widgets/app_icon.dart';
import 'package:the_way/src/widgets/app_list_item.dart';
import 'package:the_way/src/widgets/app_switch.dart';
import 'package:the_way/src/widgets/road_illustration.dart';

import '../../support/fake_api.dart';

/// Сервер: детали поездки, итог = 1200 × места (+150 за услугу) и создание брони.
FakeServer _server({
  String bookingMode = 'standard',
  int seatsFree = 3,
  bool parcelOnlyAllowed = true,
  FakeReply? onCreate,
}) {
  final server = FakeServer();
  server.on(
    'GET /trips/t1',
    (_) => FakeReply(
      200,
      tripDetailsJson(
        bookingMode: bookingMode,
        seatsFree: seatsFree,
        parcelBookable: true,
        parcelOnlyAllowed: parcelOnlyAllowed,
      ),
    ),
  );
  server.on('GET /trips/t1/quote', (o) {
    final seats = int.parse('${o.queryParameters['seats']}');
    final extras = '${o.queryParameters['extras'] ?? ''}'.isEmpty ? 0 : 150;
    return FakeReply(200, {'segmentPrice': 1200, 'priceTotal': 1200 * seats + extras});
  });
  server.on(
    'POST /trips/t1/bookings',
    (_) =>
        onCreate ??
        FakeReply(
          201,
          bookingJson(status: bookingMode == 'instant' ? 'awaiting_payment' : 'requested'),
        ),
  );
  server.on('POST /bookings/b1/pay', (_) => FakeReply(200, bookingJson(status: 'paid')));
  return server;
}

Future<void> _open(
  WidgetTester tester,
  FakeServer server, {
  BookingFormMode mode = BookingFormMode.seat,
  Map<String, List<Object?>>? opened,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final session = fakeSession(server);
  await tester.pumpWidget(
    testApp(
      session,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const Key('sheet'),
            onPressed: () => showBookingSheet(context, BookingNewArgs(tripId: 't1', mode: mode)),
            child: const Text('sheet'),
          ),
        ),
      ),
      opened: opened,
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('sheet')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('заголовок шторки брони — «Бронирование места», а не «Откликнуться на заказ»', (tester) async {
    await _open(tester, _server());
    expect(find.text('Бронирование места'), findsOneWidget);
    expect(find.text('Откликнуться на заказ'), findsNothing);
  });

  testWidgets('«Бронирование»: над «Точка отправления» и над «Конечная точка» — иллюстрация дороги 284×164', (tester) async {
    await _open(tester, _server());
    final road = find.byType(RoadIllustration);
    expect(road, findsNWidgets(2));
    final pictures = find.descendant(of: road, matching: find.byType(SvgPicture));
    for (var i = 0; i < 2; i++) {
      expect(tester.getSize(pictures.at(i)), const Size(284, 164));
    }
    final pickupTitle = tester.getTopLeft(find.text('Точка отправления').first).dy;
    final dropoffTitle = tester.getTopLeft(find.text('Конечная точка').first).dy;
    final first = tester.getTopLeft(road.at(0)).dy;
    final second = tester.getTopLeft(road.at(1)).dy;
    expect(first, greaterThan(pickupTitle));
    expect(first, lessThan(dropoffTitle));
    expect(second, greaterThan(dropoffTitle));
  });

  // Кадр «Бронирование»: над маршрутом шторки посылки — коробка 252×188, а не дорога (тема road-or-box, принятое решение
  // 2026-10-22).
  testWidgets('«Бронирование»: бронь посылки — над маршрутом коробка 252×188', (tester) async {
    await _open(tester, _server(), mode: BookingFormMode.parcel);
    final road = find.byType(RoadIllustration);
    expect(road, findsOneWidget);
    final picture = find.descendant(of: road, matching: find.byType(SvgPicture));
    expect((tester.widget<SvgPicture>(picture).bytesLoader as SvgAssetLoader).assetName, 'assets/images/box.svg');
    expect(tester.getSize(picture).width, closeTo(251.579, 0.01));
    expect(tester.getSize(picture).height, closeTo(188.4, 0.01));
    expect(tester.getRect(road).bottom, lessThanOrEqualTo(tester.getTopLeft(find.byKey(const Key('route_stops_chip'))).dy));
  });

  testWidgets('бронь без мест: ответ no_seats — «Мест нет»', (tester) async {
    final server = _server(onCreate: const FakeReply(409, {'code': 'no_seats', 'message': 'x'}));
    await _open(tester, server);

    await tester.tap(find.byKey(const Key('booking_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Мест нет'), findsOneWidget);
    expect(server.of('POST /trips/t1/bookings'), hasLength(1));
  });

  testWidgets('бронь заблокированным (403 blocked): в шторке нет текста ошибки — отказ показывает экран блокировки',
      (tester) async {
    final server = _server(onCreate: const FakeReply(403, {'code': 'blocked', 'message': 'x'}));
    await _open(tester, server);

    await tester.tap(find.byKey(const Key('booking_submit')));
    await tester.pumpAndSettle();

    expect(server.of('POST /trips/t1/bookings'), hasLength(1));
    expect(find.text('Бронирование временно недоступно'), findsNothing);
    expect(find.text('Не удалось выполнить действие. Попробуйте ещё раз'), findsNothing);
  });

  testWidgets('смена числа мест запрашивает новый итог и показывает его', (tester) async {
    final server = _server();
    await _open(tester, server);

    expect(find.text('1\u00A0200 ₽'), findsOneWidget);
    expect(server.of('GET /trips/t1/quote').single.queryParameters['seats'], 1);

    await tester.tap(find.byKey(const Key('seats_plus')));
    await tester.pumpAndSettle();

    final quotes = server.of('GET /trips/t1/quote');
    expect(quotes, hasLength(2));
    expect(quotes.last.queryParameters['seats'], 2);
    expect(find.text('2\u00A0400 ₽'), findsOneWidget);
  });

  testWidgets('посадка не в начале — высадка любая после неё, и между остановками', (tester) async {
    final server = _server();
    await _open(tester, server);

    expect(find.byKey(const Key('dropoff_1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pickup_1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dropoff_1')), findsNothing);
    expect(find.byKey(const Key('dropoff_2')), findsOneWidget);
    expect(find.byKey(const Key('dropoff_3')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dropoff_2')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('booking_submit')));
    await tester.pumpAndSettle();
    final body = server.of('POST /trips/t1/bookings').single.data as Map;
    expect(body['fromIdx'], 1);
    expect(body['toIdx'], 2);
    expect(body['seats'], 1);
  });

  testWidgets('высадка не в конце — посадка любая до неё', (tester) async {
    final server = _server();
    await _open(tester, server);

    await tester.tap(find.byKey(const Key('dropoff_2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pickup_0')), findsOneWidget);
    expect(find.byKey(const Key('pickup_1')), findsOneWidget);
    expect(find.byKey(const Key('pickup_2')), findsNothing);

    await tester.tap(find.byKey(const Key('booking_submit')));
    await tester.pumpAndSettle();
    final body = server.of('POST /trips/t1/bookings').single.data as Map;
    expect(body['fromIdx'], 0);
    expect(body['toIdx'], 2);
  });

  testWidgets('посылка с «Без проезда»: seats 0, parcelOnly, от первой до последней остановки',
      (tester) async {
    final server = _server();
    await _open(tester, server, mode: BookingFormMode.parcel);

    await tester.tap(find.byKey(const Key('parcel_row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('size_S')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('parcel_only_switch')));
    await tester.pumpAndSettle();
    expect(tester.widget<AppSwitch>(find.byKey(const Key('parcel_only_switch'))).value, isTrue);

    await tester.tap(find.byKey(const Key('booking_submit')));
    await tester.pumpAndSettle();

    final body = server.of('POST /trips/t1/bookings').single.data as Map;
    expect(body['seats'], 0);
    expect(body['parcelOnly'], true);
    expect(body['fromIdx'], 0);
    expect(body['toIdx'], 3);
    expect(body['parcelSize'], 'S');
  });

  testWidgets('посылка: мест нет, но «Без проезда» запрещён — parcelOnly в теле не уходит', (tester) async {
    final server = _server(seatsFree: 0, parcelOnlyAllowed: false);
    await _open(tester, server, mode: BookingFormMode.parcel);

    expect(find.byKey(const Key('parcel_only_switch')), findsNothing);
    await tester.tap(find.byKey(const Key('parcel_row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('size_S')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking_submit')));
    await tester.pumpAndSettle();

    final body = server.of('POST /trips/t1/bookings').single.data as Map;
    expect(body['parcelOnly'], false);
  });

  testWidgets('доп. услуги («Бронирование», «Бронирование - С доп услугами»): у «Детского кресла» есть подсказка, как у багажа и животных',
      (tester) async {
    final server = _server();
    server.on('GET /trips/t1', (_) {
      final trip = tripDetailsJson();
      return FakeReply(200, {
        ...trip,
        'extrasPriced': [
          {'kind': 'child_seat', 'price': 100},
          ...(trip['extrasPriced'] as List<Object?>),
        ],
      });
    });
    await _open(tester, server);

    // Название (600) и подсказка (400, 50 %) — два текста «Детское кресло», как в кадрах.
    expect(find.text('Детское кресло'), findsNWidgets(2));
    expect(find.text('Большой чемодан'), findsOneWidget);
  });

  testWidgets('шторка размера посылки («Бронирование - С доп услугами»): название размера — токен текста', (tester) async {
    final server = _server();
    await _open(tester, server, mode: BookingFormMode.parcel);

    await tester.tap(find.byKey(const Key('parcel_row')));
    await tester.pumpAndSettle();

    // «Бронирование - С доп услугами»: название размера — #070c13.
    expect(tester.widget<Text>(find.text('Маленькая')).style?.color, const Color(0xFF070C13));
  });

  testWidgets('поездка instant: кнопка «Перейти к оплате», бронь тут же оплачивается',
      (tester) async {
    final server = _server(bookingMode: 'instant');
    final opened = <String, List<Object?>>{};
    await _open(tester, server, opened: opened);

    expect(find.text('Перейти к оплате'), findsOneWidget);
    expect(find.text('Отправить заявку'), findsNothing);

    await tester.tap(find.byKey(const Key('booking_submit')));
    await tester.pumpAndSettle();

    expect(server.of('POST /bookings/b1/pay'), hasLength(1));
    expect(opened[AppRoutes.bookingPaid], ['b1']);
  });

  testWidgets('стандартная поездка: кнопка «Отправить заявку», оплаты нет, шторка закрывается',
      (tester) async {
    final server = _server();
    await _open(tester, server);

    expect(find.text('Отправить заявку'), findsOneWidget);
    await tester.tap(find.byKey(const Key('booking_submit')));
    await tester.pumpAndSettle();

    expect(server.of('POST /bookings/b1/pay'), isEmpty);
    expect(find.byKey(const Key('booking_submit')), findsNothing);
    expect(find.byKey(const Key('sheet')), findsOneWidget);
  });

  testWidgets('мест нет: «Без проезда» включён и не выключается', (tester) async {
    await _open(tester, _server(seatsFree: 0), mode: BookingFormMode.parcel);
    final locked = tester.widget<AppSwitch>(find.byKey(const Key('parcel_only_switch')));
    expect(locked.value, isTrue);
    expect(locked.onChanged, isNull);
  });

  testWidgets('водитель не разрешил «Без проезда»: переключателя нет', (tester) async {
    await _open(tester, _server(parcelOnlyAllowed: false), mode: BookingFormMode.parcel);
    expect(find.byKey(const Key('parcel_only_switch')), findsNothing);
  });

  // Кадр «Бронирование - С доп услугами»: картинка `image 25` 38×75 в рамке 42×42 — одна машина из полосы трёх (S | M | L):
  // у каждого размера своя треть картинки.
  testWidgets('шторка размера посылки («Бронирование - С доп услугами»): в каждой строке одна машина своего размера, 38×75', (tester) async {
    final server = _server();
    server.on('GET /trips/t1', (_) {
      final trip = tripDetailsJson(parcelBookable: true);
      return FakeReply(200, {
        ...trip,
        'parcelSizes': ['S', 'M', 'L'],
        'extrasPriced': [
          ...(trip['extrasPriced']! as List),
          {'kind': 'parcel_l', 'price': 350},
        ],
      });
    });
    await _open(tester, server, mode: BookingFormMode.parcel);
    await tester.tap(find.byKey(const Key('parcel_row')));
    await tester.pumpAndSettle();

    Image image(String size) =>
        tester.widget<Image>(find.descendant(of: find.byKey(Key('size_$size')), matching: find.byType(Image)));
    expect(image('S').alignment, Alignment.centerLeft);
    expect(image('M').alignment, Alignment.center);
    expect(image('L').alignment, Alignment.centerRight);
    expect(tester.getSize(find.descendant(of: find.byKey(const Key('size_S')), matching: find.byType(Image))),
        const Size(38, 75));
  });

  // Кадр «поиск адреса»: шторка поиска адреса — без заголовка, поле «Введите адрес» с зелёной рамкой и
  // зелёной меткой слева, строки — бледная метка, адрес, город; выбор только из остановок.
  testWidgets('«поиск адреса»: больше 5 остановок — шторка поиска адреса без заголовка, фильтр и выбор', (tester) async {
    final server = _server();
    server.on('GET /trips/t1', (_) => FakeReply(200, tripDetailsJson(stops: 7)));
    await _open(tester, server);
    await tester.tap(find.byKey(const Key('pickup_field')));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const Key('stop_picker'));
    expect(sheet, findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Точка отправления')), findsNothing);
    final field = find.descendant(of: sheet, matching: find.byType(TextField));
    expect(tester.widget<TextField>(field).decoration?.hintText, 'Введите адрес');
    final pins = find.descendant(
      of: sheet,
      matching: find.byWidgetPredicate((w) => w is AppIcon && w.name == 'vuesax_bold_location'),
    );
    expect(tester.widget<AppIcon>(pins.first).color, const Color(0xFF1EB74D));
    expect(tester.widget<AppIcon>(pins.at(1)).color, const Color(0x800C0C0C));
    // Почти на весь экран: лист от верха безопасной зоны до низа.
    expect(tester.getRect(sheet).height, greaterThan(2000));

    await tester.enterText(field, 'Б-3');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppListItem, 'Город 2, Б-2'), findsNothing);
    await tester.tap(find.widgetWithText(AppListItem, 'Город 3, Б-3'));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(find.descendant(of: find.byKey(const Key('pickup_field')), matching: find.text('Город 3, Б-3')), findsOneWidget);
  });
}
