// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'request_code_body.g.dart';

@JsonSerializable()
class RequestCodeBody {
  const RequestCodeBody({
    required this.phone,
  });
  
  factory RequestCodeBody.fromJson(Map<String, Object?> json) => _$RequestCodeBodyFromJson(json);
  
  final String phone;

  Map<String, Object?> toJson() => _$RequestCodeBodyToJson(this);
}
