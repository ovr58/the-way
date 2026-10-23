import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_icon.dart';

/// «Марка Модель» 13/600 и галочка «Проверен» 16 («Новый заказ - Выбор авто - есть авто», «Новый заказ - Выбор авто - выбрано авто», «Транспортные средства»).
class CarTitleLine extends StatelessWidget {
  const CarTitleLine(this.title, {super.key, required this.verified});

  final String title;
  final bool verified;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.titlesFootnote.copyWith(color: AppColors.textPrimary),
            ),
          ),
          if (verified) ...[
            const SizedBox(width: AppSize.gap4),
            const AppIcon('essentional_check_circle', size: AppSize.icon16, color: AppColors.accentPrimary),
          ],
        ],
      );
}

/// «номер • N места»: точка 4×4, отступы 3 («Новый заказ - Выбор авто - есть авто», «Новый заказ - Выбор авто - выбрано авто», «Транспортные средства»).
class CarPlateSeatsLine extends StatelessWidget {
  const CarPlateSeatsLine({super.key, required this.plate, required this.seats});

  final String plate;
  final String seats;

  static const _dot = AppSize.gap4;

  @override
  Widget build(BuildContext context) {
    final style = AppType.body2.copyWith(color: AppColors.textSecondary);
    return Row(
      children: [
        Flexible(child: Text(plate, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        const SizedBox(width: AppSize.pad3),
        Container(
          width: _dot,
          height: _dot,
          decoration: const BoxDecoration(color: AppColors.textSecondary, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSize.pad3),
        Text(seats, style: style),
      ],
    );
  }
}

/// Белый блок на всю ширину экрана: поля 16, скругление 12.
class CarsCard extends StatelessWidget {
  const CarsCard({super.key, required this.child, this.padding = const EdgeInsets.all(AppSize.pad16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppSize.radius12),
        ),
        child: child,
      );
}

/// Заголовок блока формы (15/600, поля 16).
class CarsSectionTitle extends StatelessWidget {
  const CarsSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
        child: Text(text, style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
      );
}

/// Малая кнопка с зелёным контуром высотой 32 («Добавить фото», «Добавить», «Заменить ›»).
class SmallOutlineButton extends StatelessWidget {
  const SmallOutlineButton({super.key, required this.label, required this.onPressed, this.icon, this.trailingIcon});

  final String label;
  final VoidCallback onPressed;
  final String? icon;

  /// Значок справа от подписи («Заменить ›», «Транспортные средства»).
  final String? trailingIcon;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(AppSize.radius8),
        onTap: onPressed,
        child: Container(
          height: AppSize.height32,
          padding: const EdgeInsets.symmetric(horizontal: AppSize.pad12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.accentPrimary, width: AppSize.stroke1),
            borderRadius: BorderRadius.circular(AppSize.radius8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                AppIcon(icon!, size: AppSize.icon14, color: AppColors.accentPrimary),
                const SizedBox(width: AppSize.gap4),
              ],
              Text(label, style: AppType.button3.copyWith(color: AppColors.accentPrimary)),
              if (trailingIcon != null) ...[
                const SizedBox(width: AppSize.gap4),
                AppIcon(trailingIcon!, size: AppSize.icon14, color: AppColors.accentPrimary),
              ],
            ],
          ),
        ),
      );
}

/// Нижняя панель кнопок: фон экрана, безопасная зона снизу (CTA кадров).
class CarsBottomBar extends StatelessWidget {
  const CarsBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bgScreen,
          border: Border(top: BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSize.pad16, AppSize.pad8, AppSize.pad16, AppSize.pad8),
            child: child,
          ),
        ),
      );
}

/// Красный снэкбар ошибки действия.
void showCarsError(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.statusError,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSize.radius12)),
        content: Row(children: [
          Expanded(child: Text(text, style: AppType.bodyFootnote.copyWith(color: AppColors.textOnAccent))),
          InkWell(
            onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            child: const Padding(
              padding: EdgeInsets.all(AppSize.pad12),
              child: AppIcon('snackbar_close', size: AppSize.icon14, color: AppColors.textOnAccent),
            ),
          ),
        ]),
      ),
    );
}

/// Кнопка с красным контуром («Удалить ТС», «Транспортные средства»): высота 42, скругление 12.
class DestructiveButton extends StatelessWidget {
  const DestructiveButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onPressed == null || loading ? 0.5 : 1,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSize.radius12),
            side: const BorderSide(color: AppColors.statusError, width: AppSize.stroke1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSize.radius12),
            onTap: loading ? null : onPressed,
            child: Container(
              width: double.infinity,
              height: AppSize.height42,
              alignment: Alignment.center,
              child: Text(label, style: AppType.button2.copyWith(color: AppColors.statusError)),
            ),
          ),
        ),
      );
}
