// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'vehicle_kind.dart';

part 'car_input.g.dart';

@JsonSerializable()
class CarInput {
  const CarInput({
    required this.brand,
    required this.model,
    required this.kind,
    required this.seats,
    required this.plate,
    this.photoFileId,
  });
  
  factory CarInput.fromJson(Map<String, Object?> json) => _$CarInputFromJson(json);
  
  final String brand;
  final String model;
  final VehicleKind kind;
  final int seats;
  final String plate;
  final String? photoFileId;

  Map<String, Object?> toJson() => _$CarInputToJson(this);
}
