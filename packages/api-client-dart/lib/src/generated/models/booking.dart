// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'booking_status.dart';
import 'extra.dart';
import 'parcel_size.dart';
import 'stop.dart';
import 'trip_card.dart';
import 'user_brief.dart';

part 'booking.g.dart';

@JsonSerializable()
class Booking {
  const Booking({
    required this.id,
    required this.number,
    required this.status,
    required this.seats,
    required this.fromIdx,
    required this.toIdx,
    required this.from,
    required this.to,
    required this.segmentPrice,
    required this.parcelSize,
    required this.parcelOnly,
    required this.extras,
    required this.priceTotal,
    required this.createdAt,
    required this.trip,
    required this.passenger,
    this.parcelComment,
    this.segmentKm,
    this.paidAt,
    this.orderId,
    this.orderNumber,
  });
  
  factory Booking.fromJson(Map<String, Object?> json) => _$BookingFromJson(json);
  
  final String id;
  final int number;
  final BookingStatus status;
  final int seats;
  final int fromIdx;
  final int toIdx;
  final Stop from;
  final Stop to;
  final int segmentPrice;
  final ParcelSize parcelSize;
  final bool parcelOnly;
  final String? parcelComment;
  final List<Extra> extras;
  final int priceTotal;
  final num? segmentKm;
  final DateTime createdAt;
  final DateTime? paidAt;
  final TripCard trip;
  final UserBrief passenger;
  final String? orderId;
  final int? orderNumber;

  Map<String, Object?> toJson() => _$BookingToJson(this);
}
