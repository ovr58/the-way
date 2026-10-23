// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum ErrorCode {
  @JsonValue('validation')
  validation('validation'),
  @JsonValue('invalid_code')
  invalidCode('invalid_code'),
  @JsonValue('unauthorized')
  unauthorized('unauthorized'),
  @JsonValue('forbidden')
  forbidden('forbidden'),
  @JsonValue('not_found')
  notFound('not_found'),
  @JsonValue('limit_reached')
  limitReached('limit_reached'),
  @JsonValue('too_far_ahead')
  tooFarAhead('too_far_ahead'),
  @JsonValue('invalid_time_step')
  invalidTimeStep('invalid_time_step'),
  @JsonValue('edit_locked')
  editLocked('edit_locked'),
  @JsonValue('seats_below_taken')
  seatsBelowTaken('seats_below_taken'),
  @JsonValue('no_seats')
  noSeats('no_seats'),
  @JsonValue('trip_unavailable')
  tripUnavailable('trip_unavailable'),
  @JsonValue('booking_exists')
  bookingExists('booking_exists'),
  @JsonValue('car_invalid')
  carInvalid('car_invalid'),
  @JsonValue('file_too_large')
  fileTooLarge('file_too_large'),
  @JsonValue('file_type')
  fileType('file_type'),
  @JsonValue('blocked')
  blocked('blocked'),
  @JsonValue('account_blocked')
  accountBlocked('account_blocked'),
  @JsonValue('invalid_transition')
  invalidTransition('invalid_transition'),
  @JsonValue('order_unavailable')
  orderUnavailable('order_unavailable'),
  @JsonValue('order_mismatch')
  orderMismatch('order_mismatch'),
  @JsonValue('car_plate_taken')
  carPlateTaken('car_plate_taken'),
  @JsonValue('car_seats_out_of_range')
  carSeatsOutOfRange('car_seats_out_of_range'),
  @JsonValue('internal')
  internal('internal'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ErrorCode(this.json);

  factory ErrorCode.fromJson(String json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final String? json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<ErrorCode> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
