// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';

import 'auth/auth_client.dart';
import 'users/users_client.dart';
import 'cities/cities_client.dart';
import 'files/files_client.dart';
import 'cars/cars_client.dart';
import 'trips/trips_client.dart';
import 'bookings/bookings_client.dart';
import 'orders/orders_client.dart';
import 'reviews/reviews_client.dart';
import 'geo/geo_client.dart';
import 'logs/logs_client.dart';

/// The Way API `v1.0.0`.
///
/// Контракт порождается из кода (`npm run openapi:emit`).
class TheWayApi {
  TheWayApi(
    Dio dio, {
    String? baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  final Dio _dio;
  final String? _baseUrl;

  static String get version => '1.0.0';

  AuthClient? _auth;
  UsersClient? _users;
  CitiesClient? _cities;
  FilesClient? _files;
  CarsClient? _cars;
  TripsClient? _trips;
  BookingsClient? _bookings;
  OrdersClient? _orders;
  ReviewsClient? _reviews;
  GeoClient? _geo;
  LogsClient? _logs;

  AuthClient get auth => _auth ??= AuthClient(_dio, baseUrl: _baseUrl);

  UsersClient get users => _users ??= UsersClient(_dio, baseUrl: _baseUrl);

  CitiesClient get cities => _cities ??= CitiesClient(_dio, baseUrl: _baseUrl);

  FilesClient get files => _files ??= FilesClient(_dio, baseUrl: _baseUrl);

  CarsClient get cars => _cars ??= CarsClient(_dio, baseUrl: _baseUrl);

  TripsClient get trips => _trips ??= TripsClient(_dio, baseUrl: _baseUrl);

  BookingsClient get bookings => _bookings ??= BookingsClient(_dio, baseUrl: _baseUrl);

  OrdersClient get orders => _orders ??= OrdersClient(_dio, baseUrl: _baseUrl);

  ReviewsClient get reviews => _reviews ??= ReviewsClient(_dio, baseUrl: _baseUrl);

  GeoClient get geo => _geo ??= GeoClient(_dio, baseUrl: _baseUrl);

  LogsClient get logs => _logs ??= LogsClient(_dio, baseUrl: _baseUrl);
}
