// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/booking.dart';
import '../models/order_card.dart';
import '../models/order_details.dart';
import '../models/order_input.dart';
import '../models/order_response_input.dart';
import '../models/trip_kind.dart';

part 'orders_client.g.dart';

@RestApi()
abstract class OrdersClient {
  factory OrdersClient(Dio dio, {String? baseUrl}) = _OrdersClient;

  @POST('/orders')
  Future<OrderDetails> createOrder({
    @Body() required OrderInput body,
  });

  @GET('/orders')
  Future<List<OrderCard>> searchOrders({
    @Query('fromCityId') int? fromCityId,
    @Query('toCityId') int? toCityId,
    @Query('lat') num? lat,
    @Query('lng') num? lng,
    @Query('near') bool? near,
    @Query('kind') TripKind? kind,
  });

  @GET('/orders/mine')
  Future<List<OrderCard>> myOrders();

  @GET('/orders/{id}')
  Future<OrderDetails> getOrder({
    @Path('id') required String id,
  });

  @POST('/orders/{id}/cancel')
  Future<OrderDetails> cancelOrder({
    @Path('id') required String id,
  });

  @POST('/orders/{id}/respond')
  Future<Booking> respondToOrder({
    @Path('id') required String id,
    @Body() required OrderResponseInput body,
  });
}
