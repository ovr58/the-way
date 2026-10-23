import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/widgets/road_illustration.dart';

import '../screens/world.dart' as world;

/// Картинка над маршрутом по сути заказа (тема road-or-box, принятое решение 2026-10-22): коробка —
/// где везут только посылку (поездка типа «посылка», бронь без пассажира, шторка посылки «Бронирование»); дорога —
/// где едет пассажир; «место + посылка» — дорога того же размера и коробка поверх в 1/3 её ширины,
/// в правом верхнем углу. Коробка — `assets/images/box.svg` (Penpot «Бронирование», 252×188).
void main() {
  Booking booking({bool parcelOnly = false, String parcelSize = 'none', int seats = 1}) =>
      Booking.fromJson(world.booking(parcelOnly: parcelOnly, parcelSize: parcelSize, seats: seats));

  test('правило: поездка-посылка — коробка, поездка с местами — дорога', () {
    expect(TripArt.ofTrip(TripKind.parcel), TripArt.box);
    expect(TripArt.ofTrip(TripKind.ride), TripArt.road);
  });

  test('правило: бронь без пассажира — коробка, место + посылка — вместе, только место — дорога', () {
    expect(TripArt.ofBooking(booking(parcelOnly: true, parcelSize: 'S', seats: 0)), TripArt.box);
    expect(TripArt.ofBooking(booking(parcelSize: 'M')), TripArt.roadWithBox);
    expect(TripArt.ofBooking(booking()), TripArt.road);
  });

  Widget app(Widget child) => MaterialApp(home: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)));

  List<String> assets(WidgetTester tester) => tester
      .widgetList<SvgPicture>(find.byType(SvgPicture))
      .map((p) => (p.bytesLoader as SvgAssetLoader).assetName)
      .toList();

  testWidgets('коробка — одна, 252×188, как в «Бронирование»', (tester) async {
    await tester.pumpWidget(app(const RoadIllustration(width: 284, height: 164, art: TripArt.box)));
    expect(assets(tester), ['assets/images/box.svg']);
    // Группа кадра 251.579×188.4 (в frame-spec округлена до 252×188).
    final size = tester.getSize(find.byType(SvgPicture));
    expect(size.width, closeTo(251.579, 0.01));
    expect(size.height, closeTo(188.4, 0.01));
  });

  // «Коробку отцентровать» — принятое решение сверх кадра (в «Бронирование» коробка слева).
  testWidgets('одна коробка — по центру поля по горизонтали, сверху («Бронирование»)', (tester) async {
    await tester.pumpWidget(app(const SizedBox(width: 311, child: RoadIllustration(width: 284, height: 164, art: TripArt.box))));
    final box = tester.getRect(find.byType(SvgPicture));
    expect(box.center.dx, closeTo(311 / 2, 0.01));
    expect(box.top, 0);
  });

  testWidgets('низкое поле (85, карточка брони у водителя): коробка вписана в высоту поля, по центру', (tester) async {
    await tester.pumpWidget(app(const SizedBox(width: 311, child: RoadIllustration(height: 85, art: TripArt.box))));
    final box = tester.getRect(find.byType(SvgPicture));
    expect(box.height, closeTo(85, 0.01));
    expect(box.width, closeTo(85 * 251.579 / 188.4, 0.01));
    expect(box.center.dx, closeTo(311 / 2, 0.01));
  });

  testWidgets('место + посылка: дорога того же размера, коробка 1/3 её ширины в правом верхнем углу', (tester) async {
    await tester.pumpWidget(app(const RoadIllustration(art: TripArt.roadWithBox)));
    expect(assets(tester), ['assets/images/road.svg', 'assets/images/box.svg']);
    final road = tester.getRect(find.byType(SvgPicture).first);
    final box = tester.getRect(find.byType(SvgPicture).last);
    expect(road.size, const Size(293, 169));
    expect(box.width, closeTo(293 / 3, 0.01));
    expect(box.height, closeTo(293 / 3 * 188.4 / 251.579, 0.01));
    expect(box.topRight, road.topRight);
  });

  testWidgets('по умолчанию — только дорога', (tester) async {
    await tester.pumpWidget(app(const RoadIllustration()));
    expect(assets(tester), ['assets/images/road.svg']);
  });
}
