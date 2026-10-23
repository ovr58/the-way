import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/theme/app_theme.dart';
import 'package:the_way/src/widgets/app_icon.dart';
import 'package:the_way/src/widgets/expand_toggle.dart';

import '../support/expand_checks.dart';

const _chip = Key('t_chip');
const _collapse = Key('t_collapse');

class _Host extends StatefulWidget {
  const _Host({this.height});

  final double? height;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool open = false;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Между остановками'),
              ExpandToggle(
                label: 'Смотреть стоимость',
                expanded: open,
                chipKey: _chip,
                closeKey: _collapse,
                height: widget.height ?? 24,
                onTap: () => setState(() => open = !open),
              ),
            ],
          ),
          ExpandReveal(expanded: open, child: const Column(children: [Text('A - B'), Text('B - C')])),
        ],
      );
}

Widget _app({double? height}) => MaterialApp(theme: buildTheme(), home: Scaffold(body: _Host(height: height)));

void main() {
  testWidgets('нажатие — список выплывает за 350 мс, повторное нажатие прячет', (tester) async {
    await tester.pumpWidget(_app());
    await expectExpandCycle(tester, chip: _chip, collapse: _collapse, item: find.text('A - B'));
  });

  testWidgets('раскрыто — круг без текста со стрелкой вверх справа; свёрнуто — таблетка с текстом и стрелкой вниз', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.text('Смотреть стоимость'), findsOneWidget);
    expect(tester.getSize(find.byKey(_chip)).height, 24);

    await tester.tap(find.byKey(_chip));
    await tester.pumpAndSettle();
    final circle = tester.getRect(find.byKey(_collapse));
    expect(circle.size, const Size(24, 24));
    expect(circle.right, closeTo(tester.getRect(find.byType(Scaffold)).right, 0.5), reason: 'у правого края строки');
    expect(find.text('Смотреть стоимость'), findsNothing);
    final turn = tester.widget<Transform>(
      find.ancestor(of: find.descendant(of: find.byKey(_collapse), matching: find.byType(AppIcon)), matching: find.byType(Transform)).first,
    );
    expect(turn.transform.getRotation().entry(0, 0), closeTo(-1, 1e-9), reason: 'стрелка повёрнута на 180°');
  });

  testWidgets('высота свёрнутой таблетки задаётся снаружи (прежний вид кнопки в каждом месте)', (tester) async {
    await tester.pumpWidget(_app(height: 21));
    expect(tester.getSize(find.byKey(_chip)).height, 21);
    await tester.tap(find.byKey(_chip));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_collapse)), const Size(21, 21));
  });

  testWidgets('ExpandReveal: высота на середине между нулём и полной', (tester) async {
    await tester.pumpWidget(_app());
    final reveal = find.byType(ExpandReveal);
    expect(tester.getSize(reveal).height, 0);
    await tester.tap(find.byKey(_chip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 175));
    final mid = tester.getSize(reveal).height;
    await tester.pumpAndSettle();
    final full = tester.getSize(reveal).height;
    expect(mid, allOf(greaterThan(0), lessThan(full)));
  });
}
