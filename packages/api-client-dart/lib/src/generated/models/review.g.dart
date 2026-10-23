// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Review _$ReviewFromJson(Map<String, dynamic> json) => Review(
  id: json['id'] as String,
  rating: (json['rating'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  authorName: json['authorName'] as String?,
  body: json['body'] as String?,
);

Map<String, dynamic> _$ReviewToJson(Review instance) => <String, dynamic>{
  'id': instance.id,
  'authorName': instance.authorName,
  'rating': instance.rating,
  'body': instance.body,
  'createdAt': instance.createdAt.toIso8601String(),
};
