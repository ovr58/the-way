// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'car_document_kind.dart';

part 'car_document_input.g.dart';

@JsonSerializable()
class CarDocumentInput {
  const CarDocumentInput({
    required this.fileId,
    required this.kind,
  });
  
  factory CarDocumentInput.fromJson(Map<String, Object?> json) => _$CarDocumentInputFromJson(json);
  
  final String fileId;
  final CarDocumentKind kind;

  Map<String, Object?> toJson() => _$CarDocumentInputToJson(this);
}
