// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/review.dart';

part 'reviews_client.g.dart';

@RestApi()
abstract class ReviewsClient {
  factory ReviewsClient(Dio dio, {String? baseUrl}) = _ReviewsClient;

  @GET('/users/{id}/reviews')
  Future<List<Review>> listUserReviews({
    @Path('id') required String id,
  });
}
