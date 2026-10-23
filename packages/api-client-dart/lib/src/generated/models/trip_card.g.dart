// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_card.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TripCard _$TripCardFromJson(Map<String, dynamic> json) => TripCard(
  id: json['id'] as String,
  number: (json['number'] as num).toInt(),
  kind: TripKind.fromJson(json['kind'] as String),
  from: Stop.fromJson(json['from'] as Map<String, dynamic>),
  to: Stop.fromJson(json['to'] as Map<String, dynamic>),
  stopsCount: (json['stopsCount'] as num).toInt(),
  departsAt: DateTime.parse(json['departsAt'] as String),
  arrivesAt: DateTime.parse(json['arrivesAt'] as String),
  seatsFree: (json['seatsFree'] as num).toInt(),
  seatsTotal: (json['seatsTotal'] as num).toInt(),
  parcelSeatsFree: (json['parcelSeatsFree'] as num).toInt(),
  parcelSeatsTotal: (json['parcelSeatsTotal'] as num).toInt(),
  price: (json['price'] as num).toInt(),
  driver: UserBrief.fromJson(json['driver'] as Map<String, dynamic>),
  extras: (json['extras'] as List<dynamic>)
      .map((e) => ServiceKind.fromJson(e as String))
      .toList(),
  parcelAllowed: json['parcelAllowed'] as bool,
  parcelSizes: (json['parcelSizes'] as List<dynamic>)
      .map((e) => CarriedParcelSize.fromJson(e as String))
      .toList(),
  duplicates: (json['duplicates'] as num).toInt(),
  registrationOpen: json['registrationOpen'] as bool,
  bookable: json['bookable'] as bool,
  parcelBookable: json['parcelBookable'] as bool,
  effectiveStatus: TripStatus.fromJson(json['effectiveStatus'] as String),
  distanceKm: json['distanceKm'] as num?,
  badge: json['badge'] == null
      ? null
      : TripBadge.fromJson(json['badge'] as String),
);

Map<String, dynamic> _$TripCardToJson(TripCard instance) => <String, dynamic>{
  'id': instance.id,
  'number': instance.number,
  'kind': _$TripKindEnumMap[instance.kind]!,
  'from': instance.from,
  'to': instance.to,
  'stopsCount': instance.stopsCount,
  'departsAt': instance.departsAt.toIso8601String(),
  'arrivesAt': instance.arrivesAt.toIso8601String(),
  'seatsFree': instance.seatsFree,
  'seatsTotal': instance.seatsTotal,
  'parcelSeatsFree': instance.parcelSeatsFree,
  'parcelSeatsTotal': instance.parcelSeatsTotal,
  'price': instance.price,
  'distanceKm': instance.distanceKm,
  'badge': _$TripBadgeEnumMap[instance.badge],
  'driver': instance.driver,
  'extras': instance.extras.map((e) => _$ServiceKindEnumMap[e]!).toList(),
  'parcelAllowed': instance.parcelAllowed,
  'parcelSizes': instance.parcelSizes
      .map((e) => _$CarriedParcelSizeEnumMap[e]!)
      .toList(),
  'duplicates': instance.duplicates,
  'registrationOpen': instance.registrationOpen,
  'bookable': instance.bookable,
  'parcelBookable': instance.parcelBookable,
  'effectiveStatus': _$TripStatusEnumMap[instance.effectiveStatus]!,
};

const _$TripKindEnumMap = {
  TripKind.ride: 'ride',
  TripKind.parcel: 'parcel',
  TripKind.$unknown: r'$unknown',
};

const _$TripBadgeEnumMap = {
  TripBadge.top: 'top',
  TripBadge.nearest: 'nearest',
  TripBadge.$unknown: r'$unknown',
};

const _$ServiceKindEnumMap = {
  ServiceKind.childSeat: 'child_seat',
  ServiceKind.pets: 'pets',
  ServiceKind.luggage: 'luggage',
  ServiceKind.$unknown: r'$unknown',
};

const _$CarriedParcelSizeEnumMap = {
  CarriedParcelSize.s: 'S',
  CarriedParcelSize.m: 'M',
  CarriedParcelSize.l: 'L',
  CarriedParcelSize.$unknown: r'$unknown',
};

const _$TripStatusEnumMap = {
  TripStatus.active: 'active',
  TripStatus.intakeClosed: 'intake_closed',
  TripStatus.completed: 'completed',
  TripStatus.cancelled: 'cancelled',
  TripStatus.$unknown: r'$unknown',
};
