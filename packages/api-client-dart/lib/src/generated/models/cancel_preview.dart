// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'cancel_preview.g.dart';

@JsonSerializable()
class CancelPreview {
  const CancelPreview({
    required this.cancellationsLast30,
    required this.willBlock,
    this.refundAmount,
    this.counts,
  });
  
  factory CancelPreview.fromJson(Map<String, Object?> json) => _$CancelPreviewFromJson(json);
  
  final int cancellationsLast30;
  final bool willBlock;
  final int? refundAmount;
  final bool? counts;

  Map<String, Object?> toJson() => _$CancelPreviewToJson(this);
}
