// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CarDocument _$CarDocumentFromJson(Map<String, dynamic> json) => CarDocument(
  id: json['id'] as String,
  kind: CarDocumentKind.fromJson(json['kind'] as String),
  url: json['url'] as String,
);

Map<String, dynamic> _$CarDocumentToJson(CarDocument instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': _$CarDocumentKindEnumMap[instance.kind]!,
      'url': instance.url,
    };

const _$CarDocumentKindEnumMap = {
  CarDocumentKind.sts: 'sts',
  CarDocumentKind.$unknown: r'$unknown',
};
