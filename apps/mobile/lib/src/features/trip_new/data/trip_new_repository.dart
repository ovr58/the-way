import 'package:api_client/api_client.dart';

import '../../orders/data/order_repository.dart';

/// Данные раздела «trip_new»: поверх `TheWayApi`, правил поездки здесь нет — их проверяет сервер.
class TripNewRepository {
  TripNewRepository(this._api);

  final TheWayApi _api;

  /// Подсказки адреса (`GET /geo/suggest`); [cityId] сужает поиск к городу профиля.
  Future<List<GeoSuggestion>> suggest(String q, {int? cityId}) =>
      _api.geo.suggestAddress(q: q, cityId: cityId);

  /// Города по имени (`GET /cities?q`).
  Future<List<City>> cities(String q) => _api.cities.listCities(q: q.isEmpty ? null : q);

  Future<List<RouteTemplate>> templates() => _api.trips.listRouteTemplates();

  Future<RouteTemplate> saveTemplate(List<StopInput> stops) =>
      _api.trips.createRouteTemplate(body: RouteTemplateInput(stops: stops));

  Future<List<Car>> cars() => _api.cars.listCars();

  Future<TripDetails> publish(TripInput input) => _api.trips.createTrip(body: input);

  Future<TripLimits> limits({required String carId, required String date}) =>
      _api.trips.tripLimits(carId: carId, date: date);

  Future<TripDetails> trip(String id) => _api.trips.getTrip(id: id);

  Future<TripDetails> reverse(String id, ReverseInput input) =>
      _api.trips.reverseTrip(id: id, body: input);

  /// Заказы пассажиров (общий шов строк Б2, Б3): публикация мастером заказа.
  OrderRepository get orders => OrderRepository(_api);

  Future<TripDetails> update(String id, TripPatch patch) =>
      _api.trips.updateTrip(id: id, body: patch);
}
