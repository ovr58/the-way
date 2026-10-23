// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stop_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StopInput _$StopInputFromJson(Map<String, dynamic> json) => StopInput(
  address: json['address'] as String,
  cityId: (json['cityId'] as num?)?.toInt(),
  place: json['place'] == null
      ? null
      : Place.fromJson(json['place'] as Map<String, dynamic>),
  shortAddress: json['shortAddress'] as String?,
  lat: json['lat'] as num?,
  lng: json['lng'] as num?,
);

Map<String, dynamic> _$StopInputToJson(StopInput instance) => <String, dynamic>{
  'cityId': instance.cityId,
  'place': instance.place,
  'address': instance.address,
  'shortAddress': instance.shortAddress,
  'lat': instance.lat,
  'lng': instance.lng,
};
