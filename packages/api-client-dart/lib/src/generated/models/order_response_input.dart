// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'order_response_input.g.dart';

@JsonSerializable()
class OrderResponseInput {
  const OrderResponseInput({
    required this.tripId,
  });
  
  factory OrderResponseInput.fromJson(Map<String, Object?> json) => _$OrderResponseInputFromJson(json);
  
  final String tripId;

  Map<String, Object?> toJson() => _$OrderResponseInputToJson(this);
}
