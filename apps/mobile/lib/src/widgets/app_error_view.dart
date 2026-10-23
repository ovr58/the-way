import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_size.dart';
import '../app/app_images.dart';
import 'app_button.dart';
import 'app_empty.dart';

/// Ошибка загрузки экрана с повтором: тексты «Ошибка» и кнопка «Обновить».
class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Expanded(child: AppEmpty(
            title: l10n.systemErrorTitle,
            subtitle: l10n.systemErrorBody,
            imageAsset: AppImages.systemOffline,
          ),),
        Padding(
          padding: const EdgeInsets.all(AppSize.pad16),
          child: AppButton(label: l10n.systemRetry, onPressed: onRetry),
        ),
      ],
    );
  }
}
