import 'package:geolocator/geolocator.dart';

import '../data/search_filter.dart';

/// Координаты телефона. Системный диалог разрешения («Запрос - Экран системы Android») показывает сам `geolocator`.
abstract class LocationService {
  /// Координаты, если разрешение уже выдано (без диалога); иначе `null`.
  Future<Coords?> ifGranted();

  /// Просит разрешение (системный диалог) и отдаёт координаты; отказ или выключенная
  /// геолокация — `null`.
  Future<Coords?> request();
}

class GeolocatorService implements LocationService {
  const GeolocatorService();

  static const _settings = LocationSettings(
    accuracy: LocationAccuracy.low,
    timeLimit: Duration(seconds: 10),
  );

  /// Текущее место; не определилось за [_settings] (нет фикса, таймаут) — последнее известное.
  Future<Coords?> _position() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final p = await Geolocator.getCurrentPosition(locationSettings: _settings);
      return Coords(p.latitude, p.longitude);
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        return last == null ? null : Coords(last.latitude, last.longitude);
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Future<Coords?> ifGranted() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
        return null;
      }
    } catch (_) {
      return null;
    }
    return _position();
  }

  @override
  Future<Coords?> request() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
        return null;
      }
    } catch (_) {
      return null;
    }
    return _position();
  }
}
