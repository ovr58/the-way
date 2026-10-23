import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';

/// Переключатель из компонента `Switch` 39×24: включён — зелёная заливка, белая ручка справа;
/// выключен — светлая заливка, зелёная обводка и зелёная ручка слева.
///
/// Переход: ручка едет, цвет дорожки, обводки и ручки перетекает —
/// 300 мс, easeInOut. Неявные анимации Flutter не смотрят на `MediaQuery.disableAnimations` — движение идёт
/// при любой настройке системы («уменьшить движение» его не выключает). Вид состояний
/// (выключен, включён, неактивен) — прежний, меняется только переход.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  // Значения кадра, которых нет в шкале: ширина 39 и обводка 1.5 (дробные значения импорта
  // Figma → Penpot в шкалу не входят).
  static const _width = 39.0;
  static const _border = 1.5;

  static const _duration = Duration(milliseconds: 300);
  static const _curve = Curves.easeInOut;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: _duration,
          curve: _curve,
          width: _width,
          height: AppSize.height24,
          padding: const EdgeInsets.symmetric(horizontal: AppSize.pad3),
          decoration: BoxDecoration(
            color: value ? AppColors.accentPrimary : AppColors.bgSurfaceAlt,
            border: value ? null : Border.all(color: AppColors.accentPrimary, width: _border),
            borderRadius: BorderRadius.circular(AppSize.height24),
          ),
          child: AnimatedAlign(
            duration: _duration,
            curve: _curve,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: _duration,
              curve: _curve,
              width: AppSize.icon18,
              height: AppSize.icon18,
              decoration: BoxDecoration(
                color: value ? AppColors.textOnAccent : AppColors.accentPrimary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
