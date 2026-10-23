// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'trip_limits.g.dart';

@JsonSerializable()
class TripLimits {
  const TripLimits({
    required this.forwardUsed,
    required this.reverseUsed,
    required this.weekUsed,
    required this.weekLimit,
    required this.maxDaysAhead,
  });
  
  factory TripLimits.fromJson(Map<String, Object?> json) => _$TripLimitsFromJson(json);
  
  final int forwardUsed;
  final int reverseUsed;
  final int weekUsed;
  final int weekLimit;
  final int maxDaysAhead;

  Map<String, Object?> toJson() => _$TripLimitsToJson(this);
}
