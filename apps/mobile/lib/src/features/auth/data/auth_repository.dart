import 'package:api_client/api_client.dart';

/// Вход по номеру и коду из SMS (`/auth/*`).
class AuthRepository {
  AuthRepository(this._api);

  final TheWayApi _api;

  /// Запрашивает код; возвращает, через сколько секунд можно повторить.
  Future<int> requestCode(String phone) async =>
      (await _api.auth.requestCode(body: RequestCodeBody(phone: phone))).resendAfterSec;

  Future<VerifyResult> verify(String phone, String code) =>
      _api.auth.verify(body: VerifyBody(phone: phone, code: code));

  /// Сохраняет выбранные до входа город и роль существующего пользователя (`PATCH /me`).
  Future<void> saveChoice({int? cityId, UserMode? mode}) =>
      _api.users.patchMe(body: PatchMeBody(name: null, photoFileId: null, cityId: cityId, mode: mode));
}
