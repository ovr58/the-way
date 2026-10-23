import 'dart:io';

import 'package:api_client/api_client.dart';

/// Создание профиля: загрузка фото и сохранение профиля (`POST /files`, `PATCH /me`).
class ProfileSetupRepository {
  ProfileSetupRepository(this._api);

  final TheWayApi _api;

  Future<FileRef> uploadPhoto(File file) => _api.files.uploadFile(file: file);

  /// Имя, фото, город и роль уходят одним запросом; `null` — «не менять».
  Future<Me> save({required String name, String? photoFileId, int? cityId, UserMode? mode}) => _api.users.patchMe(
        body: PatchMeBody(name: name, photoFileId: photoFileId, cityId: cityId, mode: mode),
      );
}
