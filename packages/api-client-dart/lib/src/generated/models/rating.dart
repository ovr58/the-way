// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'rating.g.dart';

@JsonSerializable()
class Rating {
  const Rating({
    required this.value,
    required this.count,
  });
  
  factory Rating.fromJson(Map<String, Object?> json) => _$RatingFromJson(json);
  
  final num value;
  final int count;

  Map<String, Object?> toJson() => _$RatingToJson(this);
}
