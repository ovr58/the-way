// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'user_mode.dart';

part 'patch_me_body.g.dart';

@JsonSerializable()
class PatchMeBody {
  const PatchMeBody({
    required this.name,
    required this.photoFileId,
    required this.cityId,
    required this.mode,
  });
  
  factory PatchMeBody.fromJson(Map<String, Object?> json) => _$PatchMeBodyFromJson(json);
  
  final String? name;
  final String? photoFileId;
  final int? cityId;
  final UserMode? mode;

  Map<String, Object?> toJson() => _$PatchMeBodyToJson(this);
}
