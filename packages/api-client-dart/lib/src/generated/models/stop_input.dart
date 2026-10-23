// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'place.dart';

part 'stop_input.g.dart';

@JsonSerializable()
class StopInput {
  const StopInput({
    required this.address,
    this.cityId,
    this.place,
    this.shortAddress,
    this.lat,
    this.lng,
  });
  
  factory StopInput.fromJson(Map<String, Object?> json) => _$StopInputFromJson(json);
  
  final int? cityId;
  final Place? place;
  final String address;
  final String? shortAddress;
  final num? lat;
  final num? lng;

  Map<String, Object?> toJson() => _$StopInputToJson(this);
}
