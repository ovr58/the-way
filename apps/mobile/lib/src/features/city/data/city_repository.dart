import 'package:api_client/api_client.dart';

/// Справочник городов (`GET /cities`).
class CityRepository {
  CityRepository(this._api);

  final TheWayApi _api;

  /// Все города в порядке сервера (`orderBy(name)`); поиск по тексту делает экран на клиенте (список один раз на экран).
  Future<List<City>> all() => _api.cities.listCities();
}
