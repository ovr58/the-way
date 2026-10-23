// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'client_log_level.dart';

part 'client_log_body.g.dart';

@JsonSerializable()
class ClientLogBody {
  const ClientLogBody({
    required this.level,
    required this.message,
    required this.appVersion,
    required this.device,
    this.screen,
    this.traceId,
  });
  
  factory ClientLogBody.fromJson(Map<String, Object?> json) => _$ClientLogBodyFromJson(json);
  
  final ClientLogLevel level;
  final String message;
  final String? screen;
  final String? traceId;
  final String appVersion;
  final String device;

  Map<String, Object?> toJson() => _$ClientLogBodyToJson(this);
}
