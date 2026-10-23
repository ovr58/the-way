import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_radio.dart';
import '../trip_new_actions.dart';
import '../wizard_controller.dart';
import 'publish_dialog.dart';
import 'wizard_scaffold.dart';

/// Шаг 6 из 6 — тип бронирования («Новый заказ - Выбор доп услуг»): «Стандартное» или «Быстрое бронирование»;
/// «Опубликовать поездку» открывает окно подтверждения, «Сохранить шаблон» сохраняет маршрут.
class BookingModeStep extends StatelessWidget {
  const BookingModeStep({super.key, required this.controller});

  final WizardController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => WizardScaffold(
        step: 6,
        body: [
          WizardSection(
            title: l10n.tripNewModeTitle,
            child: Column(
              children: [
                _ModeCard(
                  title: l10n.tripNewModeStandard,
                  subtitle: l10n.tripNewModeStandardHint,
                  points: [
                    l10n.tripNewModeStandard1,
                    l10n.tripNewModeStandard2,
                    l10n.tripNewModeStandard3,
                    l10n.tripNewModeStandard4,
                  ],
                  selected: controller.bookingMode == BookingMode.standard,
                  onTap: () => controller.setBookingMode(BookingMode.standard),
                ),
                const SizedBox(height: AppSize.gap12),
                _ModeCard(
                  title: l10n.tripNewModeInstant,
                  subtitle: l10n.tripNewModeInstantHint,
                  points: [
                    l10n.tripNewModeInstant1,
                    l10n.tripNewModeInstant2,
                    l10n.tripNewModeInstant3,
                  ],
                  selected: controller.bookingMode == BookingMode.instant,
                  onTap: () => controller.setBookingMode(BookingMode.instant),
                ),
              ],
            ),
          ),
        ],
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: l10n.tripNewPublish,
              size: AppButtonSize.medium,
              onPressed: controller.readyToPublish ? () => publishTrip(context, controller) : null,
            ),
            const SizedBox(height: AppSize.gap8),
            AppButton(
              label: l10n.tripNewSaveTemplate,
              kind: AppButtonKind.outline,
              size: AppButtonSize.medium,
              onPressed: controller.routeComplete
                  ? () => saveRouteTemplate(ScaffoldMessenger.of(context), l10n, controller)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.points,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<String> points;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSize.radius12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSize.pad12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSize.radius12),
            border: Border.all(
              color: selected ? AppColors.accentPrimary : AppColors.borderDefault,
              width: AppSize.stroke1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.titlesFootnote.copyWith(color: AppColors.textPrimary)),
                    Text(subtitle, style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: AppSize.gap8),
                    for (final point in points)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSize.pad2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary)),
                            Expanded(
                              child: Text(point, style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSize.gap12),
              AppRadio(selected: selected, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}
