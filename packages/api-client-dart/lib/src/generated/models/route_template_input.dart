// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'stop_input.dart';

part 'route_template_input.g.dart';

@JsonSerializable()
class RouteTemplateInput {
  const RouteTemplateInput({
    required this.stops,
  });
  
  factory RouteTemplateInput.fromJson(Map<String, Object?> json) => _$RouteTemplateInputFromJson(json);
  
  final List<StopInput> stops;

  Map<String, Object?> toJson() => _$RouteTemplateInputToJson(this);
}
