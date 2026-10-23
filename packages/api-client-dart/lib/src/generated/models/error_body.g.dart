// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_body.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ErrorBody _$ErrorBodyFromJson(Map<String, dynamic> json) => ErrorBody(
  code: ErrorCode.fromJson(json['code'] as String),
  message: json['message'] as String,
  blockedUntil: json['blockedUntil'] == null
      ? null
      : DateTime.parse(json['blockedUntil'] as String),
);

Map<String, dynamic> _$ErrorBodyToJson(ErrorBody instance) => <String, dynamic>{
  'code': _$ErrorCodeEnumMap[instance.code]!,
  'message': instance.message,
  'blockedUntil': instance.blockedUntil?.toIso8601String(),
};

const _$ErrorCodeEnumMap = {
  ErrorCode.validation: 'validation',
  ErrorCode.invalidCode: 'invalid_code',
  ErrorCode.unauthorized: 'unauthorized',
  ErrorCode.forbidden: 'forbidden',
  ErrorCode.notFound: 'not_found',
  ErrorCode.limitReached: 'limit_reached',
  ErrorCode.tooFarAhead: 'too_far_ahead',
  ErrorCode.invalidTimeStep: 'invalid_time_step',
  ErrorCode.editLocked: 'edit_locked',
  ErrorCode.seatsBelowTaken: 'seats_below_taken',
  ErrorCode.noSeats: 'no_seats',
  ErrorCode.tripUnavailable: 'trip_unavailable',
  ErrorCode.bookingExists: 'booking_exists',
  ErrorCode.carInvalid: 'car_invalid',
  ErrorCode.fileTooLarge: 'file_too_large',
  ErrorCode.fileType: 'file_type',
  ErrorCode.blocked: 'blocked',
  ErrorCode.accountBlocked: 'account_blocked',
  ErrorCode.invalidTransition: 'invalid_transition',
  ErrorCode.orderUnavailable: 'order_unavailable',
  ErrorCode.orderMismatch: 'order_mismatch',
  ErrorCode.carPlateTaken: 'car_plate_taken',
  ErrorCode.carSeatsOutOfRange: 'car_seats_out_of_range',
  ErrorCode.internal: 'internal',
  ErrorCode.$unknown: r'$unknown',
};
