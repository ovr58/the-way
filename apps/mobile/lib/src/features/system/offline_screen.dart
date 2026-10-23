import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_images.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_size.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_empty.dart';

/// «Отсутствии интернета» «Нет интернет-соединения»: «Обновить» закрывает экран и повторяет запрос.
class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key, required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: AppEmpty(
                title: l10n.systemOfflineTitle,
                subtitle: l10n.systemOfflineBody,
                imageAsset: AppImages.systemOffline,
              ),),
            Padding(
              padding: const EdgeInsets.all(AppSize.pad16),
              child: AppButton(
                label: l10n.systemRetry,
                onPressed: () {
                  Navigator.of(context).maybePop();
                  onRetry();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
