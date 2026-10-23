import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/widgets/success_badge.dart';

void main() {
  testWidgets('круг иллюстрации — заливка кадра #7EEB42 @ 0.2', (tester) async {
    await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: Center(child: SuccessBadge())));
    final circle = tester.widget<Container>(find.descendant(of: find.byType(SuccessBadge), matching: find.byType(Container)).first);
    expect((circle.decoration! as BoxDecoration).color, const Color(0x337EEB42));
  });

  testWidgets('вариант «Бронь отменена»: круг #EB4245 @ 0.12', (tester) async {
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.ltr, child: Center(child: SuccessBadge(failure: true))),
    );
    final circle = tester.widget<Container>(find.descendant(of: find.byType(SuccessBadge), matching: find.byType(Container)).first);
    expect((circle.decoration! as BoxDecoration).color, const Color(0x1FEB4245));
  });
}
