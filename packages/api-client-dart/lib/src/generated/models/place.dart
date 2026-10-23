// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'place.g.dart';

@JsonSerializable()
class Place {
  const Place({
    required this.name,
    required this.region,
  });
  
  factory Place.fromJson(Map<String, Object?> json) => _$PlaceFromJson(json);
  
  final String name;
  final String region;

  Map<String, Object?> toJson() => _$PlaceToJson(this);
}
