import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/widgets/parcel_size_image.dart';

/// Картинка размера посылки (`image 25` кадров «Новый заказ - Выбор веса посылки», «Бронирование - С доп услугами»): белая рамка 42×42, в ней 38×75 —
/// одна машина из полосы трёх (S | M | L), у каждого размера своя треть.
void main() {
  Widget app(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  Image image(WidgetTester tester) => tester.widget<Image>(find.byType(Image));

  for (final (size, alignment) in [
    (ParcelSize.s, Alignment.centerLeft),
    (ParcelSize.m, Alignment.center),
    (ParcelSize.l, Alignment.centerRight),
  ]) {
    testWidgets('${size.json}: рамка 42×42, картинка 38×75, своя треть полосы', (tester) async {
      await tester.pumpWidget(app(ParcelSizeImage(size: size)));
      expect(tester.getSize(find.byType(ParcelSizeImage)), const Size(42, 42));
      expect(tester.getSize(find.byType(Image)), const Size(38, 75));
      expect(image(tester).alignment, alignment);
      expect((image(tester).image as AssetImage).assetName, 'assets/images/parcel_size.webp');
    });
  }
}
