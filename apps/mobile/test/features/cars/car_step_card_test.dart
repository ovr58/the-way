import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/trip_new/steps/car_step.dart';
import 'package:the_way/src/features/trip_new/wizard_controller.dart';
import 'package:the_way/src/theme/app_colors.dart';
import 'package:the_way/src/widgets/app_icon.dart';

import '../trip_new/support.dart';

/// Карточка авто шага 4 мастера по кадрам «Новый заказ - Выбор авто - есть авто», «Новый заказ - Выбор авто - выбрано авто» (тема car-check-badge).
void main() {
  WizardController draft(FakeAdapter adapter) {
    final c = WizardController(repositoryOf(adapter))..setKind(TripKind.ride);
    while (c.stops.length < 2) {
      c.addStop();
    }
    for (var i = 0; i < c.stops.length; i++) {
      c.setStopFromSuggestion(i, GeoSuggestion.fromJson(suggestion('Адрес $i')));
    }
    c.setSeats(3);
    return c;
  }

  Future<WizardController> open(WidgetTester tester) async {
    tallView(tester);
    final c = draft(FakeAdapter({'GET /cars': (o) => FakeReply([carJson()])}));
    await tester.pumpWidget(app(CarStep(controller: c)));
    await tester.pumpAndSettle();
    return c;
  }

  Finder rowWith(String text) => find.ancestor(of: find.text(text), matching: find.byType(Row));

  testWidgets('у названия — зелёная галочка «Проверен» 16 («Новый заказ - Выбор авто - есть авто»)', (tester) async {
    await open(tester);
    final badge = find.descendant(
      of: rowWith('Toyota Camry').first,
      matching: find.byWidgetPredicate((w) => w is AppIcon && w.name == 'essentional_check_circle'),
    );
    expect(badge, findsOneWidget);
    final icon = tester.widget<AppIcon>(badge);
    expect(icon.size, 16);
    expect(icon.color, AppColors.accentPrimary);
  });

  testWidgets('номер и места — одной строкой («Новый заказ - Выбор авто - есть авто»)', (tester) async {
    await open(tester);
    // Ближайший ряд номера — свой: в нём места, но не название (не общий ряд карточки).
    final line = rowWith('7841HX-7').first;
    expect(find.descendant(of: line, matching: find.text('4 места')), findsOneWidget);
    expect(find.descendant(of: line, matching: find.text('Toyota Camry')), findsNothing);
  });

  testWidgets('выбранная карточка залита светло-зелёным («Новый заказ - Выбор авто - выбрано авто»)', (tester) async {
    await open(tester);
    Finder tinted() => find.byWidgetPredicate(
          (w) => w is Container && (w.decoration as BoxDecoration?)?.color == AppColors.accentPrimaryTint,
        );
    expect(tinted(), findsNothing);
    await tester.tap(find.text('Toyota Camry'));
    await tester.pump();
    expect(tinted(), findsOneWidget);
  });
}
