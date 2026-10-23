// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'update_kind.dart';

part 'update.g.dart';

@JsonSerializable()
class Update {
  const Update({
    required this.bookingId,
    required this.tripId,
    required this.kind,
    required this.at,
  });
  
  factory Update.fromJson(Map<String, Object?> json) => _$UpdateFromJson(json);
  
  final String bookingId;
  final String tripId;
  final UpdateKind kind;
  final DateTime at;

  Map<String, Object?> toJson() => _$UpdateToJson(this);
}
