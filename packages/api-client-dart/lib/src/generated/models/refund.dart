// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'refund.g.dart';

@JsonSerializable()
class Refund {
  const Refund({
    required this.amount,
    required this.days,
  });
  
  factory Refund.fromJson(Map<String, Object?> json) => _$RefundFromJson(json);
  
  final int amount;
  final int days;

  Map<String, Object?> toJson() => _$RefundToJson(this);
}
