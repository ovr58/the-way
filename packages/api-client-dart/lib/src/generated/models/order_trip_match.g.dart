// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_trip_match.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderTripMatch _$OrderTripMatchFromJson(Map<String, dynamic> json) =>
    OrderTripMatch(
      trip: TripCard.fromJson(json['trip'] as Map<String, dynamic>),
      fromIdx: (json['fromIdx'] as num).toInt(),
      toIdx: (json['toIdx'] as num).toInt(),
      priceTotal: (json['priceTotal'] as num).toInt(),
    );

Map<String, dynamic> _$OrderTripMatchToJson(OrderTripMatch instance) =>
    <String, dynamic>{
      'trip': instance.trip,
      'fromIdx': instance.fromIdx,
      'toIdx': instance.toIdx,
      'priceTotal': instance.priceTotal,
    };
