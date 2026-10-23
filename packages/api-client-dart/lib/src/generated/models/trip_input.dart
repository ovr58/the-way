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

part 'trip_input.g.dart';

@JsonSerializable()
class TripInput {
  const TripInput({
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
    this.orderId,
  });
  
  factory TripInput.fromJson(Map<String, Object?> json) => _$TripInputFromJson(json);
  
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
  final String? orderId;

  Map<String, Object?> toJson() => _$TripInputToJson(this);
}
