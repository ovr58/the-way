// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'order_status.dart';
import 'parcel_size.dart';
import 'service_kind.dart';
import 'stop.dart';
import 'trip_kind.dart';
import 'user_brief.dart';

part 'order_card.g.dart';

@JsonSerializable()
class OrderCard {
  const OrderCard({
    required this.id,
    required this.number,
    required this.kind,
    required this.from,
    required this.to,
    required this.stopsCount,
    required this.departsAt,
    required this.arrivesAt,
    required this.seats,
    required this.parcelSize,
    required this.parcelOnly,
    required this.extras,
    required this.passenger,
    required this.status,
    required this.createdAt,
    this.parcelComment,
    this.distanceKm,
    this.bookingId,
  });
  
  factory OrderCard.fromJson(Map<String, Object?> json) => _$OrderCardFromJson(json);
  
  final String id;
  final int number;
  final TripKind kind;
  final Stop from;
  final Stop to;
  final int stopsCount;
  final DateTime departsAt;
  final DateTime arrivesAt;
  final int seats;
  final ParcelSize parcelSize;
  final bool parcelOnly;
  final String? parcelComment;
  final List<ServiceKind> extras;
  final UserBrief passenger;
  final num? distanceKm;
  final OrderStatus status;
  final String? bookingId;
  final DateTime createdAt;

  Map<String, Object?> toJson() => _$OrderCardToJson(this);
}
