import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/trip_card_view.dart';

/// Адрес остановки; без адреса — город.
String stopText(Stop s) => stopAddress(s);

/// «16 мая, 12:00–15:00».
String tripRange(AppLocalizations l10n, DateTime departs, DateTime arrives) => l10n.driverTripsRange(
      DateFormat('d MMMM', 'ru').format(moscowTime(departs)),
      formatTripTime(departs),
      formatArrival(departs, arrives),
    );

/// Значок и подпись (`tag` кадра): 14 и текст 15.
class IconTag extends StatelessWidget {
  const IconTag({super.key, required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: AppSize.icon14, color: AppColors.textSecondary),
          const SizedBox(width: AppSize.gap4),
          Flexible(child: Text(text, style: AppType.body2.copyWith(color: AppColors.textPrimary))),
        ],
      );
}

/// Концы маршрута на карточке: старт (заливка), линия, финиш (контур).
class TripWay extends StatelessWidget {
  const TripWay({super.key, required this.from, required this.to, this.stops});

  final String from;
  final String to;

  /// «1 остановка» — строка с точкой между началом и концом, как на карточке пассажира.
  final String? stops;

  // Значок точки в кадре — 10, линия — 20; таких ступеней в шкале размеров нет.
  static const _point = 10.0;
  static const _line = 20.0;
  static const _stopDot = 6.0;

  @override
  Widget build(BuildContext context) {
    final style = AppType.body2.copyWith(color: AppColors.textPrimary);
    final line = SizedBox(
      width: _point,
      height: _line,
      child: Center(child: Container(width: AppSize.stroke1, color: AppColors.textPrimary)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: _point,
              height: _point,
              decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(AppSize.radius2)),
            ),
            const SizedBox(width: AppSize.gap8),
            Expanded(child: Text(from, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
          ],
        ),
        line,
        if (stops != null) ...[
          Row(
            children: [
              const SizedBox(width: AppSize.pad2),
              Container(
                width: _stopDot,
                height: _stopDot,
                decoration: const BoxDecoration(color: AppColors.textPrimary, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSize.gap12),
              Text(stops!, style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          line,
        ],
        Row(
          children: [
            Container(
              width: _point,
              height: _point,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.textPrimary, width: AppSize.stroke2),
                borderRadius: BorderRadius.circular(AppSize.radius2),
              ),
            ),
            const SizedBox(width: AppSize.gap8),
            Expanded(child: Text(to, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
          ],
        ),
      ],
    );
  }
}
