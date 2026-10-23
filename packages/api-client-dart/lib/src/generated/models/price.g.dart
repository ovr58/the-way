// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'price.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Price _$PriceFromJson(Map<String, dynamic> json) => Price(
  fromIdx: (json['fromIdx'] as num).toInt(),
  toIdx: (json['toIdx'] as num).toInt(),
  price: (json['price'] as num).toInt(),
);

Map<String, dynamic> _$PriceToJson(Price instance) => <String, dynamic>{
  'fromIdx': instance.fromIdx,
  'toIdx': instance.toIdx,
  'price': instance.price,
};
