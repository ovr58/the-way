// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/complaint.dart';
import '../models/me.dart';
import '../models/patch_me_body.dart';
import '../models/user_brief.dart';

part 'users_client.g.dart';

@RestApi()
abstract class UsersClient {
  factory UsersClient(Dio dio, {String? baseUrl}) = _UsersClient;

  @GET('/me')
  Future<Me> getMe();

  @PATCH('/me')
  Future<Me> patchMe({
    @Body() required PatchMeBody body,
  });

  @GET('/me/complaints')
  Future<List<Complaint>> myComplaints();

  @GET('/users/{id}/public')
  Future<UserBrief> getPublicUser({
    @Path('id') required String id,
  });
}
