// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'verify_body.g.dart';

@JsonSerializable()
class VerifyBody {
  const VerifyBody({
    required this.phone,
    required this.code,
  });
  
  factory VerifyBody.fromJson(Map<String, Object?> json) => _$VerifyBodyFromJson(json);
  
  final String phone;
  final String code;

  Map<String, Object?> toJson() => _$VerifyBodyToJson(this);
}
