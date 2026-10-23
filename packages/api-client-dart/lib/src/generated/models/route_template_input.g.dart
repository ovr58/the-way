// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_template_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RouteTemplateInput _$RouteTemplateInputFromJson(Map<String, dynamic> json) =>
    RouteTemplateInput(
      stops: (json['stops'] as List<dynamic>)
          .map((e) => StopInput.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RouteTemplateInputToJson(RouteTemplateInput instance) =>
    <String, dynamic>{'stops': instance.stops};
