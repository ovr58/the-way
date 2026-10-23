import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/l10n/app_localizations.dart';
import 'package:the_way/src/features/driver_trips/list/driver_trip_card.dart';
import 'package:the_way/src/theme/app_theme.dart';
import 'package:the_way/src/widgets/avatar.dart';

Map<String, Object?> _stop(int idx, String address) =>
    {'idx': idx, 'cityId': idx + 1, 'cityName': 'Город $idx', 'address': address, 'shortAddress': address};

DriverTripCard _card({
  int requested = 0,
  int awaitingPayment = 0,
  int paid = 0,
  List<Map<String, Object?>> responders = const [],
  String status = 'active',
  Map<String, Object?>? from,
}) =>
    DriverTripCard.fromJson({
      'id': 't1',
      'number': 1231,
      'kind': 'ride',
      'from': from ?? _stop(0, 'Улица Солнечная, дом 12'),
      'to': _stop(1, 'Улица Лунная, дом 5'),
      'stopsCount': 0,
      'departsAt': '2026-05-16T09:00:00.000Z',
      'arrivesAt': '2026-05-16T12:00:00.000Z',
      'seatsFree': 2,
      'seatsTotal': 4,
      'parcelSeatsFree': 0,
      'parcelSeatsTotal': 0,
      'price': 600,
      'driver': {
        'id': 'd1',
        'name': 'Виктор О.',
        'rating': {'value': 4.5, 'count': 3},
        'tripsCount': 127,
      },
      'extras': <String>[],
      'parcelAllowed': false,
      'parcelSizes': <String>[],
      'duplicates': 1,
      'registrationOpen': true,
      'bookable': false,
      'parcelBookable': false,
      'effectiveStatus': status,
      'requested': requested,
      'awaitingPayment': awaitingPayment,
      'paid': paid,
      'parcels': 0,
      'responders': responders,
    });

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
  testWidgets('requested 1, paid 2, два responders: две аватарки, «+1», «3 отклика»', (tester) async {
    final trip = _card(requested: 1, paid: 2, responders: [
      {'id': 'p1'},
      {'id': 'p2'},
    ]);
    await tester.pumpWidget(_app(DriverTripCardView(trip: trip)));

    expect(find.byType(Avatar), findsNWidgets(2));
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('3 отклика'), findsOneWidget);
    expect(find.text('Заказ №1231'), findsOneWidget);
    expect(find.text('Завершен'), findsNothing);
  });

  testWidgets('без броней нет ни аватаров, ни надписи об откликах', (tester) async {
    await tester.pumpWidget(_app(DriverTripCardView(trip: _card())));

    expect(find.byType(Avatar), findsNothing);
    expect(find.textContaining('отклик'), findsNothing);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('все отклики показаны аватарами — кружка «+N» нет', (tester) async {
    final trip = _card(awaitingPayment: 2, responders: [
      {'id': 'p1'},
      {'id': 'p2'},
    ]);
    await tester.pumpWidget(_app(DriverTripCardView(trip: trip)));

    expect(find.byType(Avatar), findsNWidgets(2));
    expect(find.text('2 отклика'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('адрес на карточке — короткий (PN-2), полный не показывается', (tester) async {
    final from = {..._stop(0, 'Россия, Ярославская область, Ярославль, Фрунзенский, 150001, Портовая набережная 10'), 'shortAddress': 'Портовая набережная, 10'};
    await tester.pumpWidget(_app(DriverTripCardView(trip: _card(from: from))));
    expect(find.text('Город 0, Портовая набережная, 10'), findsOneWidget);
    expect(find.text('Россия, Ярославская область, Ярославль, Фрунзенский, 150001, Портовая набережная 10'), findsNothing);
  });

  testWidgets('completed — плашка «Завершен»', (tester) async {
    await tester.pumpWidget(_app(DriverTripCardView(trip: _card(status: 'completed'))));

    expect(find.text('Завершен'), findsOneWidget);
  });

  testWidgets('подписей пассажира («Место забронировано», «Найден водитель») на карточке нет', (tester) async {
    final trip = _card(requested: 1, paid: 2, responders: [
      {'id': 'p1'},
    ]);
    await tester.pumpWidget(_app(DriverTripCardView(trip: trip)));

    expect(find.text('Место забронировано'), findsNothing);
    expect(find.text('Посылка забронирована'), findsNothing);
    expect(find.text('Найден водитель'), findsNothing);
  });
}
