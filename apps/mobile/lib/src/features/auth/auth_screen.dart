import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_size.dart';
import '../../theme/app_type.dart';
import '../../widgets/app_input.dart';
import 'data/api_error.dart';
import 'data/auth_repository.dart';
import 'data/phone_country.dart';
import 'data/phone_format.dart';
import 'sms_code_screen.dart';
import 'widgets/cta_bar.dart';

/// Вход: номер телефона («Вход - Базовый экран», «Вход - Ввод номера (данные введены)» – «Вход - Ввод номера (фокус)»). «Получить код» открывает ввод кода («Вход - СМС код (неправильный код)» – «Вход - СМС код (базовый экран)»).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _prefillCountryCode();
  }

  /// «Вход - Ввод номера (данные введены)»: код страны SIM-карты (нет — сети) сразу в поле, курсор после него; страна неизвестна —
  /// только «+». Человек мог начать набор раньше ответа Android — тогда поле не трогаем.
  Future<void> _prefillCountryCode() async {
    final prefix = phonePrefixFor(await readPhoneCountry());
    if (!mounted || _controller.text.isNotEmpty) return;
    _controller.value = TextEditingValue(text: prefix, selection: TextSelection.collapsed(offset: prefix.length));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _getCode() async {
    final l10n = AppLocalizations.of(context);
    final session = AppSession.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final phone = toE164(_controller.text);
    setState(() => _loading = true);
    try {
      final resendAfterSec = await AuthRepository(session.api).requestCode(phone);
      if (!mounted) return;
      navigator.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'auth/code'),
          builder: (_) => SmsCodeScreen(phone: phone, resendAfterSec: resendAfterSec),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorCode(error) == 'account_blocked' ? l10n.systemBlockedTitle : l10n.authErrorGeneric)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSize.pad16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.authWelcomeTitle, style: AppType.title2.copyWith(color: AppColors.textPrimary)),
                          const SizedBox(height: AppSize.gap8),
                          Text(l10n.authWelcomeSubtitle, style: AppType.body2.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListenableBuilder(
                            listenable: _controller,
                            builder: (context, _) => AppInput(
                              label: l10n.authPhoneLabel,
                              hintText: l10n.authPhoneHint,
                              controller: _controller,
                              keyboardType: TextInputType.phone,
                              inputFormatters: const [PhoneInputFormatter()],
                              autofocus: true,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSize.pad2),
                            child: Text(l10n.authPhoneComment, style: AppType.bodyCaption1.copyWith(color: AppColors.textSecondary)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => CtaBar(
              // Согласие даётся здесь, на вводе телефона («Вход - Ввод номера (данные введены)» – «Вход - Базовый экран»); дальше строки нет.
              withConsent: true,
              children: [
                CtaButton(
                  label: l10n.authGetCode,
                  loading: _loading,
                  onPressed: isValidPhone(_controller.text) ? _getCode : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
