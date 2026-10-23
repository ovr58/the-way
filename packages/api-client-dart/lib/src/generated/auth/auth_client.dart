// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/health_result.dart';
import '../models/request_code_body.dart';
import '../models/request_code_result.dart';
import '../models/verify_body.dart';
import '../models/verify_result.dart';

part 'auth_client.g.dart';

@RestApi()
abstract class AuthClient {
  factory AuthClient(Dio dio, {String? baseUrl}) = _AuthClient;

  @POST('/auth/request-code')
  Future<RequestCodeResult> requestCode({
    @Body() required RequestCodeBody body,
  });

  @POST('/auth/verify')
  Future<VerifyResult> verify({
    @Body() required VerifyBody body,
  });

  @POST('/auth/logout')
  Future<void> logout();

  @GET('/health')
  Future<HealthResult> health();
}
