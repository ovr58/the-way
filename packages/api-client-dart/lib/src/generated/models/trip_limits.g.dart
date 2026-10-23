// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_limits.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TripLimits _$TripLimitsFromJson(Map<String, dynamic> json) => TripLimits(
  forwardUsed: (json['forwardUsed'] as num).toInt(),
  reverseUsed: (json['reverseUsed'] as num).toInt(),
  weekUsed: (json['weekUsed'] as num).toInt(),
  weekLimit: (json['weekLimit'] as num).toInt(),
  maxDaysAhead: (json['maxDaysAhead'] as num).toInt(),
);

Map<String, dynamic> _$TripLimitsToJson(TripLimits instance) =>
    <String, dynamic>{
      'forwardUsed': instance.forwardUsed,
      'reverseUsed': instance.reverseUsed,
      'weekUsed': instance.weekUsed,
      'weekLimit': instance.weekLimit,
      'maxDaysAhead': instance.maxDaysAhead,
    };
