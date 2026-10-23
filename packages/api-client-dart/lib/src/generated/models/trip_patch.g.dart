// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_patch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TripPatch _$TripPatchFromJson(Map<String, dynamic> json) => TripPatch(
  kind: TripKind.fromJson(json['kind'] as String),
  vehicleKind: VehicleKind.fromJson(json['vehicleKind'] as String),
  stops: (json['stops'] as List<dynamic>)
      .map((e) => StopInput.fromJson(e as Map<String, dynamic>))
      .toList(),
  departsAt: DateTime.parse(json['departsAt'] as String),
  arrivesAt: DateTime.parse(json['arrivesAt'] as String),
  seatsTotal: (json['seatsTotal'] as num).toInt(),
  priceFull: (json['priceFull'] as num).toInt(),
  prices: (json['prices'] as List<dynamic>)
      .map((e) => Price.fromJson(e as Map<String, dynamic>))
      .toList(),
  priceBoardingMin: (json['priceBoardingMin'] as num).toInt(),
  carId: json['carId'] as String,
  extras: (json['extras'] as List<dynamic>)
      .map((e) => Extra.fromJson(e as Map<String, dynamic>))
      .toList(),
  parcelOnlyAllowed: json['parcelOnlyAllowed'] as bool,
  parcelSeatsTotal: (json['parcelSeatsTotal'] as num).toInt(),
  bookingMode: BookingMode.fromJson(json['bookingMode'] as String),
);

Map<String, dynamic> _$TripPatchToJson(TripPatch instance) => <String, dynamic>{
  'kind': _$TripKindEnumMap[instance.kind]!,
  'vehicleKind': _$VehicleKindEnumMap[instance.vehicleKind]!,
  'stops': instance.stops,
  'departsAt': instance.departsAt.toIso8601String(),
  'arrivesAt': instance.arrivesAt.toIso8601String(),
  'seatsTotal': instance.seatsTotal,
  'priceFull': instance.priceFull,
  'prices': instance.prices,
  'priceBoardingMin': instance.priceBoardingMin,
  'carId': instance.carId,
  'extras': instance.extras,
  'parcelOnlyAllowed': instance.parcelOnlyAllowed,
  'parcelSeatsTotal': instance.parcelSeatsTotal,
  'bookingMode': _$BookingModeEnumMap[instance.bookingMode]!,
};

const _$TripKindEnumMap = {
  TripKind.ride: 'ride',
  TripKind.parcel: 'parcel',
  TripKind.$unknown: r'$unknown',
};

const _$VehicleKindEnumMap = {
  VehicleKind.car: 'car',
  VehicleKind.bus: 'bus',
  VehicleKind.$unknown: r'$unknown',
};

const _$BookingModeEnumMap = {
  BookingMode.standard: 'standard',
  BookingMode.instant: 'instant',
  BookingMode.$unknown: r'$unknown',
};
