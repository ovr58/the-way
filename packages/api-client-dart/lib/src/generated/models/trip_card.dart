// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'carried_parcel_size.dart';
import 'service_kind.dart';
import 'stop.dart';
import 'trip_badge.dart';
import 'trip_kind.dart';
import 'trip_status.dart';
import 'user_brief.dart';

part 'trip_card.g.dart';

@JsonSerializable()
class TripCard {
  const TripCard({
    required this.id,
    required this.number,
    required this.kind,
    required this.from,
    required this.to,
    required this.stopsCount,
    required this.departsAt,
    required this.arrivesAt,
    required this.seatsFree,
    required this.seatsTotal,
    required this.parcelSeatsFree,
    required this.parcelSeatsTotal,
    required this.price,
    required this.driver,
    required this.extras,
    required this.parcelAllowed,
    required this.parcelSizes,
    required this.duplicates,
    required this.registrationOpen,
    required this.bookable,
    required this.parcelBookable,
    required this.effectiveStatus,
    this.distanceKm,
    this.badge,
  });
  
  factory TripCard.fromJson(Map<String, Object?> json) => _$TripCardFromJson(json);
  
  final String id;
  final int number;
  final TripKind kind;
  final Stop from;
  final Stop to;
  final int stopsCount;
  final DateTime departsAt;
  final DateTime arrivesAt;
  final int seatsFree;
  final int seatsTotal;
  final int parcelSeatsFree;
  final int parcelSeatsTotal;
  final int price;
  final num? distanceKm;
  final TripBadge? badge;
  final UserBrief driver;
  final List<ServiceKind> extras;
  final bool parcelAllowed;
  final List<CarriedParcelSize> parcelSizes;
  final int duplicates;
  final bool registrationOpen;
  final bool bookable;
  final bool parcelBookable;
  final TripStatus effectiveStatus;

  Map<String, Object?> toJson() => _$TripCardToJson(this);
}
