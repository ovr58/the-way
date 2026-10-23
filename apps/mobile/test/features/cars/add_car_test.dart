import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:the_way/src/app/app_routes.dart';
import 'package:the_way/src/features/cars/add/add_car_screen.dart';
import 'package:the_way/src/features/cars/data/car_catalog.dart';
import 'package:the_way/src/features/cars/routes.dart';
import 'package:the_way/src/widgets/app_button.dart';
import 'package:the_way/src/widgets/app_input.dart';

import '../driver_bookings/support.dart';

Map<String, Object?> carJson({String id = 'c1', List<Object?> documents = const []}) =>
    {...car(), 'id': id, 'documents': documents};

/// Кнопка «Добавить» внизу формы: единственная [AppButton] на экране.
AppButton submitButton(WidgetTester tester) => tester.widget<AppButton>(find.byType(AppButton));

Finder field(String label) =>
    find.descendant(
      of: find.byWidgetPredicate((w) => w is AppInput && w.label == label),
      matching: find.byType(TextField),
    );

/// Текст ошибки под полем [label] формы (`AppInput.errorText`).
String? fieldError(WidgetTester tester, String label) =>
    tester.widget<AppInput>(find.byWidgetPredicate((w) => w is AppInput && w.label == label)).errorText;

/// Форма открыта как маршрут `cars/add` поверх кнопки-запускалки; результат — в [result].
Future<({MockAdapter adapter, List<Object?> result})> open(
  WidgetTester tester, {
  Map<String, Object?> routes = const {},
  PhotoPicker? picker,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final adapter = MockAdapter(routes);
  final result = <Object?>[];
  await tester.pumpWidget(testApp(
    session: makeSession(adapter),
    extraRoutes: {
      AppRoutes.carsAdd: (context, args) => picker == null ? carsRoutes[AppRoutes.carsAdd]!(context, args) : AddCarScreen(picker: picker),
    },
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async => result.add(await Navigator.of(context).pushNamed(AppRoutes.carsAdd)),
        child: const Text('открыть'),
      ),
    ),
  ));
  await tester.tap(find.text('открыть'));
  await tester.pumpAndSettle();
  await settle(tester); // каталог читается из ассета настоящим вводом-выводом
  return (adapter: adapter, result: result);
}

Future<void> pickBrand(WidgetTester tester, String query, String name) async {
  await tester.tap(field('Марка'));
  await settle(tester);
  await tester.pumpAndSettle();
  expect(find.text('Выбрать марку автомобиля'), findsOneWidget);
  await tester.enterText(find.byKey(const Key('cars-search')), query);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> pickModel(WidgetTester tester, String query, String name) async {
  await tester.tap(field('Модель'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('cars-search')), query);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

/// Снимок СТС: настоящий файл (его читает загрузка), выбранный через «Сделать фото» → «Камера».
Future<void> addSts(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('cars-add-sts')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Сделать фото'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Камера'));
  await tester.pumpAndSettle();
}

XFile stsFile() {
  final dir = Directory.systemTemp.createTempSync('u5fix-sts');
  addTearDown(() => dir.deleteSync(recursive: true));
  final f = File('${dir.path}/sts.jpg')..writeAsBytesSync([1, 2, 3]);
  return XFile(f.path);
}

