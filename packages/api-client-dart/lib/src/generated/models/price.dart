// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'price.g.dart';

@JsonSerializable()
class Price {
  const Price({
    required this.fromIdx,
    required this.toIdx,
    required this.price,
  });
  
  factory Price.fromJson(Map<String, Object?> json) => _$PriceFromJson(json);
  
  final int fromIdx;
  final int toIdx;
  final int price;

  Map<String, Object?> toJson() => _$PriceToJson(this);
}
