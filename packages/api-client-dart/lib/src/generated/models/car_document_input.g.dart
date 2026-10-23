// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car_document_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CarDocumentInput _$CarDocumentInputFromJson(Map<String, dynamic> json) =>
    CarDocumentInput(
      fileId: json['fileId'] as String,
      kind: CarDocumentKind.fromJson(json['kind'] as String),
    );

Map<String, dynamic> _$CarDocumentInputToJson(CarDocumentInput instance) =>
    <String, dynamic>{
      'fileId': instance.fileId,
      'kind': _$CarDocumentKindEnumMap[instance.kind]!,
    };

const _$CarDocumentKindEnumMap = {
  CarDocumentKind.sts: 'sts',
  CarDocumentKind.$unknown: r'$unknown',
};
