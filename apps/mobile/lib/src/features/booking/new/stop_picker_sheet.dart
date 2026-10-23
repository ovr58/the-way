import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/app_list_item.dart';
import '../../search/data/search_filter.dart';
import '../../search/details/route_block.dart';
import '../../search/filter/location_service.dart';

/// Поиск адреса («поиск адреса»): выбор из остановок поездки с фильтром по тексту на клиенте.
/// Лист `trip-data` кадра: белый, почти на весь экран, без заголовка — ручка, поле «Введите адрес»
/// с зелёной рамкой и зелёной меткой, под ним список на всю ширину. Возвращает `idx` остановки.
///
/// С [location] первая строка — «Ближайшая ко мне» (в кадре «Моё местоположение»): остановка из
/// [stops], ближайшая к телефону. Сесть можно только на остановке водителя (реестр 10), поэтому
/// строка выбирает остановку, а не адрес. Разрешение не спрашивается: нет его, положения или координат
/// у остановок — строки нет; при набранном тексте поиска — тоже.
Future<int?> showStopPicker(BuildContext context, {required List<Stop> stops, LocationService? location}) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.overlayScrim,
      builder: (_) => _StopPicker(stops: stops, location: location),
    );

class _StopPicker extends StatefulWidget {
  const _StopPicker({required this.stops, this.location});

  final List<Stop> stops;
  final LocationService? location;

  @override
  State<_StopPicker> createState() => _StopPickerState();
}

class _StopPickerState extends State<_StopPicker> {
  // Ручка листа в кадре — 43×5 (`Drag handle`), как у `AppBottomSheet`; у этого листа нет заголовка
  // и фон белый, поэтому лист свой.
  static const _handleWidth = 43.0;
  static const _handleHeight = 5.0;
  // Метка в поле: 12 от рамки, 16 до текста (`Text Field` кадра: 343 − поле текста 287 = 56).
  static const _pinLeft = 12.0;
  static const _pinGap = 16.0;

  String _query = '';

  // Остановка, ближайшая к телефону; `null` — положения нет или у остановок нет координат.
  Stop? _nearest;

  @override
  void initState() {
    super.initState();
    widget.location?.ifGranted().then((at) {
      if (at == null || !mounted) return;
      setState(() => _nearest = _closest(at));
    });
  }

  Stop? _closest(Coords at) {
    Stop? best;
    var bestDistance = double.infinity;
    for (final s in widget.stops) {
      final lat = s.lat, lng = s.lng;
      if (lat == null || lng == null) continue;
      final d = Geolocator.distanceBetween(at.lat, at.lng, lat.toDouble(), lng.toDouble());
      if (d < bestDistance) (best, bestDistance) = (s, d);
    }
    return best;
  }

  static const _pin = AppIcon('vuesax_bold_location', size: AppSize.icon24, color: AppColors.textSecondary);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = _query.trim().toLowerCase();
    final shown = widget.stops
        .where((s) => q.isEmpty || '${stopLabel(s)} ${s.cityName}'.toLowerCase().contains(q))
        .toList();
    final nearest = q.isEmpty ? _nearest : null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        key: const Key('stop_picker'),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSize.radius16)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: AppSize.pad8),
              Container(
                width: _handleWidth,
                height: _handleHeight,
                decoration: BoxDecoration(
                  color: AppColors.bgGrabber,
                  borderRadius: BorderRadius.circular(AppSize.radius16),
                ),
              ),
              const SizedBox(height: AppSize.gap8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
                child: _field(l10n),
              ),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Text(
                          l10n.bookingNothing,
                          style: AppType.body2.copyWith(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: shown.length + (nearest == null ? 0 : 1),
                        itemBuilder: (context, i) {
                          if (nearest != null && i == 0) {
                            return AppListItem(
                              key: const Key('stop_nearest'),
                              title: l10n.bookingNearestStop,
                              leading: _pin,
                              onTap: () => Navigator.of(context).pop(nearest.idx),
                            );
                          }
                          final s = shown[nearest == null ? i : i - 1];
                          final label = stopLabel(s);
                          return AppListItem(
                            title: label,
                            // Город второй строкой — только если его нет в первой (как в подсказках адреса).
                            subtitle: s.cityName.isEmpty || label.contains(s.cityName) ? null : s.cityName,
                            leading: _pin,
                            onTap: () => Navigator.of(context).pop(s.idx),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Поле `address` кадра: 48 в высоту, рамка `accent.primary` 1, скругление 8, метка слева.
  Widget _field(AppLocalizations l10n) => Container(
        height: AppSize.height48,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppSize.radius8),
          border: Border.all(color: AppColors.accentPrimary, width: AppSize.stroke1),
        ),
        padding: const EdgeInsets.only(left: _pinLeft, right: AppSize.pad16),
        child: Row(
          children: [
            const AppIcon('vuesax_bold_location', size: AppSize.icon24, color: AppColors.accentPrimary),
            const SizedBox(width: _pinGap),
            Expanded(
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: AppType.body2.copyWith(color: AppColors.textPrimary),
                cursorColor: AppColors.accentPrimary,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: l10n.bookingAddressPlaceholder,
                  hintStyle: AppType.body2.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      );
}
