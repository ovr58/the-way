// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'city_ref.dart';
import 'rating.dart';
import 'user_mode.dart';

part 'me.g.dart';

@JsonSerializable()
class Me {
  const Me({
    required this.id,
    required this.phone,
    required this.mode,
    required this.rating,
    required this.tripsCount,
    required this.cancellationsLast30,
    this.name,
    this.photoUrl,
    this.city,
    this.blockedUntil,
  });
  
  factory Me.fromJson(Map<String, Object?> json) => _$MeFromJson(json);
  
  final String id;
  final String phone;
  final String? name;
  final String? photoUrl;
  final CityRef? city;
  final UserMode mode;
  final Rating rating;
  final int tripsCount;
  final DateTime? blockedUntil;
  final int cancellationsLast30;

  Map<String, Object?> toJson() => _$MeToJson(this);
}
