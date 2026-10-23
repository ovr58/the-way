// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/geo_suggestion.dart';

part 'geo_client.g.dart';

@RestApi()
abstract class GeoClient {
  factory GeoClient(Dio dio, {String? baseUrl}) = _GeoClient;

  @GET('/geo/suggest')
  Future<List<GeoSuggestion>> suggestAddress({
    @Query('q') required String q,
    @Query('cityId') int? cityId,
  });
}
