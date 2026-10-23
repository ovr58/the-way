// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum ExtraKind {
  @JsonValue('child_seat')
  childSeat('child_seat'),
  @JsonValue('pets')
  pets('pets'),
  @JsonValue('luggage')
  luggage('luggage'),
  @JsonValue('parcel_s')
  parcelS('parcel_s'),
  @JsonValue('parcel_m')
  parcelM('parcel_m'),
  @JsonValue('parcel_l')
  parcelL('parcel_l'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ExtraKind(this.json);

  factory ExtraKind.fromJson(String json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final String? json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<ExtraKind> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
