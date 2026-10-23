// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/car.dart';
import '../models/car_document_input.dart';
import '../models/car_input.dart';
import '../models/car_patch.dart';

part 'cars_client.g.dart';

@RestApi()
abstract class CarsClient {
  factory CarsClient(Dio dio, {String? baseUrl}) = _CarsClient;

  @GET('/cars')
  Future<List<Car>> listCars();

  @POST('/cars')
  Future<Car> createCar({
    @Body() required CarInput body,
  });

  @PATCH('/cars/{id}')
  Future<Car> updateCar({
    @Path('id') required String id,
    @Body() required CarPatch body,
  });

  @DELETE('/cars/{id}')
  Future<void> deleteCar({
    @Path('id') required String id,
  });

  @POST('/cars/{id}/documents')
  Future<Car> addCarDocument({
    @Path('id') required String id,
    @Body() required CarDocumentInput body,
  });
}
