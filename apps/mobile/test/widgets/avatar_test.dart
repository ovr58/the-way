import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/widgets/app_icon.dart';
import 'package:the_way/src/widgets/avatar.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('без фото и с silhouette — серый круг с силуэтом вполовину размера', (tester) async {
    await tester.pumpWidget(_app(const Avatar(size: 96, silhouette: true)));
    final icon = tester.widget<AppIcon>(find.byType(AppIcon));
    expect(icon.name, 'users_user_rounded');
    expect(icon.size, 48);
    expect(tester.getSize(find.byType(Avatar)), const Size(96, 96));
  });

  testWidgets('без silhouette (карточки, детали — в кадрах заглушки нет) значка нет', (tester) async {
    await tester.pumpWidget(_app(const Avatar(size: 96)));
    expect(find.byType(AppIcon), findsNothing);
  });
}
