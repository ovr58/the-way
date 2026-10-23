// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cancel_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CancelResult _$CancelResultFromJson(Map<String, dynamic> json) => CancelResult(
  status: CancelledStatus.fromJson(json['status'] as String),
  cancellationsLast30: (json['cancellationsLast30'] as num).toInt(),
  blockedUntil: json['blockedUntil'] == null
      ? null
      : DateTime.parse(json['blockedUntil'] as String),
  refund: json['refund'] == null
      ? null
      : Refund.fromJson(json['refund'] as Map<String, dynamic>),
);

Map<String, dynamic> _$CancelResultToJson(CancelResult instance) =>
    <String, dynamic>{
      'status': _$CancelledStatusEnumMap[instance.status]!,
      'cancellationsLast30': instance.cancellationsLast30,
      'blockedUntil': instance.blockedUntil?.toIso8601String(),
      'refund': instance.refund,
    };

const _$CancelledStatusEnumMap = {
  CancelledStatus.cancelled: 'cancelled',
  CancelledStatus.$unknown: r'$unknown',
};
