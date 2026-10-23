// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'dart:convert';
import 'dart:io';

import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/file_ref.dart';

part 'files_client.g.dart';

@RestApi()
abstract class FilesClient {
  factory FilesClient(Dio dio, {String? baseUrl}) = _FilesClient;

  @MultiPart()
  @POST('/files')
  Future<FileRef> uploadFile({
    @Part(name: 'file') required File file,
  });

  @GET('/files/{id}')
  @DioResponseType(ResponseType.stream)
  Stream<String> getFile({
    @Path('id') required String id,
  });
}
