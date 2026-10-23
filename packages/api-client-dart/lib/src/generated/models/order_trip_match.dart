// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'trip_card.dart';

part 'order_trip_match.g.dart';

@JsonSerializable()
class OrderTripMatch {
  const OrderTripMatch({
    required this.trip,
    required this.fromIdx,
    required this.toIdx,
    required this.priceTotal,
  });
  
  factory OrderTripMatch.fromJson(Map<String, Object?> json) => _$OrderTripMatchFromJson(json);
  
  final TripCard trip;
  final int fromIdx;
  final int toIdx;
  final int priceTotal;

  Map<String, Object?> toJson() => _$OrderTripMatchToJson(this);
}
