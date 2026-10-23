// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/city.dart';

part 'cities_client.g.dart';

@RestApi()
abstract class CitiesClient {
  factory CitiesClient(Dio dio, {String? baseUrl}) = _CitiesClient;

  @GET('/cities')
  Future<List<City>> listCities({
    @Query('q') String? q,
  });
}
