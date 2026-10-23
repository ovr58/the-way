import 'package:api_client/api_client.dart';

import 'search_filter.dart';

/// Данные раздела «search»: лента, детали поездки, города. Только вызовы API, правил нет.
class SearchRepository {
  const SearchRepository(this._api);

  final TheWayApi _api;

  /// Лента `GET /trips`: порядок — как пришёл с сервера (без города из профиля).
  /// Координаты кладутся в каждый запрос, если известны; `near` — только вместе с ними.
  /// [vehicleKind] — вкладка ленты: «Автомобили» или «Автобусы».
  Future<List<TripCard>> trips(SearchFilter filter, {Coords? where, VehicleKind vehicleKind = VehicleKind.car}) =>
      _api.trips.searchTrips(
        fromCityId: filter.from?.id,
        toCityId: filter.to?.id,
        lat: where?.lat,
        lng: where?.lng,
        near: filter.near && where != null ? true : null,
        kind: filter.kind,
        vehicleKind: vehicleKind,
      );

  Future<TripDetails> trip(String id) => _api.trips.getTrip(id: id);

  /// Профиль водителя: публичные данные и отзывы о нём, новые сверху.
  Future<UserBrief> user(String id) => _api.users.getPublicUser(id: id);

  Future<List<Review>> reviews(String id) => _api.reviews.listUserReviews(id: id);

  /// `GET /cities?q`.
  Future<List<City>> cities(String q) => _api.cities.listCities(q: q.isEmpty ? null : q);
}
