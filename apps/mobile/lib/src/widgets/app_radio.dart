import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';

/// Радиокнопка из компонента `Radio button` 20×20: кольцо с зелёной обводкой 2, у выбранной
/// внутри зелёная точка.
class AppRadio extends StatelessWidget {
  const AppRadio({super.key, required this.selected, this.onTap});

  final bool selected;
  final VoidCallback? onTap;

  // Точка выбора 10 — значение кадра, в шкале размеров его нет.
  static const _dot = 10.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: AppSize.icon20,
          height: AppSize.icon20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accentPrimary, width: AppSize.stroke2),
          ),
          child: selected
              ? Container(
                  width: _dot,
                  height: _dot,
                  decoration: const BoxDecoration(color: AppColors.accentPrimary, shape: BoxShape.circle),
                )
              : null,
        ),
      ),
    );
  }
}
