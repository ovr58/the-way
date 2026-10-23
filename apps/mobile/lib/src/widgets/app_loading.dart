import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Индикатор загрузки («Загрузка»): зелёное кольцо 48 с обводкой 4 по центру.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key});

  // Кольцо кадра: 48 и обводка 4 — в шкале размеров таких ступеней нет.
  static const _size = 48.0;
  static const _stroke = 4.0;

  @override
  Widget build(BuildContext context) => const Center(
        child: SizedBox(
          width: _size,
          height: _size,
          child: CircularProgressIndicator(strokeWidth: _stroke, color: AppColors.accentPrimary),
        ),
      );
}
