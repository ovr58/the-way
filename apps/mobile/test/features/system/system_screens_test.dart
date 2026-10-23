import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/l10n/app_localizations.dart';
import 'package:the_way/src/app/app_images.dart';
import 'package:the_way/src/app/app_routes.dart';
import 'package:the_way/src/features/system/blocked_screen.dart';
import 'package:the_way/src/features/system/error_screen.dart';
import 'package:the_way/src/features/system/offline_screen.dart';
import 'package:the_way/src/features/system/stub_screen.dart';
import 'package:the_way/src/theme/app_theme.dart';
import 'package:the_way/src/widgets/app_empty.dart';
import 'package:the_way/src/widgets/app_error_view.dart';
import 'package:the_way/src/widgets/app_loading.dart';

Widget _app(Widget home) => MaterialApp(
      theme: buildTheme(),
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

Finder _asset(String name) => find.byWidgetPredicate(
      (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == name,
    );

void main() {
  testWidgets('«Отсутствии интернета»: нет сети — тексты кадра и «Обновить»', (tester) async {
    var retried = false;
    await tester.pumpWidget(_app(OfflineScreen(onRetry: () async => retried = true)));
    expect(find.text('Нет интернет-соединения'), findsOneWidget);
    expect(_asset(AppImages.systemOffline), findsOneWidget);
    expect(find.text('Проверьте, включён ли Wi-Fi или мобильный интернет, и попробуйте снова.'), findsOneWidget);
    await tester.tap(find.text('Обновить'));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('«Ошибка»: ошибка — тексты кадра и «Обновить»', (tester) async {
    await tester.pumpWidget(_app(ErrorScreen(onRetry: () async {})));
    expect(find.text('Не удалось выполнить действие'), findsOneWidget);
    expect(_asset(AppImages.systemOffline), findsOneWidget);
    expect(find.textContaining('Что-то пошло не так.'), findsOneWidget);
    expect(find.text('Обновить'), findsOneWidget);
  });

  testWidgets('«Аккаунт заблокирован»: аккаунт заблокирован', (tester) async {
    await tester.pumpWidget(_app(const BlockedScreen()));
    expect(find.text('Путь'), findsOneWidget);
    expect(_asset(AppImages.logo), findsOneWidget);
    expect(_asset(AppImages.accountBlocked), findsOneWidget);
    expect(find.text('Ваш аккаунт заблокирован'), findsOneWidget);
    expect(find.text('Мы ограничили доступ из-за нарушений условий использования'), findsOneWidget);
  });

  testWidgets('заглушки: «Раздел в разработке» и «Чат появится позже»', (tester) async {
    await tester.pumpWidget(_app(const StubScreen(title: 'Раздел в разработке')));
    expect(find.text('Раздел в разработке'), findsOneWidget);
    await tester.pumpWidget(_app(const StubScreen(title: 'Чат появится позже')));
    expect(find.text('Чат появится позже'), findsOneWidget);
  });

  testWidgets('маршрут stub без аргумента — «Раздел в разработке»', (tester) async {
    await tester.pumpWidget(_app(Builder(builder: (c) => buildRoute(c, AppRoutes.stub))));
    expect(find.text('Раздел в разработке'), findsOneWidget);
  });

  testWidgets('AppEmpty, AppLoading, AppErrorView', (tester) async {
    await tester.pumpWidget(_app(const AppEmpty(title: 'Пусто', subtitle: 'Нет данных')));
    expect(find.text('Пусто'), findsOneWidget);
    expect(find.text('Нет данных'), findsOneWidget);
    await tester.pumpWidget(_app(const AppLoading()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    var retried = false;
    await tester.pumpWidget(_app(AppErrorView(onRetry: () => retried = true)));
    await tester.tap(find.text('Обновить'));
    expect(retried, isTrue);
  });
}
