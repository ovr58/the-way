import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/expand_toggle.dart';
import '../../../widgets/trip_card_view.dart';

/// Подпись остановки: адрес, а если его нет — город.
String stopLabel(Stop s) => stopAddress(s);

/// Маршрут поездки (`Component 2` «Детали поездки - Места есть», `Component 4` «Бронирование»): старт, промежуточные остановки, финиш.
///
/// Промежуточные остановки свёрнуты в кнопку «N остановок ⌄». Нажатие — одно
/// движение 350 мс easeInOut: остановки разворачиваются (высота и прозрачность), кнопка сжимается в круг, текст
/// растворяется, стрелка поворачивается вверх, кнопка уезжает вправо от списка; нажатие на круг — то же
/// зеркально, «N остановок ⌄» встаёт на прежнее место. Только встроенные неявные анимации Flutter; движение
/// не зависит от системной настройки «уменьшить движение». Блок один на все экраны: поиск, бронь, поездки
/// пассажира и водителя.
class RouteBlock extends StatefulWidget {
  const RouteBlock({super.key, required this.stops});

  final List<Stop> stops;

  @override
  State<RouteBlock> createState() => _RouteBlockState();
}

class _RouteBlockState extends State<RouteBlock> {
  // Значки маршрута в кадре: квадрат 10, круг 6, линия 22 — в шкале размеров этих ступеней нет.
  static const _point = 10.0;
  static const _stopDot = 6.0;
  static const _lineHeight = 22.0;
  // Подпись кнопки начинается за точкой остановки: поле 2 + точка 6 + промежуток 12.
  static const _chipLeft = AppSize.pad2 + _stopDot + AppSize.gap12;

  bool _expanded = false;

  Widget _line() => SizedBox(
        width: _point,
        height: _lineHeight,
        child: Center(child: Container(width: AppSize.stroke1, color: AppColors.textPrimary)),
      );

  Widget _stopRow(String text, {Widget? trailing}) => Row(
        children: [
          const SizedBox(width: AppSize.pad2),
          Container(
            width: _stopDot,
            height: _stopDot,
            decoration: const BoxDecoration(color: AppColors.textSecondary, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSize.gap12),
          if (trailing != null)
            trailing
          else
            Expanded(child: Text(text, style: AppType.bodyFootnote.copyWith(color: AppColors.textPrimary))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stops = widget.stops;
    if (stops.isEmpty) return const SizedBox.shrink();
    final middle = stops.length > 2 ? stops.sublist(1, stops.length - 1) : const <Stop>[];
    final style = AppType.body2.copyWith(color: AppColors.textPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: _point,
              height: _point,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(AppSize.radius2),
              ),
            ),
            const SizedBox(width: AppSize.gap8),
            Expanded(child: Text(stopLabel(stops.first), style: style)),
          ],
        ),
        if (middle.isNotEmpty) ...[
          _line(),
          SizedBox(
            width: double.infinity,
            child: Stack(
              children: [
                AnimatedSize(
                  duration: expandDuration,
                  curve: expandCurve,
                  alignment: Alignment.topLeft,
                  child: AnimatedSwitcher(
                    duration: expandDuration,
                    switchInCurve: expandCurve,
                    switchOutCurve: expandCurve,
                    layoutBuilder: (current, previous) =>
                        Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
                    child: _expanded
                        ? Padding(
                            key: const ValueKey('stops'),
                            // Справа место под круглую кнопку: список не уходит под неё.
                            padding: const EdgeInsets.only(right: AppSize.height24 + AppSize.gap8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < middle.length; i++) ...[
                                  if (i > 0) _line(),
                                  _stopRow(stopLabel(middle[i])),
                                ],
                              ],
                            ),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('chip-row'),
                            child: _stopRow('', trailing: const SizedBox(height: AppSize.height24)),
                          ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedAlign(
                    duration: expandDuration,
                    curve: expandCurve,
                    alignment: _expanded ? Alignment.centerRight : Alignment.topLeft,
                    child: AnimatedPadding(
                      duration: expandDuration,
                      curve: expandCurve,
                      padding: EdgeInsets.only(left: _expanded ? 0 : _chipLeft),
                      child: ExpandToggle(
                        label: l10n.tripCardStops(middle.length),
                        expanded: _expanded,
                        // Ключ — по состоянию: «route_stops_chip» у таблетки, «route_stops_collapse» у круга.
                        chipKey: const Key('route_stops_chip'),
                        closeKey: const Key('route_stops_collapse'),
                        onTap: () => setState(() => _expanded = !_expanded),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (stops.length > 1) ...[
          _line(),
          Row(
            children: [
              Container(
                width: _point,
                height: _point,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSize.radius2),
                  border: Border.all(color: AppColors.textPrimary, width: AppSize.stroke2),
                ),
              ),
              const SizedBox(width: AppSize.gap8),
              Expanded(child: Text(stopLabel(stops.last), style: style)),
            ],
          ),
        ],
      ],
    );
  }
}
