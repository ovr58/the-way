// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'review.g.dart';

@JsonSerializable()
class Review {
  const Review({
    required this.id,
    required this.rating,
    required this.createdAt,
    this.authorName,
    this.body,
  });
  
  factory Review.fromJson(Map<String, Object?> json) => _$ReviewFromJson(json);
  
  final String id;
  final String? authorName;
  final int rating;
  final String? body;
  final DateTime createdAt;

  Map<String, Object?> toJson() => _$ReviewToJson(this);
}
