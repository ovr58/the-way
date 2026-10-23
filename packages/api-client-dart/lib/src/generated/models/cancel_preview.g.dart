// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cancel_preview.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CancelPreview _$CancelPreviewFromJson(Map<String, dynamic> json) =>
    CancelPreview(
      cancellationsLast30: (json['cancellationsLast30'] as num).toInt(),
      willBlock: json['willBlock'] as bool,
      refundAmount: (json['refundAmount'] as num?)?.toInt(),
      counts: json['counts'] as bool?,
    );

Map<String, dynamic> _$CancelPreviewToJson(CancelPreview instance) =>
    <String, dynamic>{
      'cancellationsLast30': instance.cancellationsLast30,
      'willBlock': instance.willBlock,
      'refundAmount': instance.refundAmount,
      'counts': instance.counts,
    };
