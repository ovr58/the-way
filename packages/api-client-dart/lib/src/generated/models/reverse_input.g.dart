// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reverse_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReverseInput _$ReverseInputFromJson(Map<String, dynamic> json) => ReverseInput(
  departsAt: DateTime.parse(json['departsAt'] as String),
  arrivesAt: DateTime.parse(json['arrivesAt'] as String),
);

Map<String, dynamic> _$ReverseInputToJson(ReverseInput instance) =>
    <String, dynamic>{
      'departsAt': instance.departsAt.toIso8601String(),
      'arrivesAt': instance.arrivesAt.toIso8601String(),
    };
