// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'booking_mode.dart';
import 'extra.dart';
import 'price.dart';
import 'stop_input.dart';
import 'trip_kind.dart';
import 'vehicle_kind.dart';

part 'trip_patch.g.dart';

@JsonSerializable()
class TripPatch {
  const TripPatch({
    required this.kind,
    required this.vehicleKind,
    required this.stops,
    required this.departsAt,
    required this.arrivesAt,
    required this.seatsTotal,
    required this.priceFull,
    required this.prices,
    required this.priceBoardingMin,
    required this.carId,
    required this.extras,
    required this.parcelOnlyAllowed,
    required this.parcelSeatsTotal,
    required this.bookingMode,
  });
  
  factory TripPatch.fromJson(Map<String, Object?> json) => _$TripPatchFromJson(json);
  
  final TripKind kind;
  final VehicleKind vehicleKind;
  final List<StopInput> stops;
  final DateTime departsAt;
  final DateTime arrivesAt;
  final int seatsTotal;
  final int priceFull;
  final List<Price> prices;
  final int priceBoardingMin;
  final String carId;
  final List<Extra> extras;
  final bool parcelOnlyAllowed;
  final int parcelSeatsTotal;
  final BookingMode bookingMode;

  Map<String, Object?> toJson() => _$TripPatchToJson(this);
}
