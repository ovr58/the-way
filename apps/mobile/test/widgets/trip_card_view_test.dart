import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:the_way/l10n/app_localizations.dart';
import 'package:the_way/src/theme/app_colors.dart';
import 'package:the_way/src/theme/app_theme.dart';
import 'package:the_way/src/widgets/app_icon.dart';
import 'package:the_way/src/widgets/rating_line.dart';
import 'package:the_way/src/widgets/trip_card_view.dart';

Stop _stop(int idx, String address) =>
    Stop(idx: idx, cityId: idx + 1, cityName: 'Город $idx', address: address, shortAddress: address);

TripCard _trip({
  int stopsCount = 0,
  bool registrationOpen = false,
  int duplicates = 1,
  int seatsFree = 3,
  bool bookable = true,
  Rating rating = const Rating(value: 4.5, count: 2),
  TripBadge? badge,
  double? distanceKm,
  Stop? from,
  List<CarriedParcelSize> parcelSizes = const [],
  DateTime? arrivesAt,
}) =>
    TripCard(
      id: 't1',
      number: 7,
      kind: TripKind.ride,
      from: from ?? _stop(0, 'Улица Солнечная, дом 1'),
      to: _stop(1, 'Улица Лунная, дом 2'),
      stopsCount: stopsCount,
      departsAt: DateTime.utc(2026, 5, 15, 6),
      arrivesAt: arrivesAt ?? DateTime.utc(2026, 5, 15, 15),
      seatsFree: seatsFree,
      seatsTotal: 4,
      parcelSeatsFree: parcelSizes.isEmpty ? 0 : 1,
      parcelSeatsTotal: parcelSizes.isEmpty ? 0 : 3,
      price: 1800,
      distanceKm: distanceKm,
      badge: badge,
      driver: UserBrief(id: 'd1', name: 'Виктор О.', rating: rating, tripsCount: 127),
      extras: const [],
      parcelAllowed: parcelSizes.isNotEmpty,
      parcelSizes: parcelSizes,
      duplicates: duplicates,
      registrationOpen: registrationOpen,
      bookable: bookable,
      parcelBookable: false,
      effectiveStatus: TripStatus.active,
    );

