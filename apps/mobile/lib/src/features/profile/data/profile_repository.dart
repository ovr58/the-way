import 'dart:io';

import 'package:api_client/api_client.dart';

/// Данные раздела «Профиль»: фото и правка личных данных, полученные жалобы.
class ProfileRepository {
  ProfileRepository(this._api);

  final TheWayApi _api;

  /// `POST /files`.
  Future<FileRef> uploadPhoto(File file) => _api.files.uploadFile(file: file);

  /// `PATCH /me`: `null` — «не менять» (сервер читает его как «не прислано»).
  Future<Me> updateProfile({String? name, String? photoFileId}) =>
      _api.users.patchMe(body: PatchMeBody(name: name, photoFileId: photoFileId, cityId: null, mode: null));

  /// `GET /me/complaints`: жалобы на пользователя, новые сверху.
  Future<List<Complaint>> complaints() => _api.users.myComplaints();
}
