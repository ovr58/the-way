import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_size.dart';
import '../../theme/app_type.dart';
import '../../widgets/app_button.dart';
import 'data/trip_new_repository.dart';
import 'moscow_time.dart';
import 'trip_new_actions.dart';
import 'trip_new_images.dart';
import 'wizard_controller.dart';

/// Из мастера в «Мои заказы» водителя: вкладка 1 оболочки в режиме водителя — `driver_trips`.
void openDriverTrips(NavigatorState navigator) {
  navigator.pushNamedAndRemoveUntil(AppRoutes.shell, (_) => false, arguments: 1);
}

/// Окно «Достигнут лимит на сегодня» («Новый заказ - Маршрут сохранен», на `limit_reached`): шкалы «Туда / Обратно» из
/// `GET /trips/limits`; неделя выбрана — «Достигнут лимит на неделю», «Следующая публикация — с
/// понедельника» и шкалы «Сегодня / На неделе» (дополнение, кадра нет); «Сохранить как шаблон» (только из мастера — есть [controller]) и
/// «Отмена»; оба уходят в `driver_trips`.
Future<void> showLimitDialog(
  NavigatorState navigator,
  ScaffoldMessengerState messenger, {
  required TripNewRepository repository,
  required String carId,
  required DateTime date,
  WizardController? controller,
}) {
  final l10n = AppLocalizations.of(navigator.context);
  return showDialog<void>(
    context: navigator.context,
    barrierColor: AppColors.overlayScrim,
    builder: (_) => LimitScreen(
      repository: repository,
      carId: carId,
      date: date,
      onSaveTemplate: controller == null
          ? null
          : () async {
              await saveRouteTemplate(messenger, l10n, controller);
              navigator.pop();
              openDriverTrips(navigator);
            },
      onCancel: () {
        navigator.pop();
        openDriverTrips(navigator);
      },
    ),
  );
}

class LimitScreen extends StatefulWidget {
  const LimitScreen({
    super.key,
    required this.repository,
    required this.carId,
    required this.date,
    required this.onCancel,
    this.onSaveTemplate,
  });

  final TripNewRepository repository;
  final String carId;
  final DateTime date;
  final VoidCallback onCancel;

  /// `null` — кнопки «Сохранить как шаблон» нет (обратная поездка).
  final VoidCallback? onSaveTemplate;

  // Картинка кадра — 79×70.
  @override
  State<LimitScreen> createState() => _LimitScreenState();
}

class _LimitScreenState extends State<LimitScreen> {
  static const _imageWidth = 79.0;
  static const _imageHeight = 70.0;

  late final Future<TripLimits> _limits =
      widget.repository.limits(carId: widget.carId, date: isoDate(widget.date));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: AppColors.bgScreen,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSize.radius12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSize.pad16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Image.asset(TripNewImages.limit, width: _imageWidth, height: _imageHeight, fit: BoxFit.cover)),
            const SizedBox(height: AppSize.gap16),
            FutureBuilder<TripLimits>(
              future: _limits,
              builder: (context, snapshot) {
                final limits = snapshot.data;
                final week = limits != null && limits.weekUsed >= limits.weekLimit;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      week ? l10n.tripNewLimitWeekTitle : l10n.tripNewLimitTitle,
                      textAlign: TextAlign.center,
                      style: AppType.title3.copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: AppSize.gap8),
                    Text(
                      week
                          ? l10n.tripNewLimitWeekBody
                          : l10n.tripNewLimitBody(limits == null ? 2 : limits.forwardUsed + limits.reverseUsed),
                      textAlign: TextAlign.center,
                      style: AppType.body2.copyWith(color: AppColors.textSecondary),
                    ),
                    if (limits != null) ...[
                      const SizedBox(height: AppSize.gap20),
                      if (week) WeekLimitBars(limits: limits, date: widget.date) else LimitBars(forwardUsed: limits.forwardUsed, reverseUsed: limits.reverseUsed),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: AppSize.gap20),
            if (widget.onSaveTemplate != null) ...[
              AppButton(
                label: l10n.tripNewLimitSaveTemplate,
                size: AppButtonSize.medium,
                onPressed: widget.onSaveTemplate,
              ),
              const SizedBox(height: AppSize.gap4),
            ],
            AppButton(
              label: l10n.commonCancel,
              kind: AppButtonKind.outline,
              size: AppButtonSize.medium,
              onPressed: widget.onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

/// Шкалы «Туда 1/1» и «Обратно 0/1» («Новый заказ - Маршрут сохранен», «Новый заказ - Заказ создан», «Обратное направление - Заказ создан»; суточный предел 1).
class LimitBars extends StatelessWidget {
  const LimitBars({super.key, required this.forwardUsed, required this.reverseUsed});

  final int forwardUsed;
  final int reverseUsed;

  // Суточный предел поездок в каждом направлении.
  static const _max = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _Bar(label: l10n.tripNewLimitThere, used: forwardUsed, max: _max, text: l10n.tripNewLimitUsed(forwardUsed, _max)),
        const SizedBox(height: AppSize.gap20),
        _Bar(label: l10n.tripNewLimitBack, used: reverseUsed, max: _max, text: l10n.tripNewLimitUsed(reverseUsed, _max)),
      ],
    );
  }
}

/// Шкалы «Сегодня 2/2» и «На неделе 3/10» рядом, в две колонки («Обратное направление - Заказ создан»): сутки — обе публикации дня выезда [date], неделя — из
/// `weekUsed` / `weekLimit` `GET /trips/limits`. Подпись суток — «Сегодня», если выезд сегодня, иначе дата
/// выезда «24 октября», как в карточке поездки.
class WeekLimitBars extends StatelessWidget {
  const WeekLimitBars({super.key, required this.limits, required this.date});

  final TripLimits limits;

  /// Московская дата выезда публикуемой поездки.
  final DateTime date;

  // Публикаций в сутки: «туда» и обратная (по одной, `LimitBars._max`).
  static const _dayMax = LimitBars._max * 2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = limits.forwardUsed + limits.reverseUsed;
    final dayLabel = date == moscowToday() ? l10n.tripNewLimitToday : DateFormat('d MMMM', 'ru').format(date);
    // Две колонки поровну с промежутком 20 («Обратное направление - Заказ создан», `order-info`: `flex row gap 20`).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _Bar(label: dayLabel, used: today, max: _dayMax, text: l10n.tripNewLimitUsed(today, _dayMax))),
        const SizedBox(width: AppSize.gap20),
        Expanded(
          child: _Bar(
            label: l10n.tripNewLimitWeek,
            used: limits.weekUsed,
            max: limits.weekLimit,
            text: l10n.tripNewLimitUsed(limits.weekUsed, limits.weekLimit),
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.used, required this.max, required this.text});

  final String label;
  final int used;
  final int max;
  final String text;

  // Толщина шкалы кадра — 7.
  static const _height = 7.0;

  @override
  Widget build(BuildContext context) {
    final fill = max <= 0 ? 1.0 : (used / max).clamp(0.0, 1.0).toDouble();
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppType.body2.copyWith(color: AppColors.textSecondary))),
            Text(text, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: AppSize.gap12),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSize.radiusFull),
          child: SizedBox(
            height: _height,
            child: ColoredBox(
              color: AppColors.borderMuted,
              // Заполнено на долю «использовано / предел» («Обратное направление - Заказ создан» «На неделе 3/10»); у суточных шкал — 0 или вся.
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fill,
                  heightFactor: 1,
                  child: const ColoredBox(color: AppColors.accentPrimary),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
