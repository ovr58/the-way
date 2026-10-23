// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car_patch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CarPatch _$CarPatchFromJson(Map<String, dynamic> json) => CarPatch(
  brand: json['brand'] as String,
  model: json['model'] as String,
  kind: VehicleKind.fromJson(json['kind'] as String),
  seats: (json['seats'] as num).toInt(),
  plate: json['plate'] as String,
  photoFileId: json['photoFileId'] as String?,
);

Map<String, dynamic> _$CarPatchToJson(CarPatch instance) => <String, dynamic>{
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
