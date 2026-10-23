// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'me.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Me _$MeFromJson(Map<String, dynamic> json) => Me(
  id: json['id'] as String,
  phone: json['phone'] as String,
  mode: UserMode.fromJson(json['mode'] as String),
  rating: Rating.fromJson(json['rating'] as Map<String, dynamic>),
  tripsCount: (json['tripsCount'] as num).toInt(),
  cancellationsLast30: (json['cancellationsLast30'] as num).toInt(),
  name: json['name'] as String?,
  photoUrl: json['photoUrl'] as String?,
  city: json['city'] == null
      ? null
      : CityRef.fromJson(json['city'] as Map<String, dynamic>),
  blockedUntil: json['blockedUntil'] == null
      ? null
      : DateTime.parse(json['blockedUntil'] as String),
);

Map<String, dynamic> _$MeToJson(Me instance) => <String, dynamic>{
  'id': instance.id,
  'phone': instance.phone,
  'name': instance.name,
  'photoUrl': instance.photoUrl,
  'city': instance.city,
  'mode': _$UserModeEnumMap[instance.mode]!,
  'rating': instance.rating,
  'tripsCount': instance.tripsCount,
  'blockedUntil': instance.blockedUntil?.toIso8601String(),
  'cancellationsLast30': instance.cancellationsLast30,
};

const _$UserModeEnumMap = {
  UserMode.passenger: 'passenger',
  UserMode.driver: 'driver',
  UserMode.$unknown: r'$unknown',
};
