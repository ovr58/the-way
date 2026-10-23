// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refund.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Refund _$RefundFromJson(Map<String, dynamic> json) => Refund(
  amount: (json['amount'] as num).toInt(),
  days: (json['days'] as num).toInt(),
);

Map<String, dynamic> _$RefundToJson(Refund instance) => <String, dynamic>{
  'amount': instance.amount,
  'days': instance.days,
};
