import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_header.dart';

/// Каркас шага мастера: шапка «Новый заказ», подпись «Шаг N из 6» (у заказа пассажира — «из 3»), прокручиваемое тело и
/// закреплённая панель кнопок на `bg.surface` с безопасной зоной снизу (CTA кадра без заливки —
/// ошибка импорта, раздел «Вёрстка» плана).
class WizardScaffold extends StatelessWidget {
  const WizardScaffold({
    super.key,
    required this.body,
    required this.bottom,
    this.title,
    this.step,
    this.onBack,
    this.hideBottom = false,
    this.dismissKeyboardOnDrag = true,
    this.order = false,
  });

  /// Мастер заказа пассажира: подпись «Шаг N из 3».
  final bool order;

  /// Заголовок шапки; по умолчанию «Новый заказ».
  final String? title;

  /// Номер шага для подписи «Шаг N из 6»; `null` — подписи нет (правка, итог).
  final int? step;
  final List<Widget> body;
  final Widget bottom;
  final VoidCallback? onBack;

  /// Панель кнопок скрыта (на шаге 2 — пока поле адреса в фокусе: иначе она поднимается над клавиатурой
  /// и закрывает список подсказок).
  final bool hideBottom;

  /// Прокрутка тела закрывает клавиатуру. Выключено там, где поле адреса с подсказками: прокрутка списка
  /// не снимает фокус и не сбрасывает подсказки.
  final bool dismissKeyboardOnDrag;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(
            title: title ?? l10n.tripNewTitle,
            onBack: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: dismissKeyboardOnDrag
                  ? ScrollViewKeyboardDismissBehavior.onDrag
                  : ScrollViewKeyboardDismissBehavior.manual,
              padding: const EdgeInsets.only(top: AppSize.pad20, bottom: AppSize.pad20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (step != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
                      child: Text(
                        order ? l10n.orderStep(step!) : l10n.tripNewStep(step!),
                        textAlign: TextAlign.right,
                        style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: AppSize.gap20),
                  ],
                  for (var i = 0; i < body.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSize.gap20),
                    body[i],
                  ],
                ],
              ),
            ),
          ),
          if (!hideBottom)
            Container(
            color: AppColors.bgSurface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSize.pad16),
                child: bottom,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Блок экрана: заголовок 15/600 над белой карточкой (радиус 12, поля 16/12), как в кадрах.
class WizardSection extends StatelessWidget {
  const WizardSection({super.key, required this.title, required this.child, this.padding});

  final String title;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
          child: Text(title, style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
        ),
        const SizedBox(height: AppSize.gap12),
        WizardCard(padding: padding, child: child),
      ],
    );
  }
}

/// Белая карточка без внешних полей.
class WizardCard extends StatelessWidget {
  const WizardCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: AppSize.pad16, vertical: AppSize.pad12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppSize.radius12),
      ),
      child: child,
    );
  }
}
