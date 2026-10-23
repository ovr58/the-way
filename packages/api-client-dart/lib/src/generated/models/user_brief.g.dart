// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_brief.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserBrief _$UserBriefFromJson(Map<String, dynamic> json) => UserBrief(
  id: json['id'] as String,
  rating: Rating.fromJson(json['rating'] as Map<String, dynamic>),
  tripsCount: (json['tripsCount'] as num).toInt(),
  name: json['name'] as String?,
  photoUrl: json['photoUrl'] as String?,
  phone: json['phone'] as String?,
);

Map<String, dynamic> _$UserBriefToJson(UserBrief instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'photoUrl': instance.photoUrl,
  'rating': instance.rating,
  'tripsCount': instance.tripsCount,
  'phone': instance.phone,
};
