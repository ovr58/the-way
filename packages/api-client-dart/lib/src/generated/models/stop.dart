// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'stop.g.dart';

@JsonSerializable()
class Stop {
  const Stop({
    required this.idx,
    required this.cityId,
    required this.cityName,
    required this.address,
    required this.shortAddress,
    this.lat,
    this.lng,
  });
  
  factory Stop.fromJson(Map<String, Object?> json) => _$StopFromJson(json);
  
  final int idx;
  final int cityId;
  final String cityName;
  final String address;
  final String shortAddress;
  final num? lat;
  final num? lng;

  Map<String, Object?> toJson() => _$StopToJson(this);
}
