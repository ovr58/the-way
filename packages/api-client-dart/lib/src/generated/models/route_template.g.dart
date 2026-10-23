// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_template.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RouteTemplate _$RouteTemplateFromJson(Map<String, dynamic> json) =>
    RouteTemplate(
      id: json['id'] as String,
      stops: (json['stops'] as List<dynamic>)
          .map((e) => Stop.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RouteTemplateToJson(RouteTemplate instance) =>
    <String, dynamic>{'id': instance.id, 'stops': instance.stops};
