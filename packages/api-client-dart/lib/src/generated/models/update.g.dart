// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Update _$UpdateFromJson(Map<String, dynamic> json) => Update(
  bookingId: json['bookingId'] as String,
  tripId: json['tripId'] as String,
  kind: UpdateKind.fromJson(json['kind'] as String),
  at: DateTime.parse(json['at'] as String),
);

Map<String, dynamic> _$UpdateToJson(Update instance) => <String, dynamic>{
  'bookingId': instance.bookingId,
  'tripId': instance.tripId,
  'kind': _$UpdateKindEnumMap[instance.kind]!,
  'at': instance.at.toIso8601String(),
};

const _$UpdateKindEnumMap = {
  UpdateKind.newRequest: 'new_request',
  UpdateKind.passengerPaid: 'passenger_paid',
  UpdateKind.driverAccepted: 'driver_accepted',
  UpdateKind.driverRejected: 'driver_rejected',
  UpdateKind.$unknown: r'$unknown',
};
