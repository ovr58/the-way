import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/l10n/app_localizations.dart';
import 'package:the_way/src/features/booking/new/stop_picker_sheet.dart';
import 'package:the_way/src/features/search/data/search_filter.dart';
import 'package:the_way/src/features/search/filter/location_service.dart';
import 'package:the_way/src/widgets/app_icon.dart';
import 'package:the_way/src/widgets/app_list_item.dart';

/// Положение телефона без системного диалога: [coords] — разрешение дано, `null` — нет.
class _Location implements LocationService {
  _Location(this.coords);

  final Coords? coords;

  @override
  Future<Coords?> ifGranted() async => coords;

  @override
  Future<Coords?> request() async => fail('шторка адреса не просит разрешение');
}

/// Ярославль — Ростов — Москва по трассе М-8: остановки с координатами из подсказки Mapbox.
const _stops = [
  Stop(idx: 0, cityId: 1, cityName: 'Ярославль', address: 'Улица Солнечная, дом 1', shortAddress: '', lat: 57.6261, lng: 39.8845),
  Stop(idx: 1, cityId: 2, cityName: 'Ростов', address: 'Улица Ленина, дом 5', shortAddress: '', lat: 57.1859, lng: 39.4144),
  Stop(idx: 2, cityId: 3, cityName: 'Москва', address: 'Проспект Мира, дом 10', shortAddress: '', lat: 55.7558, lng: 37.6173),
];

/// Принятое решение («поиск адреса»): первой строкой шторки выбора адреса —
/// «Ближайшая ко мне»: остановка поездки, ближайшая к текущему положению; нет разрешения или
/// положения — строки нет.
void main() {
  Future<List<int?>> open(WidgetTester tester, LocationService location, {List<Stop> stops = _stops}) async {
    final picked = <int?>[];
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked.add(await showStopPicker(context, stops: stops, location: location)),
          child: const Text('открыть'),
        ),
      ),
    ));
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('положение известно: первая строка «Ближайшая ко мне» со значком метки выбирает ближайшую остановку', (tester) async {
    // Ростов, вокзал: ближе всех «Улица Ленина, дом 5».
    final picked = await open(tester, _Location(const Coords(57.1950, 39.4170)));
    final rows = find.byType(AppListItem);
    expect(tester.widget<AppListItem>(rows.first).title, 'Ближайшая ко мне');
    expect(tester.widget<AppListItem>(rows.first).subtitle, isNull);
    final pin = tester.widget<AppIcon>(find.descendant(of: rows.first, matching: find.byType(AppIcon)));
    expect(pin.name, 'vuesax_bold_location');
    expect(pin.color, const Color(0x800C0C0C));
    expect(rows, findsNWidgets(4));

    await tester.tap(rows.first);
    await tester.pumpAndSettle();
    expect(picked, [1]);
  });

  testWidgets('город не повторяется второй строкой под адресом, где он уже есть', (tester) async {
    await open(tester, _Location(null), stops: const [
      Stop(idx: 0, cityId: 7, cityName: 'Тутаев', address: 'Тутаев, Ярославская область', shortAddress: ''),
      Stop(idx: 1, cityId: 2, cityName: 'Ростов', address: 'Улица Ленина, дом 5', shortAddress: ''),
    ]);
    final rows = tester.widgetList<AppListItem>(find.byType(AppListItem)).toList();
    expect(rows.map((r) => r.title), ['Тутаев, Ярославская область', 'Ростов, Улица Ленина, дом 5']);
    expect(rows.map((r) => r.subtitle), [null, null]);
    expect(find.text('Тутаев'), findsNothing);
  });

  testWidgets('нет разрешения или положения — строки «Ближайшая ко мне» нет', (tester) async {
    await open(tester, _Location(null));
    expect(find.text('Ближайшая ко мне'), findsNothing);
    expect(find.byType(AppListItem), findsNWidgets(3));
  });

  testWidgets('у остановок нет координат — строки нет', (tester) async {
    await open(tester, _Location(const Coords(57.1950, 39.4170)), stops: [
      for (final s in _stops)
        Stop(idx: s.idx, cityId: s.cityId, cityName: s.cityName, address: s.address, shortAddress: s.shortAddress),
    ]);
    expect(find.text('Ближайшая ко мне'), findsNothing);
  });

  testWidgets('набран текст поиска — строки нет, только найденные остановки', (tester) async {
    await open(tester, _Location(const Coords(57.1950, 39.4170)));
    await tester.enterText(find.byType(TextField), 'Мира');
    await tester.pumpAndSettle();
    expect(find.text('Ближайшая ко мне'), findsNothing);
    expect(find.byType(AppListItem), findsOneWidget);
  });
}
