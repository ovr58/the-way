// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_log_body.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClientLogBody _$ClientLogBodyFromJson(Map<String, dynamic> json) =>
    ClientLogBody(
      level: ClientLogLevel.fromJson(json['level'] as String),
      message: json['message'] as String,
      appVersion: json['appVersion'] as String,
      device: json['device'] as String,
      screen: json['screen'] as String?,
      traceId: json['traceId'] as String?,
    );

Map<String, dynamic> _$ClientLogBodyToJson(ClientLogBody instance) =>
    <String, dynamic>{
      'level': _$ClientLogLevelEnumMap[instance.level]!,
      'message': instance.message,
      'screen': instance.screen,
      'traceId': instance.traceId,
      'appVersion': instance.appVersion,
      'device': instance.device,
    };

const _$ClientLogLevelEnumMap = {
  ClientLogLevel.error: 'error',
  ClientLogLevel.warn: 'warn',
  ClientLogLevel.info: 'info',
  ClientLogLevel.$unknown: r'$unknown',
};
