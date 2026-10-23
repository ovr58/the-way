// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'complaint.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Complaint _$ComplaintFromJson(Map<String, dynamic> json) => Complaint(
  id: json['id'] as String,
  reason: json['reason'] as String,
  status: ComplaintStatus.fromJson(json['status'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$ComplaintToJson(Complaint instance) => <String, dynamic>{
  'id': instance.id,
  'reason': instance.reason,
  'status': _$ComplaintStatusEnumMap[instance.status]!,
  'createdAt': instance.createdAt.toIso8601String(),
};

const _$ComplaintStatusEnumMap = {
  ComplaintStatus.open: 'open',
  ComplaintStatus.closed: 'closed',
  ComplaintStatus.$unknown: r'$unknown',
};
