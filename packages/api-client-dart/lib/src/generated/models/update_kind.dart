// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum UpdateKind {
  @JsonValue('new_request')
  newRequest('new_request'),
  @JsonValue('passenger_paid')
  passengerPaid('passenger_paid'),
  @JsonValue('driver_accepted')
  driverAccepted('driver_accepted'),
  @JsonValue('driver_rejected')
  driverRejected('driver_rejected'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const UpdateKind(this.json);

  factory UpdateKind.fromJson(String json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final String? json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<UpdateKind> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
