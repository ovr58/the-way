// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rating.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Rating _$RatingFromJson(Map<String, dynamic> json) =>
    Rating(value: json['value'] as num, count: (json['count'] as num).toInt());

Map<String, dynamic> _$RatingToJson(Rating instance) => <String, dynamic>{
  'value': instance.value,
  'count': instance.count,
};
