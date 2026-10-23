// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'extra_kind.dart';

part 'extra.g.dart';

@JsonSerializable()
class Extra {
  const Extra({
    required this.kind,
    required this.price,
  });
  
  factory Extra.fromJson(Map<String, Object?> json) => _$ExtraFromJson(json);
  
  final ExtraKind kind;
  final int price;

  Map<String, Object?> toJson() => _$ExtraToJson(this);
}
