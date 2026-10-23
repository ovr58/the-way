// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'extra.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Extra _$ExtraFromJson(Map<String, dynamic> json) => Extra(
  kind: ExtraKind.fromJson(json['kind'] as String),
  price: (json['price'] as num).toInt(),
);

Map<String, dynamic> _$ExtraToJson(Extra instance) => <String, dynamic>{
  'kind': _$ExtraKindEnumMap[instance.kind]!,
  'price': instance.price,
};

const _$ExtraKindEnumMap = {
  ExtraKind.childSeat: 'child_seat',
  ExtraKind.pets: 'pets',
  ExtraKind.luggage: 'luggage',
  ExtraKind.parcelS: 'parcel_s',
  ExtraKind.parcelM: 'parcel_m',
  ExtraKind.parcelL: 'parcel_l',
  ExtraKind.$unknown: r'$unknown',
};
