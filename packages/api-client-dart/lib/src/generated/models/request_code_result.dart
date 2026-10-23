// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'request_code_result.g.dart';

@JsonSerializable()
class RequestCodeResult {
  const RequestCodeResult({
    required this.resendAfterSec,
  });
  
  factory RequestCodeResult.fromJson(Map<String, Object?> json) => _$RequestCodeResultFromJson(json);
  
  final int resendAfterSec;

  Map<String, Object?> toJson() => _$RequestCodeResultToJson(this);
}
