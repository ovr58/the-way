// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'rating.dart';

part 'user_brief.g.dart';

@JsonSerializable()
class UserBrief {
  const UserBrief({
    required this.id,
    required this.rating,
    required this.tripsCount,
    this.name,
    this.photoUrl,
    this.phone,
  });
  
  factory UserBrief.fromJson(Map<String, Object?> json) => _$UserBriefFromJson(json);
  
  final String id;
  final String? name;
  final String? photoUrl;
  final Rating rating;
  final int tripsCount;
  final String? phone;

  Map<String, Object?> toJson() => _$UserBriefToJson(this);
}
