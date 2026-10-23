import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_size.dart';
import '../../theme/app_type.dart';
import '../../widgets/app_header.dart';

/// Условия использования («Вход - Просмотр условий использования»): шапка с «назад» и прокручиваемый текст.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(title: l10n.authTermsTitle, onBack: Navigator.of(context).maybePop),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSize.pad16),
              child: Text(l10n.authTermsBody, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}