Widget _app(Widget child) => MaterialApp(
      theme: buildTheme(),
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('прибытие на следующий день', () {
    // Выезд 15 мая 09:00 по Москве.
    final departs = DateTime.utc(2026, 5, 15, 6);
    setUpAll(() => initializeDateFormatting('ru'));

    test('время прибытия: в тот же день — как есть, на следующий — «+1»', () {
      expect(formatArrival(departs, DateTime.utc(2026, 5, 15, 15)), '18:00');
      expect(formatArrival(departs, DateTime.utc(2026, 5, 16, 4)), '07:00 +1');
      // 23:30 → 00:30 по Москве — уже следующий день, хотя в UTC тот же.
      expect(formatArrival(DateTime.utc(2026, 5, 15, 20, 30), DateTime.utc(2026, 5, 15, 21, 30)), '00:30 +1');
    });

    test('время в пути — часы и минуты', () {
      final l10n = lookupAppLocalizations(const Locale('ru'));
      expect(travelTime(l10n, departs, DateTime.utc(2026, 5, 16, 5)), 'в пути 23 ч');
      expect(travelTime(l10n, departs, DateTime.utc(2026, 5, 15, 8, 30)), 'в пути 2 ч 30 мин');
      expect(travelTime(l10n, departs, DateTime.utc(2026, 5, 15, 6, 45)), 'в пути 45 мин');
    });

    testWidgets('карточка ленты: «Прибытие ~07:00 +1»', (tester) async {
      await tester.pumpWidget(_app(TripCardView(trip: _trip(arrivesAt: DateTime.utc(2026, 5, 16, 4)))));
      expect(find.text('Прибытие ~07:00 +1'), findsOneWidget);
    });
  });

  /// Значки строки по порядку слева направо.
  List<String> icons(WidgetTester tester, Finder within) => tester
      .widgetList<AppIcon>(find.descendant(of: within, matching: find.byType(AppIcon)))
      .map((i) => i.name)
      .toList();

  testWidgets('рейтинг без отзывов («Базовые экраны - Поездки есть»): жёлтая звезда, затем «5, нет отзывов»', (tester) async {
    await tester.pumpWidget(_app(const RatingLine(rating: Rating(value: 5, count: 0), tripsCount: 0)));
    expect(find.text('5, нет отзывов'), findsOneWidget);
    final star = tester.widget<AppIcon>(find.byType(AppIcon));
    expect(star.name, 'system_star');
    expect(star.color, AppColors.accentWarning);
    expect(tester.getTopLeft(find.byType(AppIcon)).dx, lessThan(tester.getTopLeft(find.text('5, нет отзывов')).dx));
  });

  testWidgets('рейтинг с отзывами («Базовые экраны - Поездки есть»): звезда слева, число с запятой, число поездок', (tester) async {
    await tester.pumpWidget(_app(const RatingLine(rating: Rating(value: 4.5, count: 2), tripsCount: 127)));
    expect(find.text('4,5'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(AppIcon)).dx, lessThan(tester.getTopLeft(find.text('4,5')).dx));
    expect(find.text('127 поездок'), findsOneWidget);
    expect(find.textContaining('нет отзывов'), findsNothing);
  });

  testWidgets('карточка ленты без отзывов у водителя с поездками — «5, нет отзывов • 127 поездок»', (tester) async {
    await tester.pumpWidget(_app(TripCardView(trip: _trip(rating: const Rating(value: 5, count: 0)))));
    expect(find.text('5, нет отзывов'), findsOneWidget);
    expect(find.text('127 поездок'), findsOneWidget);
  });

  testWidgets('карточка ленты с отзывами: числа поездок нет («Базовые экраны - Поездки есть»)', (tester) async {
    await tester.pumpWidget(_app(TripCardView(trip: _trip())));
    expect(find.text('127 поездок'), findsNothing);
  });

  testWidgets('регистрация открыта и дубли: зелёная надпись', (tester) async {
    await tester.pumpWidget(_app(TripCardView(trip: _trip(registrationOpen: true, duplicates: 2))));
    final text = tester.widget<Text>(find.text('Идёт регистрация пассажиров'));
    expect(text.style?.color, AppColors.accentPrimary);
  });

  testWidgets('регистрация открыта без дублей: надписи нет', (tester) async {
    await tester.pumpWidget(_app(TripCardView(trip: _trip(registrationOpen: true))));
    expect(find.text('Идёт регистрация пассажиров'), findsNothing);
  });

  testWidgets('на карточке ленты нет кнопок брони', (tester) async {
    await tester.pumpWidget(_app(TripCardView(trip: _trip(registrationOpen: true, duplicates: 2))));
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text('Забронировать место'), findsNothing);
    expect(find.text('Отправить посылку'), findsNothing);
  });

  testWidgets('остановки: 2 → «2 остановки», 0 → надписи нет', (tester) async {
    await tester.pumpWidget(_app(TripCardView(trip: _trip(stopsCount: 2))));
    expect(find.text('2 остановки'), findsOneWidget);
    await tester.pumpWidget(_app(TripCardView(trip: _trip())));
    expect(find.textContaining(RegExp('остановк|остановок')), findsNothing);
  });

  testWidgets('плашка «Топ» справа от имени: звезда, обводка accentPrimary', (tester) async {
    await tester.pumpWidget(_app(TripCardView(trip: _trip(badge: TripBadge.top))));
    expect(find.text('Топ'), findsOneWidget);
    expect(find.text('Ближайший'), findsNothing);
    final chip = find.ancestor(of: find.text('Топ'), matching: find.byType(Container)).first;
    expect(icons(tester, chip), ['system_star']);
    final border = (tester.widget<Container>(chip).decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, AppColors.accentPrimary);
    expect(tester.getTopLeft(find.text('Топ')).dx, greaterThan(tester.getTopRight(find.text('Виктор О.')).dx));
  });

  testWidgets('плашка «Ближайший»: значок часов; без плашки — ни одной', (tester) async {
    await tester.pumpWidget(_app(TripCardView(trip: _trip(badge: TripBadge.nearest, distanceKm: 3.2))));
    expect(find.text('Ближайший'), findsOneWidget);
    final chip = find.ancestor(of: find.text('Ближайший'), matching: find.byType(Container)).first;
    expect(icons(tester, chip), ['time_clock_square']);
    await tester.pumpWidget(_app(TripCardView(trip: _trip())));
    expect(find.text('Топ'), findsNothing);
    expect(find.text('Ближайший'), findsNothing);
  });

  testWidgets('строка рейтинга карточки («Базовые экраны - Поездки есть»): «★ 4,5», справа «📍 3.2 км»', (tester) async {
    await tester.pumpWidget(_app(TripCardView(trip: _trip(distanceKm: 3.2))));
    expect(find.text('4,5'), findsOneWidget);
    expect(find.text('3.2 км'), findsOneWidget);
    expect(tester.getTopLeft(find.text('3.2 км')).dx, greaterThan(tester.getTopLeft(find.text('4,5')).dx));
  });

  testWidgets('адрес на карточке — короткий (PN-2), полный не показывается', (tester) async {
    const from = Stop(idx: 0, cityId: 1, cityName: 'Ярославль', address: 'Россия, Ярославская область, Ярославль, Фрунзенский, 150001, Портовая набережная 10', shortAddress: 'Портовая набережная, 10');
    await tester.pumpWidget(_app(TripCardView(trip: _trip(from: from))));
    expect(find.text('Ярославль, Портовая набережная, 10'), findsOneWidget);
    expect(find.text('Россия, Ярославская область, Ярославль, Фрунзенский, 150001, Портовая набережная 10'), findsNothing);
  });

  testWidgets('мест нет: «Мест нет»', (tester) async {
    await tester.pumpWidget(_app(TripCardView(trip: _trip(seatsFree: 0, bookable: false))));
    expect(find.text('Мест нет'), findsOneWidget);
  });

  // Принятое решение («Базовые экраны - Поездки есть»): у посылок на карточке ленты — только размеры,
  // как в деталях поездки (кадр «Детали поездки - Места есть» «Посылка S, M»), без счёта «· 2 из 3».
  testWidgets('посылки на карточке ленты: «Посылка S, M» без счёта мест', (tester) async {
    await tester.pumpWidget(_app(TripCardView(trip: _trip(parcelSizes: const [CarriedParcelSize.s, CarriedParcelSize.m]))));
    expect(find.text('Посылка S, M'), findsOneWidget);
    expect(find.textContaining('из 3'), findsNothing);
  });
}
