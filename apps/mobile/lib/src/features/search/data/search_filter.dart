import 'package:api_client/api_client.dart';

/// Координаты клиента для `GET /trips` («3.2 км», «Поблизости»).
class Coords {
  const Coords(this.lat, this.lng);

  final double lat;
  final double lng;
}

/// Фильтр ленты («Фильтр»): «Откуда / Куда», «Поблизости (30 км)», «Поездки / Посылки».
class SearchFilter {
  const SearchFilter({this.from, this.to, this.near = false, this.kind});

  final City? from;
  final City? to;
  final bool near;
  /// Выбор «Поездки / Посылки»; `null` — не выбрано, лента несёт и то, и другое.
  final TripKind? kind;

  static const empty = SearchFilter();

  /// Задано ли что-то сверх значений по умолчанию (красная точка у кнопки фильтра, «Фильтр- поездок нет»).
  bool get isActive => from != null || to != null || near || kind != null;

  SearchFilter copyWith({
    City? from,
    City? to,
    bool? near,
    TripKind? kind,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearKind = false,
  }) =>
      SearchFilter(
        from: clearFrom ? null : (from ?? this.from),
        to: clearTo ? null : (to ?? this.to),
        near: near ?? this.near,
        kind: clearKind ? null : (kind ?? this.kind),
      );
}
