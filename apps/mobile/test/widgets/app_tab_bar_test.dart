import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/l10n/app_localizations.dart';
import 'package:the_way/src/theme/app_colors.dart';
import 'package:the_way/src/theme/app_theme.dart';
import 'package:the_way/src/widgets/app_tab_bar.dart';

Widget _app({required VoidCallback onCreate, ValueChanged<int>? onTap}) => MaterialApp(
      theme: buildTheme(),
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppTabScaffold(
        body: const SizedBox.expand(),
        currentIndex: 0,
        onTap: onTap ?? (_) {},
        onCreate: onCreate,
      ),
    );

void main() {
  // Кадр «Базовые экраны - Поездки есть»: зелёная «+» 48×48, радиус 12, ободок 3 цвета фона экрана, верх кнопки на 8 выше верха панели.
  testWidgets('«+» приподнята на 8 над панелью, 48×48, в ободке цвета фона («Базовые экраны - Поездки есть»)', (tester) async {
    await tester.pumpWidget(_app(onCreate: () {}));
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byType(AppTabBar));
    final button = tester.getRect(find.byKey(const Key('tab_create')));
    expect(button.size, const Size(48, 48));
    expect(bar.top - button.top, 8);
    expect(button.center.dx, closeTo(bar.center.dx, 0.5));
    final material = tester.widget<Material>(find.byKey(const Key('tab_create')));
    expect(material.color, AppColors.accentPrimary);
    final shape = material.shape! as RoundedRectangleBorder;
    expect(shape.side.color, AppColors.bgScreen);
    expect(shape.side.width, 3);
    expect(shape.borderRadius, BorderRadius.circular(12));
  });

  // Кадр «Базовые экраны - Поездки есть»: «Tabs» высотой 48 (без системного отступа снизу), зона нажатия вкладки — вся высота панели.
  testWidgets('высота панели 48, вкладка нажимается по всей высоте', (tester) async {
    int? tapped;
    await tester.pumpWidget(_app(onCreate: () {}, onTap: (i) => tapped = i));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AppTabBar)).height, 48);
    final bar = tester.getRect(find.byType(AppTabBar));
    final tab = tester.getRect(find.ancestor(of: find.text('Чаты'), matching: find.byType(InkWell)).first);
    expect(tab.height, 48);
    await tester.tapAt(Offset(tab.center.dx, bar.top + 2));
    expect(tapped, 2);
  });

  testWidgets('нажатие на выступающую над панелью часть «+» вызывает onCreate', (tester) async {
    var created = 0;
    await tester.pumpWidget(_app(onCreate: () => created++));
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byType(AppTabBar));
    final x = tester.getRect(find.byKey(const Key('tab_create'))).center.dx;
    await tester.tapAt(Offset(x, bar.top - 4));
    expect(created, 1);
  });

  testWidgets('вкладки: подписи и выбор вкладки', (tester) async {
    int? tapped;
    await tester.pumpWidget(_app(onCreate: () {}, onTap: (i) => tapped = i));
    await tester.pumpAndSettle();
    for (final label in ['Поездки', 'Мои заказы', 'Чаты', 'Профиль']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Профиль'));
    expect(tapped, 3);
  });
}
