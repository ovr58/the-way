// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'parcel_size.dart';
import 'service_kind.dart';

part 'booking_input.g.dart';

@JsonSerializable()
class BookingInput {
  const BookingInput({
    required this.fromIdx,
    required this.toIdx,
    required this.seats,
    required this.parcelSize,
    required this.parcelOnly,
    required this.extras,
    this.parcelComment,
  });
  
  factory BookingInput.fromJson(Map<String, Object?> json) => _$BookingInputFromJson(json);
  
  final int fromIdx;
  final int toIdx;
  final int seats;
  final ParcelSize parcelSize;
  final bool parcelOnly;
  final String? parcelComment;
  final List<ServiceKind> extras;

  Map<String, Object?> toJson() => _$BookingInputToJson(this);
}
