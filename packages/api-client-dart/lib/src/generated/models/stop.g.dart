// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stop.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Stop _$StopFromJson(Map<String, dynamic> json) => Stop(
  idx: (json['idx'] as num).toInt(),
  cityId: (json['cityId'] as num).toInt(),
  cityName: json['cityName'] as String,
  address: json['address'] as String,
  shortAddress: json['shortAddress'] as String,
  lat: json['lat'] as num?,
  lng: json['lng'] as num?,
);

Map<String, dynamic> _$StopToJson(Stop instance) => <String, dynamic>{
  'idx': instance.idx,
  'cityId': instance.cityId,
  'cityName': instance.cityName,
  'address': instance.address,
  'shortAddress': instance.shortAddress,
  'lat': instance.lat,
  'lng': instance.lng,
};
