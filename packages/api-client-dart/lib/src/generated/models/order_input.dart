// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'parcel_size.dart';
import 'service_kind.dart';
import 'stop_input.dart';
import 'trip_kind.dart';

part 'order_input.g.dart';

@JsonSerializable()
class OrderInput {
  const OrderInput({
    required this.kind,
    required this.stops,
    required this.departsAt,
    required this.arrivesAt,
    required this.seats,
    required this.parcelSize,
    required this.extras,
    this.parcelComment,
  });
  
  factory OrderInput.fromJson(Map<String, Object?> json) => _$OrderInputFromJson(json);
  
  final TripKind kind;
  final List<StopInput> stops;
  final DateTime departsAt;
  final DateTime arrivesAt;
  final int seats;
  final ParcelSize parcelSize;
  final String? parcelComment;
  final List<ServiceKind> extras;

  Map<String, Object?> toJson() => _$OrderInputToJson(this);
}
