import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';
import 'app_icon.dart';

/// Вид кнопки: заливка (основная), контур зелёный, контур серый (`border.default`), красная заливка
/// и красный контур (`status.error`, окна отмены).
enum AppButtonKind { primary, outline, neutral, danger, dangerOutline }

/// Размер: `large` — 48 (кнопка CTA, 15/600), `medium` — 42 (13/600, окна и листы).
enum AppButtonSize { large, medium }

/// Кнопка из компонента `Button` макета (Button, CTA, Button Sheet).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.primary,
    this.size = AppButtonSize.large,
    this.loading = false,
  });

  final String label;

  /// `null` или [loading] — кнопка неактивна.
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final AppButtonSize size;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final large = size == AppButtonSize.large;
    final filled = kind == AppButtonKind.primary || kind == AppButtonKind.danger;
    // Неактивная основная кнопка в кадрах («Вход - Ввод номера (номер введён)», «Вход - Ввод номера (фокус)», «Создание профиля - Ввод имя», «Создание профиля - Загрузка фото», «Новый заказ - Маршрут»): заливка фона экрана, контур
    // `border.default`, подпись `text.secondary`; во время загрузки остаётся зелёной со счётчиком.
    final inactivePrimary = filled && !enabled && !loading;
    final textColor = inactivePrimary
        ? AppColors.textSecondary
        : filled
            ? AppColors.textOnAccent
            : switch (kind) {
                AppButtonKind.outline => AppColors.accentPrimary,
                AppButtonKind.dangerOutline => AppColors.statusError,
                _ => AppColors.textPrimary,
              };
    final side = switch (kind) {
      AppButtonKind.primary when inactivePrimary => const BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1),
      AppButtonKind.primary || AppButtonKind.danger => BorderSide.none,
      AppButtonKind.dangerOutline => const BorderSide(color: AppColors.statusError, width: AppSize.stroke1),
      AppButtonKind.outline => const BorderSide(color: AppColors.accentPrimary, width: AppSize.stroke1),
      AppButtonKind.neutral => const BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1),
    };
    final button = Material(
      color: inactivePrimary
          ? AppColors.bgScreen
          : (filled ? (kind == AppButtonKind.danger ? AppColors.statusError : AppColors.accentPrimary) : Colors.transparent),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSize.radius12), side: side),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSize.radius12),
        onTap: enabled ? onPressed : null,
        child: Container(
          width: double.infinity,
          height: large ? AppSize.height48 : AppSize.height42,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: AppSize.pad16, vertical: large ? AppSize.pad16 : AppSize.pad12),
          child: loading
              ? SizedBox(
                  width: AppSize.icon20,
                  height: AppSize.icon20,
                  child: CircularProgressIndicator(strokeWidth: AppSize.stroke2, color: textColor),
                )
              : Text(label, style: (large ? AppType.button1 : AppType.button2).copyWith(color: textColor)),
        ),
      ),
    );
    // Прочие неактивные кнопки (контурные) — полупрозрачные.
    return enabled || loading || inactivePrimary ? button : Opacity(opacity: 0.5, child: button);
  }
}

/// Кнопка «+ …» пустых списков («Мои заказы - Нет заказов», «Базовые экраны - Поездок нет» «Создать заказ», «Транспортные средства» «Добавить ТС»): одна на всё приложение —
/// зелёная, плюс 14 слева через 4, подпись 13/600, поля 12/16, высота 42, ширина по тексту, скругление 12.
class AppAddButton extends StatelessWidget {
  const AppAddButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.accentPrimary,
        borderRadius: BorderRadius.circular(AppSize.radius12),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSize.radius12),
          onTap: onPressed,
          child: Container(
            height: AppSize.height42,
            padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon('essentional_add', size: AppSize.icon14, color: AppColors.textOnAccent),
                const SizedBox(width: AppSize.gap4),
                Text(label, style: AppType.button2.copyWith(color: AppColors.textOnAccent)),
              ],
            ),
          ),
        ),
      );
}

/// Круглая кнопка-иконка 40 (назад, фильтр, меню в шапке).
class AppIconButton extends StatelessWidget {
  const AppIconButton({super.key, required this.child, required this.onPressed, this.background = AppColors.bgSurface});

  final Widget child;
  final VoidCallback? onPressed;
  final Color background;

  @override
  Widget build(BuildContext context) => Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: AppSize.height40, height: AppSize.height40, child: Center(child: child)),
        ),
      );
}
