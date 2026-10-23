import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/widgets/app_image.dart';

/// неудача загрузки картинки с API не прячется за серой плашкой молча — уходит в журнал клиента
/// один раз на адрес (в тестах сеть отвечает 400).
void main() {
  tearDown(() => AppImage.onLoadError = null);

  testWidgets('неудача загрузки — плашка и одно сообщение в журнал на адрес', (tester) async {
    final messages = <String>[];
    AppImage.onLoadError = messages.add;
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Column(children: [
        AppImage('/files/broken', width: 42, height: 42),
        AppImage('/files/broken', width: 42, height: 42),
      ]),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(messages, hasLength(1));
    expect(messages.single, contains('/files/broken'));
    expect(messages.single, contains('42.0×42.0'));
  });
}
