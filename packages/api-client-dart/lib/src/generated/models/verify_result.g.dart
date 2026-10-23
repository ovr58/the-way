// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verify_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VerifyResult _$VerifyResultFromJson(Map<String, dynamic> json) => VerifyResult(
  token: json['token'] as String,
  isNew: json['isNew'] as bool,
  me: Me.fromJson(json['me'] as Map<String, dynamic>),
);

Map<String, dynamic> _$VerifyResultToJson(VerifyResult instance) =>
    <String, dynamic>{
      'token': instance.token,
      'isNew': instance.isNew,
      'me': instance.me,
    };
