import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:the_way/src/app/app_routes.dart';
import 'package:the_way/src/features/cars/add/add_car_screen.dart' show PhotoPicker;
import 'package:the_way/src/features/cars/data/car_catalog.dart';
import 'package:the_way/src/features/cars/list/car_details_screen.dart';
import 'package:the_way/src/features/cars/routes.dart';
import 'package:the_way/src/widgets/app_button.dart';
import 'package:the_way/src/widgets/app_input.dart';

import '../driver_bookings/support.dart';

/// Кадры «Транспортные средства»: «Редактировать» открывает форму добавления ТС в режиме правки, «Заменить» — новый СТС.

Map<String, Object?> carJson({int seats = 4, String model = 'Camry', String? photoUrl}) => {
      ...car(),
      'seats': seats,
      'model': model,
      'photoUrl': photoUrl,
      'documents': [
        {'id': 'd1', 'kind': 'sts', 'url': '/files/s1'},
      ],
    };

Finder field(String label) => find.descendant(
      of: find.byWidgetPredicate((w) => w is AppInput && w.label == label),
      matching: find.byType(TextField),
    );

String fieldText(WidgetTester tester, String label) => tester.widget<TextField>(field(label)).controller!.text;

XFile photoFile() {
  final dir = Directory.systemTemp.createTempSync('ce-photo');
  addTearDown(() => dir.deleteSync(recursive: true));
  final f = File('${dir.path}/p.jpg')..writeAsBytesSync([1, 2, 3]);
  return XFile(f.path);
}

void useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Список авто → карточка «Транспортные средства».
Future<MockAdapter> openDetailsFromList(WidgetTester tester, Map<String, Object?> routes) async {
  useTallView(tester);
  final adapter = MockAdapter(routes);
  await tester.pumpWidget(testApp(
    session: makeSession(adapter),
    home: Builder(builder: (context) => carsRoutes[AppRoutes.cars]!(context, null)),
  ));
  await settle(tester);
  await tester.tap(find.text('Toyota Camry'));
  await tester.pumpAndSettle();
  return adapter;
}

/// Карточка «Транспортные средства» напрямую — с подменённым выбором снимка.
Future<MockAdapter> openDetails(WidgetTester tester, Map<String, Object?> routes, {required Car car, required PhotoPicker picker}) async {
  useTallView(tester);
  final adapter = MockAdapter(routes);
  await tester.pumpWidget(testApp(session: makeSession(adapter), home: CarDetailsScreen(car: car, picker: picker)));
  await tester.pumpAndSettle();
  return adapter;
}

Future<void> openEdit(WidgetTester tester) async {
  await tester.tap(find.text('Редактировать'));
  await tester.pumpAndSettle();
  await settle(tester); // каталог читается из ассета настоящим вводом-выводом
  await tester.pumpAndSettle();
}

