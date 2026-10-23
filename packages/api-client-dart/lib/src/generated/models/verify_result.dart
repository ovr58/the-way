// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'me.dart';

part 'verify_result.g.dart';

@JsonSerializable()
class VerifyResult {
  const VerifyResult({
    required this.token,
    required this.isNew,
    required this.me,
  });
  
  factory VerifyResult.fromJson(Map<String, Object?> json) => _$VerifyResultFromJson(json);
  
  final String token;
  final bool isNew;
  final Me me;

  Map<String, Object?> toJson() => _$VerifyResultToJson(this);
}
