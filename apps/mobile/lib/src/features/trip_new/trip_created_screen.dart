import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_size.dart';
import '../../theme/app_type.dart';
import '../../widgets/app_button.dart';
import '../../widgets/success_badge.dart';
import 'data/trip_new_repository.dart';
import 'limit_screen.dart';
import 'moscow_time.dart';

/// «Заказ опубликован!» («Новый заказ - Заказ создан») и итог обратной поездки («Обратное направление - Заказ создан»): шкалы из `GET /trips/limits` — у «Новый заказ - Заказ создан»
/// «Туда / Обратно», у «Обратное направление - Заказ создан» «Сегодня / На неделе», как нарисованы. После обычной поездки — «Добавить обратный маршрут» (→ `trip_new/return`)
/// и «Смотреть мои заказы»; после обратной (`reverseOf ≠ null`) — только «Мои заказы».
class TripCreatedScreen extends StatefulWidget {
  const TripCreatedScreen({super.key, required this.trip, required this.repository, this.respond = false});

  /// Поездка — отклик на заказ пассажира: текст «Отклик отправлен…».
  final bool respond;

  final TripDetails trip;
  final TripNewRepository repository;

  @override
  State<TripCreatedScreen> createState() => _TripCreatedScreenState();
}

class _TripCreatedScreenState extends State<TripCreatedScreen> {
  // Промежуток между блоком «иллюстрация + текст» и карточкой лимита в кадре — 40; в шкале ступени нет.
  static const _groupGap = 40.0;

  late final Future<TripLimits> _limits = widget.repository.limits(
    carId: widget.trip.car.id,
    date: isoDate(toMoscow(widget.trip.departsAt).$1),
  );

  TripDetails get trip => widget.trip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final isReturn = trip.reverseOf != null;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bgScreen,
        body: SafeArea(
          child: FutureBuilder<TripLimits>(
            future: _limits,
            builder: (context, snapshot) {
              final limits = snapshot.data;
              return Column(
                children: [
                  Expanded(
                    // Содержимое стоит по центру высоты (`notification-elements` кадра, `jc: center`).
                    child: LayoutBuilder(
                      builder: (context, box) => SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSize.pad16),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight - AppSize.pad16 * 2),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SuccessBadge(),
                                const SizedBox(height: AppSize.gap8),
                                Text(
                                  l10n.tripNewCreatedTitle,
                                  textAlign: TextAlign.center,
                                  style: AppType.title2.copyWith(color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: AppSize.gap8),
                                Text(
                                  widget.respond ? l10n.orderRespondCreatedBody : l10n.tripNewCreatedBody,
                                  textAlign: TextAlign.center,
                                  style: AppType.body2.copyWith(color: AppColors.textSecondary),
                                ),
                                if (limits != null) ...[
                                  const SizedBox(height: _groupGap),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(AppSize.pad16),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgSurface,
                                      borderRadius: BorderRadius.circular(AppSize.radius12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          l10n.tripNewCreatedLimits,
                                          textAlign: TextAlign.center,
                                          style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: AppSize.gap12),
                                        if (isReturn)
                                          WeekLimitBars(limits: limits, date: toMoscow(trip.departsAt).$1)
                                        else
                                          LimitBars(forwardUsed: limits.forwardUsed, reverseUsed: limits.reverseUsed),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    color: AppColors.bgSurface,
                    padding: const EdgeInsets.all(AppSize.pad16),
                    child: isReturn
                        ? AppButton(
                            label: l10n.tripNewCreatedOrdersShort,
                            onPressed: () => openDriverTrips(navigator),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if ((limits?.reverseUsed ?? 0) < 1) ...[
                                AppButton(
                                  label: l10n.tripNewCreatedReverse,
                                  size: AppButtonSize.medium,
                                  onPressed: () => navigator.pushNamed(AppRoutes.tripNewReturn, arguments: trip.id),
                                ),
                                const SizedBox(height: AppSize.gap8),
                              ],
                              AppButton(
                                label: l10n.tripNewCreatedOrders,
                                kind: AppButtonKind.outline,
                                size: AppButtonSize.medium,
                                onPressed: () => openDriverTrips(navigator),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
