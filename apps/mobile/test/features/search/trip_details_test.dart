import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/app_routes.dart';
import 'package:the_way/src/features/booking/new/booking_new_args.dart';
import 'package:the_way/src/features/search/details/trip_details_screen.dart';
import 'package:the_way/src/widgets/app_icon.dart';
import 'package:the_way/src/widgets/app_header.dart';
import 'package:the_way/src/widgets/road_illustration.dart';

import '../../support/expand_checks.dart';
import '../../support/fake_api.dart';

Future<Map<String, List<Object?>>> _open(
  WidgetTester tester,
  Map<String, Object?> trip,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final server = FakeServer()..on('GET /trips/t1', (_) => FakeReply(200, trip));
  final opened = <String, List<Object?>>{};
  await tester.pumpWidget(testApp(fakeSession(server), const TripDetailsScreen(tripId: 't1'), opened: opened));
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  testWidgets('прибытие на следующий день: дата прибытия и время в пути', (tester) async {
    await _open(tester, {...tripDetailsJson(), 'departsAt': '2026-06-04T20:00:00Z', 'arrivesAt': '2026-06-05T04:00:00Z'});
    expect(find.text('Прибытие 5 июня, 07:00 · в пути 8 ч'), findsOneWidget);
  });

  testWidgets('прибытие в тот же день — строки прибытия нет, как в кадрах', (tester) async {
    await _open(tester, tripDetailsJson());
    expect(find.textContaining('в пути'), findsNothing);
  });

  testWidgets('«Детали поездки - Места есть»: иллюстрация дороги 293×169 вверху карточки маршрута, над первым адресом', (tester) async {
    await _open(tester, tripDetailsJson());
    final road = find.byType(RoadIllustration);
    expect(road, findsOneWidget);
    expect(tester.getSize(find.descendant(of: road, matching: find.byType(SvgPicture))), const Size(293, 169));
    final firstAddress = tester.getTopLeft(find.byKey(const Key('route_stops_chip'))).dy;
    expect(tester.getRect(road).bottom, lessThan(firstAddress));
  });

  testWidgets('«Детали поездки - Мест нет»: шапка «Поездка» без нижней линии', (tester) async {
    await _open(tester, tripDetailsJson());
    expect(tester.widget<AppHeader>(find.byType(AppHeader)).bordered, isFalse);
  });

  testWidgets('«Детали поездки - Места есть»: у водителя «★ 4,8 • N поездок» с серым кружком 6', (tester) async {
    await _open(tester, tripDetailsJson());
    final dot = find.byKey(const Key('rating_dot'));
    expect(dot, findsOneWidget);
    expect(tester.getSize(dot), const Size(6, 6));
  });

  testWidgets('есть места: «Забронировать место» и «Отправить посылку» открывают форму в своих режимах',
      (tester) async {
    await _open(tester, tripDetailsJson(parcelBookable: true));
    expect(find.text('Забронировать место'), findsOneWidget);
    expect(find.text('Отправить посылку'), findsOneWidget);
    expect(find.text('1 из 3'), findsNothing);
    expect(find.text('3 из 3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('details_parcel')));
    await tester.pumpAndSettle();
    // Шторка брони в режиме посылки: есть строка «Посылка», нет выбора мест.
    expect(find.byKey(const Key('parcel_row')), findsOneWidget);
    expect(find.byKey(const Key('seats_plus')), findsNothing);
  });

  // Пассажиру рядом с «Мест свободно N из M» счёт «занято из всего» у посылок читается наоборот; в кадрах
  // «Детали поездки - Мест нет», «Детали поездки - Места есть», «Детали поездки - Мест нет» у посылок только размеры. «S, M · N из M» — экраны водителя и брони.
  testWidgets('«Детали поездки - Мест нет»: посылки — только размеры «Посылка S, M», без счёта мест', (tester) async {
    await _open(tester, tripDetailsJson(parcelBookable: true));
    expect(find.text('Посылка S, M'), findsOneWidget);
    expect(find.textContaining('Посылки S, M'), findsNothing);
  });

  testWidgets('места кончились («Детали поездки - Мест нет»): «Мест нет» неактивна, брони нет', (tester) async {
    await _open(tester, tripDetailsJson(seatsFree: 0, bookable: false));
    expect(find.text('Мест нет'), findsOneWidget);
    expect(find.text('Забронировать место'), findsNothing);
    expect(find.text('0 из 3'), findsOneWidget);
  });

  testWidgets('поездка-дубль без регистрации: кнопки брони нет', (tester) async {
    await _open(tester, tripDetailsJson(bookable: false));
    expect(find.text('Забронировать место'), findsNothing);
    expect(find.text('Мест нет'), findsNothing);
  });

  testWidgets('своя бронь («Детали поездки - Бронь есть»): ряд «Отменить бронь» | «Написать водителю» 50/50, «Написать» → заглушка чата',
      (tester) async {
    final opened = await _open(tester, tripDetailsJson(myBooking: bookingJson()));
    expect(find.text('Забронировать место'), findsNothing);
    final cancel = find.text('Отменить бронь');
    final write = find.text('Написать водителю');
    expect(cancel, findsOneWidget);
    expect(tester.getCenter(cancel).dy, tester.getCenter(write).dy);
    expect(tester.getCenter(cancel).dx, lessThan(tester.getCenter(write).dx));
    expect(
      tester.getSize(find.byKey(const Key('details_cancel'))).width,
      tester.getSize(find.byKey(const Key('details_chat'))).width,
    );

    await tester.tap(write);
    await tester.pumpAndSettle();
    expect(opened[AppRoutes.stub], ['Чат появится позже']);
  });

  testWidgets('своя бронь отменена: кнопки «Отменить бронь» нет, «Написать водителю» — как раньше', (tester) async {
    await _open(tester, tripDetailsJson(myBooking: bookingJson(status: 'cancelled')));
    expect(find.text('Отменить бронь'), findsNothing);
    expect(find.text('Написать водителю'), findsOneWidget);
  });

  testWidgets('«Отменить бронь» («Детали поездки - Бронь есть») открывает окно отмены; отмена заявки перечитывает поездку', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = FakeServer()
      ..on('GET /trips/t1', (_) => FakeReply(200, tripDetailsJson(myBooking: bookingJson())))
      ..on('GET /bookings/b1/cancel-preview',
          (_) => const FakeReply(200, {'cancellationsLast30': 0, 'willBlock': false, 'refundAmount': null}))
      ..on('POST /bookings/b1/cancel',
          (_) => const FakeReply(200, {'status': 'cancelled', 'cancellationsLast30': 0, 'blockedUntil': null}));
    await tester.pumpWidget(testApp(fakeSession(server), const TripDetailsScreen(tripId: 't1')));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Отменить бронь'));
    await tester.pumpAndSettle();
    expect(find.text('Отменить заявку?'), findsOneWidget);
    await tester.tap(find.text('Отменить заявку'));
    await tester.pumpAndSettle();

    expect(server.of('POST /bookings/b1/cancel'), hasLength(1));
    expect(server.of('GET /trips/t1'), hasLength(2));
  });

  testWidgets('стрелка у водителя ведёт в профиль водителя', (tester) async {
    final opened = await _open(tester, tripDetailsJson());

    await tester.tap(find.byKey(const Key('details_driver_chat')));
    await tester.pumpAndSettle();

    expect(opened[AppRoutes.searchDriver], ['d1']);
    expect(opened[AppRoutes.stub], isNull);
  });

  testWidgets('остановки и цены по отрезкам раскрываются кнопками', (tester) async {
    await _open(tester, tripDetailsJson());
    expect(find.text('Город 1, Б-1'), findsNothing);
    expect(find.text('Город 0, А-0 - Город 1, Б-1'), findsNothing);

    await tester.tap(find.byKey(const Key('route_stops_chip')));
    await tester.tap(find.byKey(const Key('details_prices_chip')));
    await tester.pumpAndSettle();

    expect(find.text('Город 1, Б-1'), findsOneWidget);
    expect(find.text('Город 2, Б-2'), findsOneWidget);
    // Участки соседних точек.
    expect(find.text('Город 0, А-0 - Город 1, Б-1'), findsOneWidget);
    expect(find.text('Город 1, Б-1 - Город 2, Б-2'), findsOneWidget);
    expect(find.text('Город 2, Б-2 - Город 3, Я-3'), findsOneWidget);
    // цена участка — тем же форматом, что «Стоимость поездки»: пробел перед «₽».
    expect(find.text('400₽'), findsNothing);
    expect(find.text('400 ₽'), findsAtLeastNWidgets(3));
  });

  testWidgets('«Детали поездки - Места есть»: значок машины перед моделью авто, стрелки в чипах (значки рисуются)', (tester) async {
    await _open(tester, tripDetailsJson());
    final names = tester.widgetList<AppIcon>(find.byType(AppIcon)).map((i) => i.name).toList();
    expect(names, containsAll(['system_car', 'arrows_alt_arrow_down']));
    final car = find.ancestor(of: find.byWidgetPredicate((w) => w is AppIcon && w.name == 'system_car'), matching: find.byType(Row)).first;
    expect(find.descendant(of: car, matching: find.textContaining('Camry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('details_prices_chip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('details_prices_collapse')), findsOneWidget);
  });

  testWidgets('«Смотреть стоимость» — та же анимация, что у остановок (350 мс, круг со стрелкой вверх)', (tester) async {
    await _open(tester, tripDetailsJson());
    await expectExpandCycle(
      tester,
      chip: const Key('details_prices_chip'),
      collapse: const Key('details_prices_collapse'),
      item: find.text('Город 0, А-0 - Город 1, Б-1'),
    );
  });

  testWidgets('после формы брони: «Заявка отправлена»', (tester) async {
    await _open(tester, tripDetailsJson());
    await tester.tap(find.byKey(const Key('details_book')));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byKey(const Key('booking_submit')))).pop(const BookingOutcome.requested());
    await tester.pumpAndSettle();

    expect(find.text('Заявка отправлена'), findsOneWidget);
  });

  testWidgets('после формы брони с ошибкой оплаты — текст по коду, а не «Заявка отправлена»', (tester) async {
    await _open(tester, tripDetailsJson());
    await tester.tap(find.byKey(const Key('details_book')));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byKey(const Key('booking_submit')))).pop(const BookingOutcome.payFailed('no_seats'));
    await tester.pumpAndSettle();

    expect(find.text('Мест нет'), findsOneWidget);
    expect(find.text('Заявка отправлена'), findsNothing);
  });

  /// Сквозной путь: детали → шторка → отправка → снэкбар на деталях (результат шторки доходит).
  Future<void> bookThrough(WidgetTester tester, {required String mode, FakeReply? payReply}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = FakeServer()
      ..on('GET /trips/t1', (_) => FakeReply(200, tripDetailsJson(bookingMode: mode)))
      ..on('GET /trips/t1/quote', (_) => const FakeReply(200, {'segmentPrice': 1200, 'priceTotal': 1200}))
      ..on(
        'POST /trips/t1/bookings',
        (_) => FakeReply(201, bookingJson(status: mode == 'instant' ? 'awaiting_payment' : 'requested')),
      )
      ..on('POST /bookings/b1/pay', (_) => payReply ?? FakeReply(200, bookingJson(status: 'paid')));
    await tester.pumpWidget(testApp(fakeSession(server), const TripDetailsScreen(tripId: 't1')));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('details_book')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking_submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('сквозной путь: отправка заявки в шторке → снэкбар «Заявка отправлена» на деталях',
      (tester) async {
    await bookThrough(tester, mode: 'standard');

    expect(find.byKey(const Key('booking_submit')), findsNothing);
    expect(find.text('Заявка отправлена'), findsOneWidget);
  });

  testWidgets('сквозной путь: ошибка оплаты в шторке → снэкбар по коду на деталях', (tester) async {
    await bookThrough(
      tester,
      mode: 'instant',
      payReply: const FakeReply(409, {'code': 'no_seats', 'message': 'x'}),
    );

    expect(find.byKey(const Key('booking_submit')), findsNothing);
    expect(find.text('Мест нет'), findsOneWidget);
    expect(find.text('Заявка отправлена'), findsNothing);
  });
}
