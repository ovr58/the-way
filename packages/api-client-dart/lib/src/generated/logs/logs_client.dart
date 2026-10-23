// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/client_log_body.dart';

part 'logs_client.g.dart';

@RestApi()
abstract class LogsClient {
  factory LogsClient(Dio dio, {String? baseUrl}) = _LogsClient;

  @POST('/client-logs')
  Future<void> writeClientLog({
    @Body() required ClientLogBody body,
  });
}
