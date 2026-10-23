// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'car_document_kind.dart';

part 'car_document.g.dart';

@JsonSerializable()
class CarDocument {
  const CarDocument({
    required this.id,
    required this.kind,
    required this.url,
  });
  
  factory CarDocument.fromJson(Map<String, Object?> json) => _$CarDocumentFromJson(json);
  
  final String id;
  final CarDocumentKind kind;
  final String url;

  Map<String, Object?> toJson() => _$CarDocumentToJson(this);
}
