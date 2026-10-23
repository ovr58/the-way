// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Booking _$BookingFromJson(Map<String, dynamic> json) => Booking(
  id: json['id'] as String,
  number: (json['number'] as num).toInt(),
  status: BookingStatus.fromJson(json['status'] as String),
  seats: (json['seats'] as num).toInt(),
  fromIdx: (json['fromIdx'] as num).toInt(),
  toIdx: (json['toIdx'] as num).toInt(),
  from: Stop.fromJson(json['from'] as Map<String, dynamic>),
  to: Stop.fromJson(json['to'] as Map<String, dynamic>),
  segmentPrice: (json['segmentPrice'] as num).toInt(),
  parcelSize: ParcelSize.fromJson(json['parcelSize'] as String),
  parcelOnly: json['parcelOnly'] as bool,
  extras: (json['extras'] as List<dynamic>)
      .map((e) => Extra.fromJson(e as Map<String, dynamic>))
      .toList(),
  priceTotal: (json['priceTotal'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  trip: TripCard.fromJson(json['trip'] as Map<String, dynamic>),
  passenger: UserBrief.fromJson(json['passenger'] as Map<String, dynamic>),
  parcelComment: json['parcelComment'] as String?,
  segmentKm: json['segmentKm'] as num?,
  paidAt: json['paidAt'] == null
      ? null
      : DateTime.parse(json['paidAt'] as String),
  orderId: json['orderId'] as String?,
  orderNumber: (json['orderNumber'] as num?)?.toInt(),
);

Map<String, dynamic> _$BookingToJson(Booking instance) => <String, dynamic>{
  'id': instance.id,
  'number': instance.number,
  'status': _$BookingStatusEnumMap[instance.status]!,
  'seats': instance.seats,
  'fromIdx': instance.fromIdx,
  'toIdx': instance.toIdx,
  'from': instance.from,
  'to': instance.to,
  'segmentPrice': instance.segmentPrice,
  'parcelSize': _$ParcelSizeEnumMap[instance.parcelSize]!,
  'parcelOnly': instance.parcelOnly,
  'parcelComment': instance.parcelComment,
  'extras': instance.extras,
  'priceTotal': instance.priceTotal,
  'segmentKm': instance.segmentKm,
  'createdAt': instance.createdAt.toIso8601String(),
  'paidAt': instance.paidAt?.toIso8601String(),
  'trip': instance.trip,
  'passenger': instance.passenger,
  'orderId': instance.orderId,
  'orderNumber': instance.orderNumber,
};

const _$BookingStatusEnumMap = {
  BookingStatus.requested: 'requested',
  BookingStatus.awaitingPayment: 'awaiting_payment',
  BookingStatus.paid: 'paid',
  BookingStatus.rejected: 'rejected',
  BookingStatus.cancelled: 'cancelled',
  BookingStatus.$unknown: r'$unknown',
};

const _$ParcelSizeEnumMap = {
  ParcelSize.none: 'none',
  ParcelSize.s: 'S',
  ParcelSize.m: 'M',
  ParcelSize.l: 'L',
  ParcelSize.$unknown: r'$unknown',
};
