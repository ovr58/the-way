// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'car_document.dart';
import 'car_status.dart';
import 'vehicle_kind.dart';

part 'car.g.dart';

@JsonSerializable()
class Car {
  const Car({
    required this.id,
    required this.brand,
    required this.model,
    required this.kind,
    required this.seats,
    required this.plate,
    required this.status,
    required this.documents,
    this.photoUrl,
  });
  
  factory Car.fromJson(Map<String, Object?> json) => _$CarFromJson(json);
  
  final String id;
  final String brand;
  final String model;
  final VehicleKind kind;
  final int seats;
  final String plate;
  final String? photoUrl;
  final CarStatus status;
  final List<CarDocument> documents;

  Map<String, Object?> toJson() => _$CarToJson(this);
}
