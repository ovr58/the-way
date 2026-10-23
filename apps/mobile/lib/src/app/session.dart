import 'package:api_client/api_client.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Держатель сессии приложения: токен, профиль `me` и состояние до входа.
///
/// Токен и флаги до входа лежат в защищённом хранилище платформы; `me` — в памяти, его читает
/// [refresh]. Доступ из дерева — [AppSession.of].
class AppSession extends ChangeNotifier {
  AppSession(
    this._storage, {
    String? token,
    bool onboardingDone = false,
    UserMode? pendingMode,
    int? pendingCityId,
    bool geoPromptShown = false,
  }) {
    _token = token;
    _onboardingDone = onboardingDone;
    _pendingMode = pendingMode;
    _pendingCityId = pendingCityId;
    _geoPromptShown = geoPromptShown;
  }

  static const _kToken = 'session_token';
  static const _kOnboardingDone = 'onboarding_done';
  static const _kPendingMode = 'pending_mode';
  static const _kPendingCityId = 'pending_city_id';
  static const _kGeoPromptShown = 'geo_prompt_shown';

  /// Читает сохранённое состояние из хранилища.
  static Future<AppSession> restore(FlutterSecureStorage storage) async {
    final values = await storage.readAll();
    return AppSession(
      storage,
      token: values[_kToken],
      onboardingDone: values[_kOnboardingDone] == '1',
      pendingMode: values[_kPendingMode] == null ? null : UserMode.fromJson(values[_kPendingMode]!),
      pendingCityId: int.tryParse(values[_kPendingCityId] ?? ''),
      geoPromptShown: values[_kGeoPromptShown] == '1',
    );
  }

  /// Ближайший [AppSession] выше по дереву; перестраивает виджет при изменении сессии.
  static AppSession of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSessionScope>()!.notifier!;

  /// То же, но без [AppSession] в дереве возвращает `null` (виджеты в тестах).
  static AppSession? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSessionScope>()?.notifier;

  final FlutterSecureStorage _storage;

  /// API приложения; ставится один раз при сборке приложения (клиент нужен [Dio]-перехватчикам,
  /// которым нужна сессия, поэтому она создаётся раньше).
  late TheWayApi api;

  String? _token;
  bool _onboardingDone = false;
  UserMode? _pendingMode;
  int? _pendingCityId;
  bool _geoPromptShown = false;

  /// Профиль текущего пользователя; `null` до первого [refresh] или входа.
  Me? me;

  String? get token => _token;
  bool get isSignedIn => _token != null;
  bool get onboardingDone => _onboardingDone;
  UserMode? get pendingMode => _pendingMode;
  int? get pendingCityId => _pendingCityId;
  bool get geoPromptShown => _geoPromptShown;

  /// Режим экрана: из профиля, пока профиль не загружен — выбранный на онбординге, иначе пассажир.
  UserMode get mode => me?.mode ?? _pendingMode ?? UserMode.passenger;

  set onboardingDone(bool value) {
    _onboardingDone = value;
    _write(_kOnboardingDone, value ? '1' : null);
    notifyListeners();
  }

  set pendingMode(UserMode? value) {
    _pendingMode = value;
    _write(_kPendingMode, value?.json);
    notifyListeners();
  }

  set pendingCityId(int? value) {
    _pendingCityId = value;
    _write(_kPendingCityId, value?.toString());
    notifyListeners();
  }

  set geoPromptShown(bool value) {
    _geoPromptShown = value;
    _write(_kGeoPromptShown, value ? '1' : null);
    notifyListeners();
  }

  /// Принимает токен после `POST /auth/verify`; профиль можно передать сразу.
  Future<void> signIn(String token, {Me? me}) async {
    _token = token;
    this.me = me;
    await _write(_kToken, token);
    notifyListeners();
  }

  /// Перечитывает профиль (`GET /me`).
  Future<void> refresh() async {
    me = await api.users.getMe();
    notifyListeners();
  }

  /// Меняет режим (`PATCH /me`); оболочка перестраивает вкладки.
  Future<void> setMode(UserMode mode) async {
    me = await api.users.patchMe(
      body: PatchMeBody(name: null, photoFileId: null, cityId: null, mode: mode),
    );
    notifyListeners();
  }

  /// Выход. [remote] `false` — только очистка токена, без запроса к серверу (токен уже отвергнут).
  Future<void> logout({bool remote = true}) async {
    if (remote && _token != null) {
      try {
        await api.auth.logout();
      } catch (_) {
        // Токен снимается в любом случае: выход не должен зависеть от сети.
      }
    }
    _token = null;
    me = null;
    await _write(_kToken, null);
    notifyListeners();
  }

  Future<void> _write(String key, String? value) async {
    try {
      if (value == null) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: value);
      }
    } catch (_) {
      // Хранилище недоступно — состояние живёт в памяти до закрытия приложения.
    }
  }
}

/// Кладёт [AppSession] в дерево.
class AppSessionScope extends InheritedNotifier<AppSession> {
  const AppSessionScope({super.key, required AppSession session, required super.child})
      : super(notifier: session);
}