AppButton saveButton(WidgetTester tester) =>
    tester.widget<AppButton>(find.byWidgetPredicate((w) => w is AppButton && w.label == 'Сохранить'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => rootBundle.loadString(CarCatalog.asset));

  testWidgets('«Редактировать»: та же форма с полями авто, «Сохранить» шлёт PATCH, карточка и список обновлены', (tester) async {
    var listed = 0;
    final adapter = await openDetailsFromList(tester, {
      'GET /cars': (RequestOptions _) => ++listed == 1 ? [carJson()] : [carJson(seats: 3)],
      'PATCH /cars/c1': carJson(seats: 3),
    });
    await openEdit(tester);
    expect(find.text('Редактирование ТС'), findsOneWidget);
    expect(fieldText(tester, 'Марка'), 'Toyota');
    expect(fieldText(tester, 'Модель'), 'Camry');
    expect(fieldText(tester, 'Госномер'), '7841HX-7');
    expect(fieldText(tester, 'Вместимость'), '4');
    expect(find.text('Тип'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
    await tester.enterText(field('Вместимость'), '3');
    await tester.pump();
    await tester.tap(find.text('Сохранить'));
    await settle(tester);
    await tester.pumpAndSettle();
    final patch = adapter.requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.path, '/cars/c1');
    expect(patch.data, {
      'brand': 'Toyota',
      'model': 'Camry',
      'kind': 'car',
      'seats': 3,
      'plate': '7841HX-7',
      'photoFileId': null,
    });
    expect(adapter.log.where((e) => e.startsWith('POST')), isEmpty);
    expect(find.text('Легковой · 3 места'), findsOneWidget);
    await tester.binding.handlePopRoute(); // системное «назад»
    await settle(tester);
    await tester.pumpAndSettle();
    expect(adapter.log.where((e) => e == 'GET /cars').length, 2);
  });

  testWidgets('правка: номер другого своего авто (car_plate_taken) — текст под полем «Госномер», форма остаётся', (tester) async {
    await openDetailsFromList(tester, {
      'GET /cars': [carJson()],
      'PATCH /cars/c1': (409, {'code': 'car_plate_taken', 'message': 'x'}),
    });
    await openEdit(tester);
    await tester.enterText(field('Госномер'), 'В222ВВ76');
    await tester.pump();
    await tester.tap(find.text('Сохранить'));
    await settle(tester);
    await tester.pumpAndSettle();
    final input = tester.widget<AppInput>(find.byWidgetPredicate((w) => w is AppInput && w.label == 'Госномер'));
    expect(input.errorText, 'Авто с таким госномером уже есть в вашем списке');
    expect(find.text('Редактирование ТС'), findsOneWidget);
  });

  testWidgets('правка: модель выбирается из каталога марки авто', (tester) async {
    final adapter = await openDetailsFromList(tester, {
      'GET /cars': [carJson()],
      'PATCH /cars/c1': carJson(model: 'Corolla'),
    });
    await openEdit(tester);
    await tester.tap(field('Модель'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cars-search')), 'coro');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Corolla').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await settle(tester);
    await tester.pumpAndSettle();
    final patch = adapter.requests.singleWhere((r) => r.method == 'PATCH');
    expect((patch.data as Map)['model'], 'Corolla');
  });

  testWidgets('правка: фото авто с сервера показано, «Добавить фото» нет; новый снимок уходит photoFileId', (tester) async {
    final adapter = await openDetails(
      tester,
      {
        'POST /files': (201, {'id': 'f9', 'url': 'u'}),
        'PATCH /cars/c1': carJson(),
      },
      car: Car.fromJson(carJson(photoUrl: '/files/p1')),
      picker: (_) async => photoFile(),
    );
    await openEdit(tester);
    expect(find.text('Добавить фото'), findsNothing);
    await tester.tap(find.byKey(const Key('cars-photo-preview')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Камера'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await settle(tester);
    await tester.pumpAndSettle();
    final patch = adapter.requests.singleWhere((r) => r.method == 'PATCH');
    expect((patch.data as Map)['photoFileId'], 'f9');
  });

  testWidgets('«Заменить» у СТС: лист «Камера / Галерея», снимок уходит POST /cars/{id}/documents', (tester) async {
    final sources = <ImageSource>[];
    final adapter = await openDetails(
      tester,
      {
        'POST /files': (201, {'id': 'f1', 'url': 'u'}),
        'POST /cars/c1/documents': carJson(),
      },
      car: Car.fromJson(carJson()),
      picker: (source) async {
        sources.add(source);
        return photoFile();
      },
    );
    await tester.tap(find.text('Заменить'));
    await tester.pumpAndSettle();
    expect(find.text('Загрузка фотографии'), findsOneWidget);
    expect(find.text('Файлы'), findsNothing);
    await tester.tap(find.text('Галерея'));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(sources, [ImageSource.gallery]);
    final doc = adapter.requests.singleWhere((r) => r.path == '/cars/c1/documents');
    expect(doc.data, {'fileId': 'f1', 'kind': 'sts'});
  });

  testWidgets('камера запрещена — «Нет доступа к камере…», запросов нет', (tester) async {
    final adapter = await openDetails(tester, const {}, car: Car.fromJson(carJson()), picker: (_) async => throw PlatformException(code: 'camera_access_denied', message: 'The user did not allow camera access.'));
    await tester.tap(find.text('Заменить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Камера'));
    await tester.pumpAndSettle();
    expect(find.text('Нет доступа к камере — разрешите в настройках телефона'), findsOneWidget);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('«Заменить»: лист закрыт без выбора — запросов нет', (tester) async {
    final adapter = await openDetails(tester, const {}, car: Car.fromJson(carJson()), picker: (_) async => null);
    await tester.tap(find.text('Заменить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Камера'));
    await tester.pumpAndSettle();
    expect(adapter.requests, isEmpty);
  });
}
