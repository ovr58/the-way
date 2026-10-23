// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'place.dart';

part 'geo_suggestion.g.dart';

@JsonSerializable()
class GeoSuggestion {
  const GeoSuggestion({
    required this.label,
    required this.shortLabel,
    required this.lat,
    required this.lng,
    required this.place,
  });
  
  factory GeoSuggestion.fromJson(Map<String, Object?> json) => _$GeoSuggestionFromJson(json);
  
  final String label;
  final String shortLabel;
  final num lat;
  final num lng;
  final Place place;

  Map<String, Object?> toJson() => _$GeoSuggestionToJson(this);
}
