import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

/// Снимки экранов для сверки с кадрами макета.
///
/// Логический размер 375×H, pixelRatio 2 — как выгрузка кадров Penpot (750×1624 для H = 812).
/// PNG пишутся в `build/screens/kNN.png` (папка в .gitignore). Тесты-снимки ничего не
/// утверждают о виде: единственная проверка — Gilroy загрузилась ([loadShotFonts]).

const _width = 375.0;
const _ratio = 2.0;
final _boundaryKey = GlobalKey(debugLabel: 'shot-boundary');

/// Общая подготовка файла снимков, вызывается первой строкой `main()`: шрифт, фото по сети, без ленты debug.
void shotInit() => setUpAll(_shotSetUp);

Future<void> _shotSetUp() async {
  WidgetsApp.debugAllowBannerOverride = false; // лента debug в углу не часть экрана
  await loadShotFonts();
  servePhotos();
}

/// Подгружает все шрифты сборки из `FontManifest.json` — Gilroy и шрифт значков MaterialIcons (без него
/// значки `Icons.*` и стрелки календаря рисуются квадратами, тема tofu-glyphs) — и убеждается, что Gilroy
/// настоящий. Без шрифта тест рисует Ahem (буква — квадрат, все ширины равны), снимок был бы браком;
/// поэтому здесь падение, а не молчание.
Future<void> loadShotFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<Object?>;
  for (final family in manifest.cast<Map<String, Object?>>()) {
    final loader = FontLoader(family['family']! as String);
    for (final font in (family['fonts']! as List<Object?>).cast<Map<String, Object?>>()) {
      loader.addFont(rootBundle.load(font['asset']! as String));
    }
    await loader.load();
  }
  double width(String s) => (TextPainter(
        text: TextSpan(text: s, style: const TextStyle(fontFamily: 'Gilroy', fontSize: 20)),
        textDirection: TextDirection.ltr,
      )..layout())
          .width;
  if (width('i') == width('W') || width('и') == width('Ж')) {
    throw StateError('Gilroy не загрузилась: ширины букв равны (шрифт-заглушка Ahem)');
  }
}

/// Размер поверхности: 375×[height] логических точек (по умолчанию 812, как кадр).
void shotSurface(WidgetTester tester, {double height = 812}) {
  // Переполнение вёрстки — дефект приложения, а не снимка: не роняем тест (полосы переполнения видны
  // на снимке), строка идёт в лог. Всё остальное по-прежнему падает.
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (!text.contains('overflowed')) return previous?.call(details);
    final line = text.split(RegExp(r'[\r\n]')).first;
    if (_noted.add(line)) stdout.writeln('SHOT-OVERFLOW $line');
  };
  tester.view
    ..physicalSize = Size(_width * _ratio, height * _ratio)
    ..devicePixelRatio = _ratio;
  addTearDown(tester.view.reset);
}

/// Оборачивает приложение в границу перерисовки, с которой снимается PNG.
Widget shotRoot(Widget app) => RepaintBoundary(key: _boundaryKey, child: app);

/// Доводит дерево до устойчивого вида: картинки ассетов и сети декодируются, SVG загружаются.
/// Бесконечные анимации (индикаторы загрузки) не мешают — это фиксированные паузы, не settle.
Future<void> shotSettle(WidgetTester tester) async {
  // Тестовая среда рисует тени сплошным чёрным: на время снимка включаем настоящие и перерисовываем
  // всё дерево; [shoot] возвращает значение (проверка среды в конце теста требует исходное).
  debugDisableShadows = false;
  void repaint(RenderObject o) {
    o.markNeedsPaint();
    o.visitChildren(repaint);
  }

  repaint(tester.binding.renderViews.first);
  await tester.pump();
  _takeOverflow(tester);
  final context = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    for (final file in Directory('assets/images').listSync().whereType<File>()) {
      if (!context.mounted || !file.path.endsWith('.webp')) continue;
      await precacheImage(AssetImage(file.path.replaceAll(r'\', '/')), context);
    }
  });
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 60));
    _takeOverflow(tester);
  }
  await tester.pump(const Duration(milliseconds: 400)); // анимации появления
  _takeOverflow(tester);
}

/// Переполнение вёрстки (RenderFlex overflowed) — дефект приложения, а не снимка: снимок остаётся
/// (полосы переполнения видны на нём), строка идёт в лог. Любая другая ошибка по-прежнему роняет тест.
void _takeOverflow(WidgetTester tester) {
  final error = tester.takeException();
  if (error == null) return;
  if (!error.toString().contains('overflowed')) throw error;
  final line = error.toString().split(RegExp(r'[\r\n]')).first;
  if (_noted.add(line)) stdout.writeln('SHOT-OVERFLOW $line');
}

final _noted = <String>{};

/// Снимает PNG экрана в `build/screens/<code>.png`.
Future<void> shoot(WidgetTester tester, String code) async {
  await shotSettle(tester);
  final boundary = _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/screens/$code.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
  debugDisableShadows = true;
}

// ---- фото по сети: подставные байты вместо запросов к API -------------------------------------

