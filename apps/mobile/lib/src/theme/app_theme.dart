import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_type.dart';

/// Светлая тема приложения из токенов макета.
ThemeData buildTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.accentPrimary,
    onPrimary: AppColors.textOnAccent,
    surface: AppColors.bgSurface,
    onSurface: AppColors.textPrimary,
    error: AppColors.statusError,
    outline: AppColors.borderDefault,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: AppType.body1.fontFamily,
    scaffoldBackgroundColor: AppColors.bgScreen,
    dividerColor: AppColors.borderDefault,
  );
}
