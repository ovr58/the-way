import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../terms_screen.dart';

/// «Продолжая, я соглашаюсь с условиями использования и политикой конфиденциальности»: обе
/// ссылки открывают условия использования («Вход - Просмотр условий использования»).
class ConsentText extends StatefulWidget {
  const ConsentText({super.key});

  @override
  State<ConsentText> createState() => _ConsentTextState();
}

class _ConsentTextState extends State<ConsentText> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()..onTap = _openTerms;
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()..onTap = _openTerms;

  void _openTerms() => Navigator.of(context).push(
        MaterialPageRoute<void>(settings: const RouteSettings(name: 'auth/terms'), builder: (_) => const TermsScreen()),
      );

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final base = AppType.bodyFootnote.copyWith(color: AppColors.textSecondary);
    final link = AppType.bodyFootnote.copyWith(color: AppColors.accentPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            TextSpan(text: l10n.authConsentPrefix),
            TextSpan(text: l10n.authConsentTerms, style: link, recognizer: _terms),
            TextSpan(text: l10n.authConsentAnd),
            TextSpan(text: l10n.authConsentPrivacy, style: link, recognizer: _privacy),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
