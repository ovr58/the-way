// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'city.g.dart';

@JsonSerializable()
class City {
  const City({
    required this.id,
    required this.name,
    required this.region,
    required this.lat,
    required this.lng,
  });
  
  factory City.fromJson(Map<String, Object?> json) => _$CityFromJson(json);
  
  final int id;
  final String name;
  final String region;
  final num lat;
  final num lng;

  Map<String, Object?> toJson() => _$CityToJson(this);
}
