// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'health_result.g.dart';

@JsonSerializable()
class HealthResult {
  const HealthResult({
    required this.ok,
  });
  
  factory HealthResult.fromJson(Map<String, Object?> json) => _$HealthResultFromJson(json);
  
  final bool ok;

  Map<String, Object?> toJson() => _$HealthResultToJson(this);
}
