// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_card.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderCard _$OrderCardFromJson(Map<String, dynamic> json) => OrderCard(
  id: json['id'] as String,
  number: (json['number'] as num).toInt(),
  kind: TripKind.fromJson(json['kind'] as String),
  from: Stop.fromJson(json['from'] as Map<String, dynamic>),
  to: Stop.fromJson(json['to'] as Map<String, dynamic>),
  stopsCount: (json['stopsCount'] as num).toInt(),
  departsAt: DateTime.parse(json['departsAt'] as String),
  arrivesAt: DateTime.parse(json['arrivesAt'] as String),
  seats: (json['seats'] as num).toInt(),
  parcelSize: ParcelSize.fromJson(json['parcelSize'] as String),
  parcelOnly: json['parcelOnly'] as bool,
  extras: (json['extras'] as List<dynamic>)
      .map((e) => ServiceKind.fromJson(e as String))
      .toList(),
  passenger: UserBrief.fromJson(json['passenger'] as Map<String, dynamic>),
  status: OrderStatus.fromJson(json['status'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  parcelComment: json['parcelComment'] as String?,
  distanceKm: json['distanceKm'] as num?,
  bookingId: json['bookingId'] as String?,
);

Map<String, dynamic> _$OrderCardToJson(OrderCard instance) => <String, dynamic>{
  'id': instance.id,
  'number': instance.number,
  'kind': _$TripKindEnumMap[instance.kind]!,
  'from': instance.from,
  'to': instance.to,
  'stopsCount': instance.stopsCount,
  'departsAt': instance.departsAt.toIso8601String(),
  'arrivesAt': instance.arrivesAt.toIso8601String(),
  'seats': instance.seats,
  'parcelSize': _$ParcelSizeEnumMap[instance.parcelSize]!,
  'parcelOnly': instance.parcelOnly,
  'parcelComment': instance.parcelComment,
  'extras': instance.extras.map((e) => _$ServiceKindEnumMap[e]!).toList(),
  'passenger': instance.passenger,
  'distanceKm': instance.distanceKm,
  'status': _$OrderStatusEnumMap[instance.status]!,
  'bookingId': instance.bookingId,
  'createdAt': instance.createdAt.toIso8601String(),
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

const _$OrderStatusEnumMap = {
  OrderStatus.open: 'open',
  OrderStatus.matched: 'matched',
  OrderStatus.cancelled: 'cancelled',
  OrderStatus.expired: 'expired',
  OrderStatus.$unknown: r'$unknown',
};
