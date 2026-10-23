// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'booking.dart';
import 'booking_mode.dart';
import 'car.dart';
import 'carried_parcel_size.dart';
import 'extra.dart';
import 'price.dart';
import 'service_kind.dart';
import 'stop.dart';
import 'trip_badge.dart';
import 'trip_kind.dart';
import 'trip_status.dart';
import 'user_brief.dart';

part 'trip_details.g.dart';

@JsonSerializable()
class TripDetails {
  const TripDetails({
    required this.parcelSeatsTotal,
    required this.number,
    required this.kind,
    required this.from,
    required this.to,
    required this.stopsCount,
    required this.departsAt,
    required this.arrivesAt,
    required this.seatsFree,
    required this.seatsTotal,
    required this.parcelSeatsFree,
    required this.id,
    required this.price,
    required this.editLocked,
    required this.isMine,
    required this.driver,
    required this.extras,
    required this.parcelAllowed,
    required this.parcelSizes,
    required this.duplicates,
    required this.registrationOpen,
    required this.bookable,
    required this.parcelBookable,
    required this.car,
    required this.stops,
    required this.prices,
    required this.priceBoardingMin,
    required this.extrasPriced,
    required this.parcelOnlyAllowed,
    required this.bookingMode,
    required this.effectiveStatus,
    this.badge,
    this.distanceKm,
    this.myBooking,
    this.reverseOf,
    this.paidTotal,
  });
  
  factory TripDetails.fromJson(Map<String, Object?> json) => _$TripDetailsFromJson(json);
  
  final String id;
  final int number;
  final TripKind kind;
  final Stop from;
  final Stop to;
  final int stopsCount;
  final DateTime departsAt;
  final DateTime arrivesAt;
  final int seatsFree;
  final int seatsTotal;
  final int parcelSeatsFree;
  final int parcelSeatsTotal;
  final int price;
  final num? distanceKm;
  final TripBadge? badge;
  final UserBrief driver;
  final List<ServiceKind> extras;
  final bool parcelAllowed;
  final List<CarriedParcelSize> parcelSizes;
  final int duplicates;
  final bool registrationOpen;
  final bool bookable;
  final bool parcelBookable;
  final TripStatus effectiveStatus;
  final List<Stop> stops;
  final List<Price> prices;
  final int priceBoardingMin;
  final List<Extra> extrasPriced;
  final bool parcelOnlyAllowed;
  final BookingMode bookingMode;
  final Car car;
  final bool isMine;
  final bool editLocked;
  final Booking? myBooking;
  final String? reverseOf;
  final int? paidTotal;

  Map<String, Object?> toJson() => _$TripDetailsToJson(this);
}
