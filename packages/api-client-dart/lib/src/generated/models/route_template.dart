// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'stop.dart';

part 'route_template.g.dart';

@JsonSerializable()
class RouteTemplate {
  const RouteTemplate({
    required this.id,
    required this.stops,
  });
  
  factory RouteTemplate.fromJson(Map<String, Object?> json) => _$RouteTemplateFromJson(json);
  
  final String id;
  final List<Stop> stops;

  Map<String, Object?> toJson() => _$RouteTemplateToJson(this);
}
