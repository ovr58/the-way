// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'complaint_status.dart';

part 'complaint.g.dart';

@JsonSerializable()
class Complaint {
  const Complaint({
    required this.id,
    required this.reason,
    required this.status,
    required this.createdAt,
  });
  
  factory Complaint.fromJson(Map<String, Object?> json) => _$ComplaintFromJson(json);
  
  final String id;
  final String reason;
  final ComplaintStatus status;
  final DateTime createdAt;

  Map<String, Object?> toJson() => _$ComplaintToJson(this);
}
