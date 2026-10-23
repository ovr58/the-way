// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/booking.dart';
import '../models/booking_input.dart';
import '../models/cancel_preview.dart';
import '../models/cancel_result.dart';
import '../models/list_status.dart';
import '../models/parcel_size.dart';
import '../models/quote.dart';
import '../models/update.dart';

part 'bookings_client.g.dart';

@RestApi()
abstract class BookingsClient {
  factory BookingsClient(Dio dio, {String? baseUrl}) = _BookingsClient;

  @GET('/trips/{id}/quote')
  Future<Quote> quoteBooking({
    @Path('id') required String id,
    @Query('fromIdx') required int fromIdx,
    @Query('toIdx') required int toIdx,
    @Query('seats') required int seats,
    @Query('parcelSize') ParcelSize? parcelSize,
    @Query('extras') String? extras,
  });

  @POST('/trips/{id}/bookings')
  Future<Booking> createBooking({
    @Path('id') required String id,
    @Body() required BookingInput body,
  });

  @GET('/trips/{id}/bookings')
  Future<List<Booking>> tripBookings({
    @Path('id') required String id,
  });

  @GET('/bookings/mine')
  Future<List<Booking>> myBookings({
    @Query('status') ListStatus? status,
  });

  @GET('/bookings/{id}')
  Future<Booking> getBooking({
    @Path('id') required String id,
  });

  @POST('/bookings/{id}/confirm')
  Future<Booking> confirmBooking({
    @Path('id') required String id,
  });

  @POST('/bookings/{id}/reject')
  Future<Booking> rejectBooking({
    @Path('id') required String id,
  });

  @POST('/bookings/{id}/pay')
  Future<Booking> payBooking({
    @Path('id') required String id,
  });

  @GET('/bookings/{id}/cancel-preview')
  Future<CancelPreview> bookingCancelPreview({
    @Path('id') required String id,
  });

  @POST('/bookings/{id}/cancel')
  Future<CancelResult> cancelBooking({
    @Path('id') required String id,
  });

  @GET('/updates')
  Future<List<Update>> listUpdates();

  @POST('/updates/{bookingId}/seen')
  Future<void> markUpdateSeen({
    @Path('bookingId') required String bookingId,
  });
}
