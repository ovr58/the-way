import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../app/search_key.dart';

/// Модель автомобиля из каталога.
class CarModel {
  const CarModel({required this.id, required this.name, required this.cyrillicName});

  factory CarModel.fromJson(Map<String, Object?> json) => CarModel(
        id: json['id']! as String,
        name: json['name']! as String,
        cyrillicName: json['cyrillicName']! as String,
      );

  final String id;
  final String name;
  final String cyrillicName;
}

/// Модель ищется по вхождению (цифры из середины индекса), марка — по началу названия («Добавление нового ТС»);
/// сравнение по ключу поиска — латиница и кириллица.
bool _matches(String query, String name, String cyrillicName, {bool prefix = false}) {
  final q = searchKey(query.trim());
  bool hit(String s) => prefix ? searchKey(s).startsWith(q) : searchKey(s).contains(q);
  return hit(name) || hit(cyrillicName);
}

/// Марка автомобиля из каталога с её моделями.
class CarBrand {
  const CarBrand({
    required this.id,
    required this.name,
    required this.cyrillicName,
    required this.popular,
    required this.models,
  });

  factory CarBrand.fromJson(Map<String, Object?> json) => CarBrand(
        id: json['id']! as String,
        name: json['name']! as String,
        cyrillicName: json['cyrillicName']! as String,
        popular: json['popular']! as bool,
        models: [
          for (final m in json['models']! as List<Object?>) CarModel.fromJson(m! as Map<String, Object?>),
        ],
      );

  final String id;
  final String name;
  final String cyrillicName;
  final bool popular;
  final List<CarModel> models;

  /// Модели, чьё название (латиницей или кириллицей) содержит [query]; пустой запрос — все.
  /// Сначала модели, начинающиеся с запроса.
  List<CarModel> searchModels(String query) => prefixFirst(
        query,
        [for (final m in models) if (_matches(query, m.name, m.cyrillicName)) m],
        (CarModel m) => m.name,
      );
}

/// Каталог марок и моделей: `assets/data/car_catalog.json` (сборка — `tools/data/build-car-catalog.mjs`).
/// Популярные марки идут первыми — так лежат в файле.
class CarCatalog {
  const CarCatalog(this.brands);

  static const asset = 'assets/data/car_catalog.json';

  final List<CarBrand> brands;

  static Future<CarCatalog> load(AssetBundle bundle) async {
    final text = await bundle.loadString(asset);
    final list = jsonDecode(text) as List<Object?>;
    return CarCatalog([for (final b in list) CarBrand.fromJson(b! as Map<String, Object?>)]);
  }

  /// Марки, чьё название (латиницей или кириллицей) начинается с [query]; пустой запрос — все.
  List<CarBrand> searchBrands(String query) =>
      [for (final b in brands) if (_matches(query, b.name, b.cyrillicName, prefix: true)) b];
}
