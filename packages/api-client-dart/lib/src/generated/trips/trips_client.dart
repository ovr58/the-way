// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/cancel_preview.dart';
import '../models/cancel_result.dart';
import '../models/driver_trip_card.dart';
import '../models/list_status.dart';
import '../models/reverse_input.dart';
import '../models/route_template.dart';
import '../models/route_template_input.dart';
import '../models/seats_input.dart';
import '../models/trip_card.dart';
import '../models/trip_details.dart';
import '../models/trip_input.dart';
import '../models/trip_kind.dart';
import '../models/trip_limits.dart';
import '../models/trip_patch.dart';
import '../models/vehicle_kind.dart';

part 'trips_client.g.dart';

@RestApi()
abstract class TripsClient {
  factory TripsClient(Dio dio, {String? baseUrl}) = _TripsClient;

  @GET('/trips')
  Future<List<TripCard>> searchTrips({
    @Query('fromCityId') int? fromCityId,
    @Query('toCityId') int? toCityId,
    @Query('lat') num? lat,
    @Query('lng') num? lng,
    @Query('near') bool? near,
    @Query('kind') TripKind? kind,
    @Query('vehicleKind') VehicleKind? vehicleKind,
  });

  @POST('/trips')
  Future<TripDetails> createTrip({
    @Body() required TripInput body,
  });

  @GET('/trips/mine')
  Future<List<DriverTripCard>> myTrips({
    @Query('status') required ListStatus status,
  });

  @GET('/trips/limits')
  Future<TripLimits> tripLimits({
    @Query('carId') required String carId,
    @Query('date') required String date,
  });

  @GET('/trips/{id}')
  Future<TripDetails> getTrip({
    @Path('id') required String id,
  });

  @PATCH('/trips/{id}')
  Future<TripDetails> updateTrip({
    @Path('id') required String id,
    @Body() required TripPatch body,
  });

  @POST('/trips/{id}/reverse')
  Future<TripDetails> reverseTrip({
    @Path('id') required String id,
    @Body() required ReverseInput body,
  });

  @POST('/trips/{id}/seats')
  Future<TripDetails> setTripSeats({
    @Path('id') required String id,
    @Body() required SeatsInput body,
  });

  @POST('/trips/{id}/close-intake')
  Future<TripDetails> closeTripIntake({
    @Path('id') required String id,
  });

  @GET('/trips/{id}/cancel-preview')
  Future<CancelPreview> tripCancelPreview({
    @Path('id') required String id,
  });

  @POST('/trips/{id}/cancel')
  Future<CancelResult> cancelTrip({
    @Path('id') required String id,
  });

  @GET('/route-templates')
  Future<List<RouteTemplate>> listRouteTemplates();

  @POST('/route-templates')
  Future<RouteTemplate> createRouteTemplate({
    @Body() required RouteTemplateInput body,
  });

  @DELETE('/route-templates/{id}')
  Future<void> deleteRouteTemplate({
    @Path('id') required String id,
  });
}
