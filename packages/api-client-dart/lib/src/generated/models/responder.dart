// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'responder.g.dart';

@JsonSerializable()
class Responder {
  const Responder({
    required this.id,
    this.photoUrl,
  });
  
  factory Responder.fromJson(Map<String, Object?> json) => _$ResponderFromJson(json);
  
  final String id;
  final String? photoUrl;

  Map<String, Object?> toJson() => _$ResponderToJson(this);
}
