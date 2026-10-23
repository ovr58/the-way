// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geo_suggestion.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeoSuggestion _$GeoSuggestionFromJson(Map<String, dynamic> json) =>
    GeoSuggestion(
      label: json['label'] as String,
      shortLabel: json['shortLabel'] as String,
      lat: json['lat'] as num,
      lng: json['lng'] as num,
      place: Place.fromJson(json['place'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$GeoSuggestionToJson(GeoSuggestion instance) =>
    <String, dynamic>{
      'label': instance.label,
      'shortLabel': instance.shortLabel,
      'lat': instance.lat,
      'lng': instance.lng,
      'place': instance.place,
    };
