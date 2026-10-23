// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_me_body.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchMeBody _$PatchMeBodyFromJson(Map<String, dynamic> json) => PatchMeBody(
  name: json['name'] as String?,
  photoFileId: json['photoFileId'] as String?,
  cityId: (json['cityId'] as num?)?.toInt(),
  mode: json['mode'] == null ? null : UserMode.fromJson(json['mode'] as String),
);

Map<String, dynamic> _$PatchMeBodyToJson(PatchMeBody instance) =>
    <String, dynamic>{
      'name': instance.name,
      'photoFileId': instance.photoFileId,
      'cityId': instance.cityId,
      'mode': _$UserModeEnumMap[instance.mode],
    };

const _$UserModeEnumMap = {
  UserMode.passenger: 'passenger',
  UserMode.driver: 'driver',
  UserMode.$unknown: r'$unknown',
};
