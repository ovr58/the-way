import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/l10n/app_localizations.dart';
import 'package:the_way/src/theme/app_colors.dart';
import 'package:the_way/src/theme/app_theme.dart';
import 'package:the_way/src/widgets/app_icon.dart';
import 'package:the_way/src/widgets/rating_line.dart';

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
      home: Scaffold(body: Center(child: child)),
    );

const _rated = Rating(value: 4.5, count: 2);

void main() {
  // «Детали поездки - Места есть» (блок водителя): «★ 4,5 • 127 поездок» — между звездой и числом 8, серый кружок 6 (text.secondary),
  // подписи text.muted, между числом, кружком и поездками по 8.
  testWidgets('блок водителя: кружок-разделитель 6 между рейтингом и числом поездок', (tester) async {
    await tester.pumpWidget(_app(const RatingLine(rating: _rated, tripsCount: 127)));
    final dot = find.byKey(const Key('rating_dot'));
    expect(dot, findsOneWidget);
    expect(tester.getSize(dot), const Size(6, 6));
    final box = tester.widget<DecoratedBox>(find.descendant(of: dot, matching: find.byType(DecoratedBox)));
    expect((box.decoration as BoxDecoration).color, AppColors.textSecondary);
    expect((box.decoration as BoxDecoration).shape, BoxShape.circle);
    final rating = tester.getRect(find.text('4,5'));
    final trips = tester.getRect(find.text('127 поездок'));
    final d = tester.getRect(dot);
    expect(rating.right, lessThanOrEqualTo(d.left));
    expect(d.right, lessThanOrEqualTo(trips.left));
    expect(d.left - rating.right, closeTo(8, 0.5));
    expect(trips.left - d.right, closeTo(8, 0.5));
    expect(tester.widget<Text>(find.text('127 поездок')).style?.color, AppColors.textMuted);
    expect(rating.left - tester.getRect(find.byType(AppIcon)).right, closeTo(8, 0.5)); // звезда — число
  });

  testWidgets('число поездок склоняется: 1 поездка, 2 поездки, 5 поездок', (tester) async {
    for (final (n, text) in [(1, '1 поездка'), (2, '2 поездки'), (5, '5 поездок'), (21, '21 поездка')]) {
      await tester.pumpWidget(_app(RatingLine(rating: _rated, tripsCount: n)));
      expect(find.text(text), findsOneWidget, reason: '$n');
    }
  });

  testWidgets('без числа поездок кружка нет', (tester) async {
    await tester.pumpWidget(_app(const RatingLine(rating: _rated)));
    expect(find.byKey(const Key('rating_dot')), findsNothing);
    await tester.pumpWidget(_app(const RatingLine(rating: Rating(value: 5, count: 0))));
    expect(find.byKey(const Key('rating_dot')), findsNothing);
  });

  testWidgets('без отзывов, но с завершёнными поездками — «5, нет отзывов • 3 поездки»', (tester) async {
    await tester.pumpWidget(_app(const RatingLine(rating: Rating(value: 5, count: 0), tripsCount: 3)));
    expect(find.text('5, нет отзывов'), findsOneWidget);
    expect(find.byKey(const Key('rating_dot')), findsOneWidget);
    expect(find.text('3 поездки'), findsOneWidget);
  });

  testWidgets('без отзывов и без поездок — только «5, нет отзывов»', (tester) async {
    await tester.pumpWidget(_app(const RatingLine(rating: Rating(value: 5, count: 0), tripsCount: 0)));
    expect(find.text('5, нет отзывов'), findsOneWidget);
    expect(find.byKey(const Key('rating_dot')), findsNothing);
    expect(find.textContaining('поезд'), findsNothing);
  });

  testWidgets('ряды без поездок в кадре (лента, пассажир) — поездки только при нуле отзывов', (tester) async {
    await tester.pumpWidget(_app(const RatingLine(rating: _rated, tripsCount: 127, tripsWithReviews: false)));
    expect(find.textContaining('поезд'), findsNothing);
    await tester.pumpWidget(
        _app(const RatingLine(rating: Rating(value: 5, count: 0), tripsCount: 127, tripsWithReviews: false)));
    expect(find.text('5, нет отзывов'), findsOneWidget);
    expect(find.text('127 поездок'), findsOneWidget);
  });

  // «Профиль - Базовый экран», «Профиль ВОДИТЕЛЯ» (шапка профиля): кружок 3 цвета text.primary, промежутки по 4, текст text.primary.
  testWidgets('шапка профиля: кружок 3, промежутки 4, текст основного цвета', (tester) async {
    await tester.pumpWidget(_app(const RatingLine(rating: _rated, tripsCount: 120, variant: RatingLineVariant.profile)));
    final dot = find.byKey(const Key('rating_dot'));
    expect(tester.getSize(dot), const Size(3, 3));
    final box = tester.widget<DecoratedBox>(find.descendant(of: dot, matching: find.byType(DecoratedBox)));
    expect((box.decoration as BoxDecoration).color, AppColors.textPrimary);
    final rating = tester.getRect(find.text('4,5'));
    final trips = tester.getRect(find.text('120 поездок'));
    final d = tester.getRect(dot);
    expect(d.left - rating.right, closeTo(4, 0.5));
    expect(trips.left - d.right, closeTo(4, 0.5));
    expect(tester.widget<Text>(find.text('120 поездок')).style?.color, AppColors.textPrimary);
    expect(tester.widget<Text>(find.text('4,5')).style?.color, AppColors.textPrimary);
    expect(rating.left - tester.getRect(find.byType(AppIcon)).right, closeTo(4, 0.5)); // звезда — число
  });
}
