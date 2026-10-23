// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CarInput _$CarInputFromJson(Map<String, dynamic> json) => CarInput(
  brand: json['brand'] as String,
  model: json['model'] as String,
  kind: VehicleKind.fromJson(json['kind'] as String),
  seats: (json['seats'] as num).toInt(),
  plate: json['plate'] as String,
  photoFileId: json['photoFileId'] as String?,
);

Map<String, dynamic> _$CarInputToJson(CarInput instance) => <String, dynamic>{
  'brand': instance.brand,
  'model': instance.model,
  'kind': _$VehicleKindEnumMap[instance.kind]!,
  'seats': instance.seats,
  'plate': instance.plate,
  'photoFileId': instance.photoFileId,
};

const _$VehicleKindEnumMap = {
  VehicleKind.car: 'car',
  VehicleKind.bus: 'bus',
  VehicleKind.$unknown: r'$unknown',
};
