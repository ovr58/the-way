// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Car _$CarFromJson(Map<String, dynamic> json) => Car(
  id: json['id'] as String,
  brand: json['brand'] as String,
  model: json['model'] as String,
  kind: VehicleKind.fromJson(json['kind'] as String),
  seats: (json['seats'] as num).toInt(),
  plate: json['plate'] as String,
  status: CarStatus.fromJson(json['status'] as String),
  documents: (json['documents'] as List<dynamic>)
      .map((e) => CarDocument.fromJson(e as Map<String, dynamic>))
      .toList(),
  photoUrl: json['photoUrl'] as String?,
);

Map<String, dynamic> _$CarToJson(Car instance) => <String, dynamic>{
  'id': instance.id,
  'brand': instance.brand,
  'model': instance.model,
  'kind': _$VehicleKindEnumMap[instance.kind]!,
  'seats': instance.seats,
  'plate': instance.plate,
  'photoUrl': instance.photoUrl,
  'status': _$CarStatusEnumMap[instance.status]!,
  'documents': instance.documents,
};

const _$VehicleKindEnumMap = {
  VehicleKind.car: 'car',
  VehicleKind.bus: 'bus',
  VehicleKind.$unknown: r'$unknown',
};

const _$CarStatusEnumMap = {
  CarStatus.pending: 'pending',
  CarStatus.verified: 'verified',
  CarStatus.rejected: 'rejected',
  CarStatus.$unknown: r'$unknown',
};
