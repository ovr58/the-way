import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';

/// Кнопка окна: [primary] — жирная (действие), иначе обычная (отмена).
class AppDialogAction {
  const AppDialogAction(this.label, {this.primary = false, this.onPressed});

  final String label;
  final bool primary;

  /// Окно закрывается само перед вызовом.
  final VoidCallback? onPressed;
}

/// Окно («Профиль - Базовый экран» «Выйдите из аккаунта?»): серый фон 270, заголовок, текст, кнопки столбцом с
/// разделителями. Показывается поверх `overlay.scrim`.
class AppDialog extends StatelessWidget {
  const AppDialog({super.key, required this.title, this.body, required this.actions});

  final String title;
  final String? body;
  final List<AppDialogAction> actions;

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? body,
    required List<AppDialogAction> actions,
  }) =>
      showDialog<void>(
        context: context,
        barrierColor: AppColors.overlayScrim,
        builder: (_) => AppDialog(title: title, body: body, actions: actions),
      );

  // Ширина окна кадра — 270, высота кнопки — 44; таких ступеней в шкале нет.
  static const _width = 270.0;
  static const _buttonHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    // Не `Dialog`: он держит минимальную ширину 280, а в кадре окно шириной 270.
    return Center(
      child: Material(
        color: AppColors.bgScreen,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSize.radius12)),
        child: SizedBox(
          width: _width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSize.pad16),
                child: Column(
                  children: [
                    Text(title, textAlign: TextAlign.center, style: AppType.titlesHeadline.copyWith(color: AppColors.textPrimary)),
                    if (body != null) ...[
                      const SizedBox(height: AppSize.gap2),
                      Text(body!, textAlign: TextAlign.center, style: AppType.titlesFootnote.copyWith(color: AppColors.borderStrong)),
                    ],
                  ],
                ),
              ),
              for (final action in actions)
                InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    action.onPressed?.call();
                  },
                  child: Container(
                    height: _buttonHeight,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1)),
                    ),
                    child: Text(
                      action.label,
                      style: (action.primary ? AppType.titlesHeadline : AppType.body1).copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
