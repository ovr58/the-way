// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quote.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Quote _$QuoteFromJson(Map<String, dynamic> json) => Quote(
  segmentPrice: (json['segmentPrice'] as num).toInt(),
  priceTotal: (json['priceTotal'] as num).toInt(),
);

Map<String, dynamic> _$QuoteToJson(Quote instance) => <String, dynamic>{
  'segmentPrice': instance.segmentPrice,
  'priceTotal': instance.priceTotal,
};
