import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../widgets/app_button.dart';
import 'consent_text.dart';

/// Нижняя панель `CTA`: линия сверху `border.default`, фон экрана, поля 8/16, безопасная зона
/// снизу. [withConsent] — строка согласия над кнопками: в кадрах она видна только на вводе телефона
/// («Вход - Ввод номера (данные введены)» – «Вход - Базовый экран»), на остальных экранах с этой панелью слой скрыт — поэтому по умолчанию её нет.
class CtaBar extends StatelessWidget {
  const CtaBar({super.key, required this.children, this.withConsent = false});

  final List<Widget> children;
  final bool withConsent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bgScreen,
        border: Border(top: BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSize.pad8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (withConsent) ...[const ConsentText(), const SizedBox(height: AppSize.gap8)],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSize.gap8),
                      children[i],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Основная кнопка панели: зелёная, пока действие доступно, иначе серый контур (как в кадрах).
class CtaButton extends StatelessWidget {
  const CtaButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => AppButton(
        label: label,
        onPressed: onPressed,
        loading: loading,
        kind: onPressed == null && !loading ? AppButtonKind.neutral : AppButtonKind.primary,
      );
}