/// Фото по последней части пути `/files/<имя>` (id — в `world.dart`): у каждого человека и авто своё.
/// Портреты — из `design/images` (кому какой в кадрах — `design/images/index.json`): я — `photo-acd9`
/// (кадры профиля), Виктор О. — `photo-ace6` (водитель «Детали поездки - Мест нет» – «Отлик»), Павел С. — `photo-acea` (пассажир
/// «Профиль - Профиль пассажира» – «Бронь отклонена»), Алексей Р. — `photo-acdc`, Александр П. — `photo-ace3`, Дмитрий С. — `photo-aceb`;
/// Ольга Н. — второй женский портрет seed (`avatar-olga.jpg`, в макете женский портрет один). Авто:
/// Toyota — `frame-acdd` (кадры «Новый заказ - Выбор авто - есть авто», «Детали поездки - Мест нет», «Транспортные средства»), Hyundai Solaris и Kia Rio — фото seed.
const _photoFiles = {
  'photo-me': '../../design/images/photo-acd9.webp',
  'photo-d1': '../../design/images/photo-ace6.webp',
  'photo-p1': '../../design/images/photo-acea.webp',
  'photo-p2': '../api/seed/data/media/avatar-olga.jpg',
  'photo-p3': '../../design/images/photo-acdc.webp',
  'photo-d-f2': '../../design/images/photo-ace3.webp',
  'photo-d-f3': '../../design/images/photo-aceb.webp',
  'car-c2': '../api/seed/data/media/car-solaris.jpg',
  'car-c3': '../api/seed/data/media/car-rio.jpg',
};
const _otherPortrait = '../../design/images/photo-acea.webp';
const _otherCar = '../../design/images/frame-acdd.webp';

/// Фото людей и автомобилей приходят по API (`Image.network`); в тесте сети нет — отдаём файлы
/// [_photoFiles]; незнакомое имя — портрет или Toyota. Вызывать в `setUpAll`.
void servePhotos() {
  final cache = <String, Uint8List>{};
  HttpOverrides.global = _PhotoOverrides((path) {
    final name = path.split('/').last;
    final file = _photoFiles[name] ?? (name.startsWith('car') ? _otherCar : _otherPortrait);
    return cache[file] ??= File(file).readAsBytesSync();
  });
}

class _PhotoOverrides extends HttpOverrides {
  _PhotoOverrides(this.photo);

  final Uint8List Function(String path) photo;

  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client(this);
}

class _Client implements HttpClient {
  _Client(this.photos);

  final _PhotoOverrides photos;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(photos.photo(url.path));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  _Request(this.bytes);

  final Uint8List bytes;

  @override
  HttpHeaders get headers => _Headers();

  @override
  Future<HttpClientResponse> close() async => _Response(bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.bytes);

  final Uint8List bytes;

  @override
  int get statusCode => 200;

  @override
  int get contentLength => bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(bytes).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}


/// Растягивает поверхность на длину прокрутки первого видимого списка: снимок полной высоты
/// контента (кадры длиннее экрана). Если приложение длиннее кадра, снимок получится выше кадра.
Future<void> shotExpand(WidgetTester tester) async {
  final extra = tester.state<ScrollableState>(find.byType(Scrollable).first).position.maxScrollExtent;
  if (extra <= 0) return;
  final height = tester.view.physicalSize.height / _ratio + extra.ceilToDouble();
  tester.view.physicalSize = Size(_width * _ratio, height * _ratio);
  await tester.pump();
}

/// Растягивает поверхность, пока шторка поверх экрана (последний прокручиваемый список) не уместится
/// целиком: снимок шторки длиннее экрана без прокрутки («Бронирование», «Бронирование - С доп услугами» — шторка кадра 375×1156 при доске 812).
/// Высота шторки ограничена долей экрана, поэтому растёт шагами, пока прокручивать нечего.
Future<void> shotExpandSheet(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    final position = tester.state<ScrollableState>(find.byType(Scrollable).last).position;
    if (position.maxScrollExtent <= 0) {
      position.jumpTo(0);
      await tester.pump();
      return;
    }
    final height = tester.view.physicalSize.height / _ratio + position.maxScrollExtent.ceilToDouble() + 1;
    tester.view.physicalSize = Size(_width * _ratio, height * _ratio);
    await tester.pump();
  }
}

/// Положение телефона для снимка: геолокация включена, разрешение «пока используется», точка [lat],
/// [lng] («поиск адреса» — строка «Ближайшая ко мне»). Код приложения не подменяется — только платформа
/// `geolocator`; прежняя возвращается после теста.
void shotLocation(double lat, double lng) {
  final previous = GeolocatorPlatform.instance;
  GeolocatorPlatform.instance = _ShotGeolocator(lat, lng);
  addTearDown(() => GeolocatorPlatform.instance = previous);
}

class _ShotGeolocator extends GeolocatorPlatform {
  _ShotGeolocator(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.whileInUse;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async => Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.utc(2026, 5, 15),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

/// Возвращает поверхности высоту [height] (после [shotExpand] или [shotExpandSheet]).
Future<void> shotResize(WidgetTester tester, {double height = 812}) async {
  tester.view.physicalSize = Size(_width * _ratio, height * _ratio);
  await tester.pump();
}

/// Ждёт, пока [finder] найдёт виджет (данные из ассета и сети приходят настоящим вводом-выводом).
Future<void> shotWaitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Забирает отложенное переполнение вёрстки после ручного `pump` (см. [shotSettle]).
void shotTake(WidgetTester tester) => _takeOverflow(tester);
