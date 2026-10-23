// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'file_ref.g.dart';

@JsonSerializable()
class FileRef {
  const FileRef({
    required this.id,
    required this.url,
  });
  
  factory FileRef.fromJson(Map<String, Object?> json) => _$FileRefFromJson(json);
  
  final String id;
  final String url;

  Map<String, Object?> toJson() => _$FileRefToJson(this);
}
