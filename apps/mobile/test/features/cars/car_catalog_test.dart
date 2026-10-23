import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/features/cars/data/car_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CarCatalog catalog;

  setUpAll(() async {
    catalog = await CarCatalog.load(rootBundle);
  });

  test('каталог из ассета: популярные марки идут первыми', () {
    final popular = catalog.brands.takeWhile((b) => b.popular).length;
    expect(popular, greaterThan(0));
    expect(catalog.brands.skip(popular).any((b) => b.popular), isFalse);
  });

  test('поиск марки — по латинскому и русскому названию, без учёта регистра', () {
    expect(catalog.searchBrands('toyo').map((b) => b.name), contains('Toyota'));
    expect(catalog.searchBrands('ТОЙОТ').map((b) => b.name), contains('Toyota'));
    expect(catalog.searchBrands('').length, catalog.brands.length);
    expect(catalog.searchBrands('zzzzzz'), isEmpty);
  });

  test('поиск модели внутри марки; поколения в названии нет', () {
    final toyota = catalog.searchBrands('toyota').first;
    expect(toyota.searchModels('camr').map((m) => m.name), contains('Camry'));
    expect(toyota.searchModels('камри').map((m) => m.name), contains('Camry'));
    expect(catalog.brands.expand((b) => b.models).any((m) => m.name.contains(',')), isFalse);
  });
  // «i» находит и русское название на «И» (Иж, Икспенг) — ключ поиска один для обеих азбук.
  test('поиск марки — по началу названия («Добавление нового ТС»): «i» → только марки на I или И', () {
    final found = catalog.searchBrands('i');
    final names = found.map((b) => b.name).toList();
    expect(names, containsAll(<String>['Infiniti', 'Isuzu', 'Iveco']));
    expect(names, isNot(contains('Aion')));
    expect(names, contains('Иж'));
    expect(found.every((b) => b.name.toLowerCase().startsWith('i') || b.cyrillicName.toLowerCase().startsWith('и')), isTrue);
  });

  test('поиск марки по началу русского названия', () {
    final toyota = catalog.searchBrands('тойо').map((b) => b.name);
    expect(toyota, contains('Toyota'));
    expect(catalog.searchBrands('йота'), isEmpty);
  });

  test('поиск модели — по вхождению: середина индекса находит модель', () {
    final toyota = catalog.searchBrands('toyota').first;
    expect(toyota.searchModels('amr').map((m) => m.name), contains('Camry'));
  });

  test('марка латиницей: gaz → ГАЗ, uaz → УАЗ, paz → ПАЗ; кириллицей «газ» — тоже', () {
    expect(catalog.searchBrands('gaz').map((b) => b.name), contains('ГАЗ'));
    expect(catalog.searchBrands('uaz').map((b) => b.name), contains('УАЗ'));
    expect(catalog.searchBrands('paz').map((b) => b.name), contains('ПАЗ'));
    expect(catalog.searchBrands('газ').map((b) => b.name), contains('ГАЗ'));
  });

  test('маршрутки и автобусы в каталоге', () {
    List<String> models(String brand) =>
        catalog.brands.singleWhere((b) => b.name == brand).models.map((m) => m.name).toList();
    expect(models('ГАЗ'), containsAll(<String>['ГАЗель Next', 'ГАЗель Business', 'Соболь']));
    expect(models('ПАЗ'), containsAll(<String>['3205', 'Vector Next']));
    expect(models('Ford'), contains('Transit'));
    expect(models('Mercedes-Benz'), contains('Sprinter'));
    expect(models('Peugeot'), contains('Boxer'));
    expect(models('Fiat'), contains('Ducato'));
    expect(models('Iveco'), contains('Daily'));
  });

  test('модель латиницей и кириллицей; сначала начинающиеся с запроса', () {
    final gaz = catalog.searchBrands('gaz').first;
    expect(gaz.searchModels('gazel').map((m) => m.name), contains('ГАЗель Next'));
    expect(gaz.searchModels('sobol').map((m) => m.name), contains('Соболь'));
    final mercedes = catalog.searchBrands('mercedes').first;
    final amg = mercedes.searchModels('amg').map((m) => m.name).toList();
    expect(amg.indexOf('AMG GT'), lessThan(amg.indexOf('GLC Coupe AMG')));
  });
}
