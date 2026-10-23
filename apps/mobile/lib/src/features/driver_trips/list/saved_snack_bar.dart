import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_icon.dart';

/// Зелёный снэкбар «Изменения сохранены» («Редактирование - Кличество мест сохранено», «Базовые экраны - Поездок нет»): галочка, текст 13, крестик.
void showSavedSnackBar(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.accentPrimary,
      margin: const EdgeInsets.all(AppSize.pad16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSize.radius12)),
      content: Row(
        children: [
          const AppIcon('essentional_check_circle', color: AppColors.textOnAccent),
          const SizedBox(width: AppSize.gap8),
          Expanded(
            child: Text(l10n.driverTripsSaved, style: AppType.bodyFootnote.copyWith(color: AppColors.textOnAccent)),
          ),
          InkWell(
            onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            child: const Padding(
              padding: EdgeInsets.all(AppSize.pad12),
              child: AppIcon('snackbar_close', size: AppSize.icon24, color: AppColors.textOnAccent),
            ),
          ),
        ],
      ),
    ),
  );
}
