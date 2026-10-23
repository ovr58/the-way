import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/app_routes.dart';
import 'package:the_way/src/features/cars/routes.dart';

import '../driver_bookings/support.dart';

Map<String, Object?> carJson({String status = 'verified', List<Object?> documents = const []}) =>
    {...car(), 'status': status, 'documents': documents};

Future<MockAdapter> open(WidgetTester tester, Map<String, Object?> routes, {List<(String, Object?)>? pushed}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final adapter = MockAdapter(routes);
  await tester.pumpWidget(testApp(
    session: makeSession(adapter),
    pushed: pushed,
    home: Builder(builder: (context) => carsRoutes[AppRoutes.cars]!(context, null)),
  ));
  await settle(tester);
  return adapter;
}

void main() {
  testWidgets('миниатюра фото авто в списке грузится с токеном сессии, как фото в деталях', (tester) async {
    await open(tester, {'GET /cars': [{...carJson(), 'photoUrl': '/files/p1'}]});
    final images = tester.widgetList<Image>(find.byType(Image)).map((i) => i.image).whereType<NetworkImage>().toList();
    expect(images, hasLength(1));
    expect(images.single.url, endsWith('/files/p1'));
    expect(images.single.headers, {'Authorization': 'Bearer tok'});
  });

  testWidgets('нет авто («Транспортные средства»): текст и кнопка «Добавить ТС»', (tester) async {
    await open(tester, {'GET /cars': <Object?>[]});
    expect(find.text('Транспортные средства'), findsOneWidget);
    expect(find.text('У вас еще нет транспортного средства'), findsOneWidget);
    expect(find.text('Добавьте информацию о ТС и берите или создавайте заказы'), findsOneWidget);
    expect(find.text('Добавить ТС'), findsOneWidget);
  });

  testWidgets('есть авто («Транспортные средства»): название, госномер, места', (tester) async {
    await open(tester, {'GET /cars': [carJson()]});
    expect(find.text('Toyota Camry'), findsOneWidget);
    expect(find.textContaining('7841HX-7'), findsOneWidget);
    expect(find.textContaining('4 места'), findsOneWidget);
    expect(find.text('Добавить ТС'), findsOneWidget);
    expect(find.text('У вас еще нет транспортного средства'), findsNothing);
  });

  testWidgets('строка авто по кадру «Транспортные средства»: название 13/600, «номер • места» точкой 4×4 в своём ряду', (tester) async {
    await open(tester, {'GET /cars': [carJson()]});
    final title = tester.widget<Text>(find.text('Toyota Camry'));
    expect(title.style?.fontSize, 13);
    expect(title.style?.fontWeight, FontWeight.w600);
    final line = find.ancestor(of: find.text('7841HX-7'), matching: find.byType(Row)).first;
    expect(find.descendant(of: line, matching: find.text('4 места')), findsOneWidget);
    expect(find.descendant(of: line, matching: find.text('Toyota Camry')), findsNothing);
    expect(
      find.descendant(
        of: line,
        matching: find.byWidgetPredicate(
          (w) => w is Container && (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('«Добавить ТС» открывает cars/add', (tester) async {
    final pushed = <(String, Object?)>[];
    await open(tester, {'GET /cars': [carJson()]}, pushed: pushed);
    await tester.tap(find.text('Добавить ТС'));
    await tester.pumpAndSettle();
    expect(pushed.single.$1, AppRoutes.carsAdd);
  });

  testWidgets('ошибка загрузки — экран с повтором', (tester) async {
    await open(tester, {'GET /cars': (500, {'code': 'internal', 'message': 'x'})});
    expect(find.text('Обновить'), findsOneWidget);
  });

  group('карточка авто («Транспортные средства»)', () {
    final sts = {'id': 'd1', 'kind': 'sts', 'url': '/files/f1'};

    testWidgets('сведения и документы; «Редактировать» над «Удалить ТС», «Заменить» в строке СТС (кадры «Транспортные средства»)', (tester) async {
      await open(tester, {'GET /cars': [carJson(documents: [sts])]});
      await tester.tap(find.text('Toyota Camry'));
      await tester.pumpAndSettle();
      expect(find.text('Toyota Camry'), findsWidgets);
      expect(find.text('7841HX-7'), findsOneWidget);
      expect(find.text('Проверен'), findsOneWidget);
      expect(find.text('Легковой · 4 места'), findsOneWidget);
      expect(find.text('Документы'), findsOneWidget);
      expect(find.text('СТС (свидетельство о регистрации)'), findsOneWidget);
      expect(find.text('Удалить ТС'), findsOneWidget);
      expect(find.text('Редактировать'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Редактировать')).dy, lessThan(tester.getTopLeft(find.text('Удалить ТС')).dy));
      expect(find.text('Заменить'), findsOneWidget);
      expect(tester.getCenter(find.text('Заменить')).dy,
          closeTo(tester.getCenter(find.text('СТС (свидетельство о регистрации)')).dy, 1));
    });

    testWidgets('без файлов документов блок «Документы — СТС» всё равно показан, с «Заменить» (кадры «Транспортные средства»)', (tester) async {
      await open(tester, {'GET /cars': [carJson()]});
      await tester.tap(find.text('Toyota Camry'));
      await tester.pumpAndSettle();
      expect(find.text('Документы'), findsOneWidget);
      expect(find.text('СТС (свидетельство о регистрации)'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Документы')).dy, lessThan(tester.getTopLeft(find.text('СТС (свидетельство о регистрации)')).dy));
      expect(find.text('Заменить'), findsOneWidget);
      expect(find.text('Редактировать'), findsOneWidget);
    });

    testWidgets('статус на проверке — своя подпись', (tester) async {
      await open(tester, {'GET /cars': [carJson(status: 'pending')]});
      await tester.tap(find.text('Toyota Camry'));
      await tester.pumpAndSettle();
      expect(find.text('На проверке'), findsOneWidget);
      expect(find.text('Проверен'), findsNothing);
    });

    testWidgets('удаление: подтверждение, DELETE, список обновляется', (tester) async {
      var listed = 0;
      final adapter = await open(tester, {
        'GET /cars': (RequestOptions _) => ++listed == 1 ? [carJson()] : <Object?>[],
        'DELETE /cars/c1': (204, null),
      });
      await tester.tap(find.text('Toyota Camry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить ТС'));
      await tester.pumpAndSettle();
      expect(find.text('Удалить транспортное средство?'), findsOneWidget);
      expect(adapter.log, isNot(contains('DELETE /cars/c1')));
      await tester.tap(find.text('Удалить'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(adapter.log, contains('DELETE /cars/c1'));
      expect(adapter.log.where((e) => e == 'GET /cars').length, 2);
      expect(find.text('У вас еще нет транспортного средства'), findsOneWidget);
    });

    testWidgets('отмена в окне удаления ничего не удаляет', (tester) async {
      final adapter = await open(tester, {'GET /cars': [carJson()]});
      await tester.tap(find.text('Toyota Camry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить ТС'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(adapter.log.where((e) => e.startsWith('DELETE')), isEmpty);
    });
  });
}
