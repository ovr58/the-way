// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookingInput _$BookingInputFromJson(Map<String, dynamic> json) => BookingInput(
  fromIdx: (json['fromIdx'] as num).toInt(),
  toIdx: (json['toIdx'] as num).toInt(),
  seats: (json['seats'] as num).toInt(),
  parcelSize: ParcelSize.fromJson(json['parcelSize'] as String),
  parcelOnly: json['parcelOnly'] as bool,
  extras: (json['extras'] as List<dynamic>)
      .map((e) => ServiceKind.fromJson(e as String))
      .toList(),
  parcelComment: json['parcelComment'] as String?,
);

Map<String, dynamic> _$BookingInputToJson(BookingInput instance) =>
    <String, dynamic>{
      'fromIdx': instance.fromIdx,
      'toIdx': instance.toIdx,
      'seats': instance.seats,
      'parcelSize': _$ParcelSizeEnumMap[instance.parcelSize]!,
      'parcelOnly': instance.parcelOnly,
      'parcelComment': instance.parcelComment,
      'extras': instance.extras.map((e) => _$ServiceKindEnumMap[e]!).toList(),
    };

const _$ParcelSizeEnumMap = {
  ParcelSize.none: 'none',
  ParcelSize.s: 'S',
  ParcelSize.m: 'M',
  ParcelSize.l: 'L',
  ParcelSize.$unknown: r'$unknown',
};

const _$ServiceKindEnumMap = {
  ServiceKind.childSeat: 'child_seat',
  ServiceKind.pets: 'pets',
  ServiceKind.luggage: 'luggage',
  ServiceKind.$unknown: r'$unknown',
};
