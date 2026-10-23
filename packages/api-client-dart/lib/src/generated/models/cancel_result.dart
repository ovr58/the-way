// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'cancelled_status.dart';
import 'refund.dart';

part 'cancel_result.g.dart';

@JsonSerializable()
class CancelResult {
  const CancelResult({
    required this.status,
    required this.cancellationsLast30,
    this.blockedUntil,
    this.refund,
  });
  
  factory CancelResult.fromJson(Map<String, Object?> json) => _$CancelResultFromJson(json);
  
  final CancelledStatus status;
  final int cancellationsLast30;
  final DateTime? blockedUntil;
  final Refund? refund;

  Map<String, Object?> toJson() => _$CancelResultToJson(this);
}
