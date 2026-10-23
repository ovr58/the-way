import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/l10n/app_localizations.dart';
import 'package:the_way/src/theme/app_colors.dart';
import 'package:the_way/src/widgets/rating_line.dart';

/// Плашка «Рейтинг поездок» профиля пассажира («Профиль - Профиль пассажира», «Профиль - Профиль пассажира до оплаты»): «★ 4,8 · 120 поездок» — между числом и
/// поездками кружок 3 цвета text.primary, промежутки 4, текст 15/600.
void main() {
  Widget app(Widget child) => MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)),
      );

  testWidgets('вид stat: «4,8 · 120 поездок», кружок 3, текст 15/600', (tester) async {
    await tester.pumpWidget(app(RatingLine(
      rating: Rating(value: 4.8, count: 8),
      tripsCount: 120,
      variant: RatingLineVariant.stat,
    )));
    expect(tester.getSize(find.byKey(const Key('rating_dot'))), const Size(3, 3));
    final value = tester.widget<Text>(find.text('4,8'));
    expect(value.style?.fontWeight, FontWeight.w600);
    expect(value.style?.fontSize, 15);
    expect(value.style?.color, AppColors.textPrimary);
    expect(tester.widget<Text>(find.text('120 поездок')).style?.fontWeight, FontWeight.w600);
  });
}
