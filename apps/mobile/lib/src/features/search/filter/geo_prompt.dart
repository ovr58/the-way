import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../widgets/app_button.dart';
import 'popup_card.dart';

/// Окно «Доступ к локации» «Доступ к геолокации». `true` — «Разрешить» (дальше системный диалог «Запрос - Экран системы Android»),
/// `false` — «Пропустить».
Future<bool?> showGeoPrompt(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: PopupCard(
        title: l10n.searchGeoTitle,
        body: l10n.searchGeoBody,
        actions: [
          AppButton(
            label: l10n.searchGeoAllow,
            size: AppButtonSize.medium,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
          AppButton(
            label: l10n.searchGeoSkip,
            size: AppButtonSize.medium,
            kind: AppButtonKind.outline,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ],
      ),
    ),
  );
}
