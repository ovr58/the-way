// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderInput _$OrderInputFromJson(Map<String, dynamic> json) => OrderInput(
  kind: TripKind.fromJson(json['kind'] as String),
  stops: (json['stops'] as List<dynamic>)
      .map((e) => StopInput.fromJson(e as Map<String, dynamic>))
      .toList(),
  departsAt: DateTime.parse(json['departsAt'] as String),
  arrivesAt: DateTime.parse(json['arrivesAt'] as String),
  seats: (json['seats'] as num).toInt(),
  parcelSize: ParcelSize.fromJson(json['parcelSize'] as String),
  extras: (json['extras'] as List<dynamic>)
      .map((e) => ServiceKind.fromJson(e as String))
      .toList(),
  parcelComment: json['parcelComment'] as String?,
);

Map<String, dynamic> _$OrderInputToJson(OrderInput instance) =>
    <String, dynamic>{
      'kind': _$TripKindEnumMap[instance.kind]!,
      'stops': instance.stops,
      'departsAt': instance.departsAt.toIso8601String(),
      'arrivesAt': instance.arrivesAt.toIso8601String(),
      'seats': instance.seats,
      'parcelSize': _$ParcelSizeEnumMap[instance.parcelSize]!,
      'parcelComment': instance.parcelComment,
      'extras': instance.extras.map((e) => _$ServiceKindEnumMap[e]!).toList(),
    };

const _$TripKindEnumMap = {
  TripKind.ride: 'ride',
  TripKind.parcel: 'parcel',
  TripKind.$unknown: r'$unknown',
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
