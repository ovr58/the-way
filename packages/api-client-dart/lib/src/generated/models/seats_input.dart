// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'seats_input.g.dart';

@JsonSerializable()
class SeatsInput {
  const SeatsInput({
    required this.seatsTotal,
  });
  
  factory SeatsInput.fromJson(Map<String, Object?> json) => _$SeatsInputFromJson(json);
  
  final int seatsTotal;

  Map<String, Object?> toJson() => _$SeatsInputToJson(this);
}