/// Все поля формы заполнены (кроме СТС).
Future<void> fillForm(WidgetTester tester) async {
  await pickBrand(tester, 'toyo', 'Toyota');
  await pickModel(tester, 'camr', 'Camry');
  await tester.enterText(field('Госномер'), 'А 123 ВС 76');
  await tester.enterText(field('Вместимость'), '4');
  await tester.tap(find.text('Легковой'));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Ассет читается настоящим вводом-выводом; кэш пакета ассетов заполняется один раз, вне поддельного времени теста.
  setUpAll(() => rootBundle.loadString(CarCatalog.asset));

  testWidgets('без марки кнопка «Добавить» неактивна', (tester) async {
    await open(tester);
    expect(find.text('Добавление нового ТС'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('марка без остальных полей — кнопка по-прежнему неактивна', (tester) async {
    await open(tester);
    await pickBrand(tester, 'toyo', 'Toyota');
    expect(find.text('Toyota'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('модель нельзя выбрать, пока нет марки', (tester) async {
    await open(tester);
    await tester.tap(field('Модель'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Выбрать модель'), findsNothing);
  });

  testWidgets('поля появляются по шагам: марка → госномер, тип и вместимость; «Тип» над вместимостью', (tester) async {
    await open(tester);
    expect(field('Марка'), findsOneWidget);
    expect(field('Модель'), findsOneWidget);
    expect(find.byKey(const Key('cars-add-sts')), findsOneWidget);
    expect(field('Госномер'), findsNothing);
    expect(field('Вместимость'), findsNothing);
    expect(find.text('Тип'), findsNothing);
    await pickBrand(tester, 'toyo', 'Toyota');
    expect(field('Госномер'), findsOneWidget);
    expect(field('Вместимость'), findsOneWidget);
    expect(find.text('Тип'), findsOneWidget);
    expect(find.text('Легковой'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Тип')).dy, greaterThan(tester.getTopLeft(field('Госномер')).dy));
    expect(tester.getBottomLeft(find.text('Легковой')).dy, lessThan(tester.getTopLeft(field('Вместимость')).dy));
  });

  testWidgets('без выбранного типа вместимость не проверяется; выбран «Легковой» — «9» уже ошибка', (tester) async {
    await open(tester);
    await pickBrand(tester, 'toyo', 'Toyota');
    await tester.enterText(field('Вместимость'), '9');
    await tester.pump();
    expect(fieldError(tester, 'Вместимость'), isNull);
    await tester.ensureVisible(find.text('Легковой'));
    await tester.tap(find.text('Легковой'));
    await tester.pump();
    expect(fieldError(tester, 'Вместимость'), 'У легкового — от 1 до 8 мест');
  });

  testWidgets('без фото СТС кнопка «Добавить» неактивна (FR-04)', (tester) async {
    await open(tester, picker: (_) async => stsFile());
    await fillForm(tester);
    expect(submitButton(tester).onPressed, isNull);
    await addSts(tester);
    expect(submitButton(tester).onPressed, isNotNull);
  });

  // «Автобус» выбирается, мест у него от 9 до 60.
  testWidgets('«Автобус»: 4 места — текст под полем и «Добавить» неактивна; 24 — можно; «Легковой» с 24 — снова текст', (tester) async {
    await open(tester, picker: (_) async => stsFile());
    await pickBrand(tester, 'toyo', 'Toyota');
    await pickModel(tester, 'camr', 'Camry');
    await tester.enterText(field('Госномер'), 'А 123 ВС 76');
    await tester.enterText(field('Вместимость'), '4');
    await addSts(tester);
    await tester.tap(find.text('Автобус'));
    await tester.pump();
    expect(fieldError(tester, 'Вместимость'), 'У автобуса — от 9 до 60 мест');
    expect(submitButton(tester).onPressed, isNull);

    await tester.enterText(field('Вместимость'), '61');
    await tester.pump();
    expect(fieldError(tester, 'Вместимость'), 'У автобуса — от 9 до 60 мест');
    expect(submitButton(tester).onPressed, isNull);

    await tester.enterText(field('Вместимость'), '24');
    await tester.pump();
    expect(fieldError(tester, 'Вместимость'), isNull);
    expect(submitButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Легковой'));
    await tester.pump();
    expect(fieldError(tester, 'Вместимость'), 'У легкового — от 1 до 8 мест');
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('автобус: POST /cars с kind=bus и 24 местами', (tester) async {
    final env = await open(
      tester,
      picker: (_) async => stsFile(),
      routes: {
        'POST /cars': (201, carJson(id: 'c9')),
        'POST /files': (201, {'id': 'f1', 'url': 'http://test/f1'}),
        'POST /cars/c9/documents': carJson(id: 'c9'),
      },
    );
    await fillForm(tester);
    await tester.enterText(field('Вместимость'), '24');
    await tester.tap(find.text('Автобус'));
    await tester.pump();
    await addSts(tester);
    await tester.tap(find.byType(AppButton));
    await settle(tester);
    await tester.pumpAndSettle();
    final post = env.adapter.requests.singleWhere((r) => r.method == 'POST' && r.path == '/cars');
    expect((post.data as Map)['kind'], 'bus');
    expect((post.data as Map)['seats'], 24);
  });

  testWidgets('кнопки «Тип» по кадру «Добавление нового ТС»: значок и подпись, без картинки, высота 72', (tester) async {
    await open(tester);
    await pickBrand(tester, 'toyo', 'Toyota');
    await pickModel(tester, 'camr', 'Camry');
    for (final label in ['Легковой', 'Автобус']) {
      final button = find.ancestor(of: find.text(label), matching: find.byType(Material)).first;
      expect(find.descendant(of: button, matching: find.byType(Image)), findsNothing, reason: label);
      expect(tester.getSize(button).height, 72, reason: label);
    }
  });

  testWidgets('все поля заполнены: POST /cars с каждым полем формы и carId в результате', (tester) async {
    final env = await open(
      tester,
      picker: (_) async => stsFile(),
      routes: {
        'POST /cars': (201, carJson(id: 'c9')),
        'POST /files': (201, {'id': 'f1', 'url': 'http://test/f1'}),
        'POST /cars/c9/documents': carJson(id: 'c9'),
      },
    );
    await fillForm(tester);
    await addSts(tester);
    await tester.tap(find.byType(AppButton));
    await settle(tester);
    await tester.pumpAndSettle();
    final post = env.adapter.requests.singleWhere((r) => r.method == 'POST' && r.path == '/cars');
    expect(post.data, {
      'brand': 'Toyota',
      'model': 'Camry',
      'kind': 'car',
      'seats': 4,
      'plate': 'А 123 ВС 76',
      'photoFileId': null,
    });
    final doc = env.adapter.requests.singleWhere((r) => r.path == '/cars/c9/documents');
    expect(doc.data, {'fileId': 'f1', 'kind': 'sts'});
    expect(env.result, ['c9']);
  });

  testWidgets('каталог марок сгруппирован по буквам («Добавление нового ТС»)', (tester) async {
    await open(tester);
    await tester.tap(field('Марка'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const Key('cars-letter-A'))).dy, lessThan(tester.getTopLeft(find.text('Audi')).dy));
    final letterB = find.byKey(const Key('cars-letter-B'));
    await tester.scrollUntilVisible(letterB, 400, scrollable: find.byType(Scrollable).last);
    expect(tester.getTopLeft(letterB).dy, lessThan(tester.getTopLeft(find.text('BAIC')).dy));
    // поиск оставляет только буквы найденных марок
    await tester.enterText(find.byKey(const Key('cars-search')), 'toyo');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cars-letter-T')), findsOneWidget);
    expect(find.byKey(const Key('cars-letter-A')), findsNothing);
  });

  testWidgets('смена марки сбрасывает модель', (tester) async {
    await open(tester);
    await pickBrand(tester, 'toyo', 'Toyota');
    await pickModel(tester, 'camr', 'Camry');
    expect(find.text('Camry'), findsOneWidget);
    await pickBrand(tester, 'bmw', 'BMW');
    expect(find.text('Camry'), findsNothing);
  });

  testWidgets('ошибка сервера: текст, экран остаётся', (tester) async {
    final env = await open(
      tester,
      picker: (_) async => stsFile(),
      routes: {
        'POST /cars': (400, {'code': 'validation', 'message': 'x'}),
        'POST /files': (201, {'id': 'f1', 'url': 'http://test/f1'}),
      },
    );
    await fillForm(tester);
    await addSts(tester);
    await tester.tap(find.byType(AppButton));
    await settle(tester);
    expect(find.text('Не удалось выполнить действие. Повторите попытку.'), findsOneWidget);
    expect(env.result, isEmpty);
    expect(find.text('Добавление нового ТС'), findsOneWidget);
  });

  // Кадры «Транспортные средства»: одно авто не добавить в свой список дважды — сервер отвечает
  // кодом `car_plate_taken`, форма показывает текст под полем «Госномер».
  testWidgets('госномер уже в списке (car_plate_taken): текст под полем «Госномер», правка номера его убирает', (tester) async {
    final env = await open(
      tester,
      picker: (_) async => stsFile(),
      routes: {
        'POST /cars': (409, {'code': 'car_plate_taken', 'message': 'x'}),
        'POST /files': (201, {'id': 'f1', 'url': 'http://test/f1'}),
      },
    );
    await fillForm(tester);
    await addSts(tester);
    await tester.tap(find.byType(AppButton));
    await settle(tester);
    expect(fieldError(tester, 'Госномер'), 'Авто с таким госномером уже есть в вашем списке');
    expect(find.text('Не удалось выполнить действие. Повторите попытку.'), findsNothing);
    expect(env.result, isEmpty);

    await tester.enterText(field('Госномер'), 'А 124 ВС 76');
    await tester.pump();
    expect(fieldError(tester, 'Госномер'), isNull);
  });

  // Принятое решение: у «Легкового» мест от 1 до 8.
  testWidgets('вместимость легкового — от 1 до 8: «9» — текст под полем и «Добавить» неактивна, «8» — можно', (tester) async {
    await open(tester, picker: (_) async => stsFile());
    await fillForm(tester);
    await addSts(tester);
    await tester.enterText(field('Вместимость'), '9');
    await tester.pump();
    expect(fieldError(tester, 'Вместимость'), 'У легкового — от 1 до 8 мест');
    expect(submitButton(tester).onPressed, isNull);

    await tester.enterText(field('Вместимость'), '0');
    await tester.pump();
    expect(fieldError(tester, 'Вместимость'), 'У легкового — от 1 до 8 мест');
    expect(submitButton(tester).onPressed, isNull);

    await tester.enterText(field('Вместимость'), '8');
    await tester.pump();
    expect(fieldError(tester, 'Вместимость'), isNull);
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('сервер: число мест вне границ (car_seats_out_of_range) — текст под полем «Вместимость»', (tester) async {
    await open(
      tester,
      picker: (_) async => stsFile(),
      routes: {
        'POST /cars': (400, {'code': 'car_seats_out_of_range', 'message': 'x'}),
        'POST /files': (201, {'id': 'f1', 'url': 'http://test/f1'}),
      },
    );
    await fillForm(tester);
    await addSts(tester);
    await tester.tap(find.byType(AppButton));
    await settle(tester);
    expect(fieldError(tester, 'Вместимость'), 'У легкового — от 1 до 8 мест');
    expect(find.text('Не удалось выполнить действие. Повторите попытку.'), findsNothing);
  });

  testWidgets('авто создано, загрузка СТС упала: поля заблокированы, повтор грузит только СТС', (tester) async {
    var filesCalls = 0;
    final env = await open(
      tester,
      picker: (_) async => stsFile(),
      routes: {
        'POST /cars': (201, carJson(id: 'c9')),
        'POST /files': (options) => ++filesCalls == 1 ? (500, {'code': 'internal', 'message': 'x'}) : (201, {'id': 'f1', 'url': 'u'}),
        'POST /cars/c9/documents': carJson(id: 'c9'),
      },
    );
    await fillForm(tester);
    await addSts(tester);
    await tester.tap(find.byType(AppButton));
    await settle(tester);
    expect(find.text('Не удалось выполнить действие. Повторите попытку.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10)); // снэкбар уходит с кнопки
    // поля не принимают правок: нажатие на «Марку» листа не открывает
    await tester.tap(field('Марка'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Выбрать марку автомобиля'), findsNothing);
    await tester.tap(find.byType(AppButton));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(env.adapter.requests.where((r) => r.method == 'POST' && r.path == '/cars'), hasLength(1));
    expect(env.adapter.requests.where((r) => r.path == '/cars/c9/documents'), hasLength(1));
    expect(env.result, ['c9']);
  });

  testWidgets('СТС: «Добавить» открывает экран СТС, «Сделать фото» берёт снимок у системы', (tester) async {
    final sources = <ImageSource>[];
    await open(tester, picker: (source) async {
      sources.add(source);
      return XFile('/nonexistent/sts.jpg');
    });
    await tester.tap(find.byKey(const Key('cars-add-sts')));
    await tester.pumpAndSettle();
    expect(find.text('Загрузите фото документа автомобиля'), findsOneWidget);
    await tester.tap(find.text('Сделать фото'));
    await tester.pumpAndSettle();
    expect(find.text('Загрузка фотографии'), findsOneWidget);
    await tester.tap(find.text('Камера'));
    await tester.pumpAndSettle();
    expect(sources, [ImageSource.camera]);
    expect(find.text('Добавление нового ТС'), findsOneWidget);
  });
}
