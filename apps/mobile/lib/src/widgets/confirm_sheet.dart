import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';

/// Окно подтверждения действия по образцу «Новый заказ - Выбор доп услуг» («Опубликовать поездку?»): нижний лист с ручкой,
/// заголовком, пояснением и двумя кнопками в ряд — «назад» (контур) слева, действие (заливка) справа.
/// Действие запускается после закрытия листа.
Future<void> showConfirmSheet(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  required String backLabel,
  required VoidCallback onConfirm,
}) =>
    AppBottomSheet.show<void>(
      context,
      title: title,
      child: ConfirmSheet(body: body, confirmLabel: confirmLabel, backLabel: backLabel, onConfirm: onConfirm),
    );

/// Тело листа [showConfirmSheet]: пояснение и ряд кнопок.
class ConfirmSheet extends StatelessWidget {
  const ConfirmSheet({
    super.key,
    this.body,
    required this.confirmLabel,
    required this.backLabel,
    required this.onConfirm,
  });

  final String? body;
  final String confirmLabel;
  final String backLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (body != null) ...[
            Text(body!, style: AppType.body2.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSize.gap16),
          ],
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: backLabel,
                  kind: AppButtonKind.outline,
                  size: AppButtonSize.medium,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: AppSize.gap8),
              Expanded(
                child: AppButton(
                  label: confirmLabel,
                  size: AppButtonSize.medium,
                  onPressed: () {
                    Navigator.of(context).pop();
                    onConfirm();
                  },
                ),
              ),
            ],
          ),
        ],
      );
}
