import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_routes.dart';
import '../../app/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_size.dart';
import '../../theme/app_type.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_icon.dart';
import 'data/api_error.dart';
import 'data/auth_repository.dart';
import 'data/phone_format.dart';
import 'widgets/cta_bar.dart';

const _codeLength = 6;
// Промежуток 24 макета («Вход - СМС код (неправильный код)» – «Создание профиля - Базовый экран»), в шкале `AppSize` его нет.
const double _gap24 = 24;

/// Ввод кода из SMS («Вход - СМС код (неправильный код)» – «Вход - СМС код (базовый экран)»): шесть ячеек, таймер повтора, «Неверный код подтверждения».
/// Вход → `profile_setup` для нового пользователя, иначе `shell`.
class SmsCodeScreen extends StatefulWidget {
  const SmsCodeScreen({super.key, required this.phone, required this.resendAfterSec});

  /// Номер в формате E.164.
  final String phone;
  final int resendAfterSec;

  @override
  State<SmsCodeScreen> createState() => _SmsCodeScreenState();
}

class _SmsCodeScreenState extends State<SmsCodeScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  late int _secondsLeft = widget.resendAfterSec;
  bool _loading = false;
  bool _wrongCode = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_keepCaretAtEnd);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.removeListener(_keepCaretAtEnd);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Курсор скрытого поля всегда после последней цифры: ячейка с курсором на экране — следующая за
  /// последней цифрой, и «Стереть» стирает именно предыдущую, куда бы ни ткнули и что бы ни прислала
  /// клавиатура.
  void _keepCaretAtEnd() {
    final value = _controller.value;
    final end = TextSelection.collapsed(offset: value.text.length);
    if (value.selection != end) _controller.value = value.copyWith(selection: end, composing: TextRange.empty);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) timer.cancel();
      setState(() => _secondsLeft--);
    });
  }

  void _snack(Object error) {
    final l10n = AppLocalizations.of(context);
    final text = apiErrorCode(error) == 'account_blocked' ? l10n.systemBlockedTitle : l10n.authErrorGeneric;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _resend() async {
    final session = AppSession.of(context);
    try {
      final seconds = await AuthRepository(session.api).requestCode(widget.phone);
      if (!mounted) return;
      setState(() {
        _secondsLeft = seconds;
        _wrongCode = false;
        _controller.clear();
      });
      _startTimer();
    } catch (error) {
      if (mounted) _snack(error);
    }
  }

  Future<void> _login() async {
    final session = AppSession.of(context);
    final navigator = Navigator.of(context);
    final repository = AuthRepository(session.api);
    setState(() {
      _loading = true;
      _wrongCode = false;
    });
    try {
      final result = await repository.verify(widget.phone, _controller.text);
      await session.signIn(result.token, me: result.me);
      if (!result.isNew) await _applyChoice(session, repository);
      session.onboardingDone = true;
      navigator.pushNamedAndRemoveUntil(result.isNew ? AppRoutes.profileSetup : AppRoutes.shell, (_) => false);
    } catch (error) {
      if (!mounted) return;
      if (apiErrorCode(error) == 'invalid_code') {
        // ячейки пусты, фокус в первой, клавиатура открыта; надпись — до первой цифры (`onChanged`).
        setState(() {
          _wrongCode = true;
          _controller.clear();
        });
        // Фокус уже в поле, а клавиатуру скрыли («Назад») — `requestFocus` её не вернёт, показываем сами.
        if (_focus.hasFocus) {
          SystemChannels.textInput.invokeMethod<void>('TextInput.show');
        } else {
          _focus.requestFocus();
        }
      } else {
        _snack(error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Существующий пользователь: выбранные до входа город и роль уходят в профиль.
  Future<void> _applyChoice(AppSession session, AuthRepository repository) async {
    final cityId = session.pendingCityId;
    final mode = session.pendingMode;
    if (cityId == null && mode == null) return;
    try {
      await repository.saveChoice(cityId: cityId, mode: mode);
      await session.refresh();
      session
        ..pendingCityId = null
        ..pendingMode = null;
    } catch (_) {
      // Вход состоялся; выбор можно повторить в профиле — не мешаем перейти к поездкам.
    }
  }

  /// вход сам после шестой цифры и по ✓ клавиатуры; «Вход» остаётся на случай отказа сети.
  void _submitIfComplete() {
    if (!_loading && !_wrongCode && _controller.text.length == _codeLength) _login();
  }

  String _timerLabel() => '${_secondsLeft ~/ 60}:${(_secondsLeft % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(title: l10n.authCodeTitle, onBack: Navigator.of(context).maybePop),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16, vertical: AppSize.pad8),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        style: AppType.body2.copyWith(color: AppColors.textSecondary),
                        children: [
                          TextSpan(text: l10n.authCodeHint),
                          TextSpan(text: formatPhone(widget.phone), style: const TextStyle(color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSize.gap16),
                  _CodeCells(
                    controller: _controller,
                    focus: _focus,
                    onChanged: () {
                      setState(() => _wrongCode = false);
                      _submitIfComplete();
                    },
                    onSubmitted: _submitIfComplete,
                  ),
                  const SizedBox(height: _gap24),
                  _ResendRow(ready: _secondsLeft <= 0, timerLabel: _timerLabel(), onResend: _resend),
                  if (_wrongCode) ...[const SizedBox(height: AppSize.gap16), const _WrongCode()],
                ],
              ),
            ),
          ),
          ListenableBuilder(
            listenable: _controller,
            // «Вход - СМС код (неправильный код)»: при неверном коде «Вход» неактивна, пока код не изменён. Строки согласия на экране кода
            // нет («Вход - СМС код (неправильный код)» – «Вход - СМС код (базовый экран)»): согласие дано на вводе телефона.
            builder: (context, _) => CtaBar(
              children: [
                CtaButton(
                  label: l10n.authLogin,
                  loading: _loading,
                  onPressed: !_wrongCode && _controller.text.length == _codeLength ? _login : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Шесть ячеек 52×52 (радиус 12) над невидимым полем ввода.
class _CodeCells extends StatelessWidget {
  const _CodeCells({required this.controller, required this.focus, required this.onChanged, required this.onSubmitted});

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, focus]),
      builder: (context, _) {
        final text = controller.text;
        return SizedBox(
          height: AppSize.height52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _codeLength; i++) ...[
                    if (i > 0) const SizedBox(width: AppSize.gap4),
                    _Cell(
                      char: i < text.length ? text[i] : null,
                      active: focus.hasFocus && i == text.length.clamp(0, _codeLength - 1),
                      filled: i < text.length,
                    ),
                  ],
                ],
              ),
              Positioned.fill(
                child: TextField(
                  key: const Key('auth_code_field'),
                  controller: controller,
                  focusNode: focus,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: _codeLength,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  style: const TextStyle(color: Colors.transparent),
                  decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                  onChanged: (_) => onChanged(),
                  onSubmitted: (_) => onSubmitted(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.char, required this.active, required this.filled});

  final String? char;
  final bool active;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cursor = active && char == null;
    return Container(
      width: AppSize.height52,
      height: AppSize.height52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppSize.radius12),
        border: active || filled ? Border.all(color: AppColors.accentPrimary, width: AppSize.stroke1) : null,
      ),
      child: Text(
        char ?? (cursor ? '|' : '_'),
        style: AppType.titlesHeadline.copyWith(color: cursor ? AppColors.accentPrimary : AppColors.textPrimary),
      ),
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({required this.ready, required this.timerLabel, required this.onResend});

  final bool ready;
  final String timerLabel;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(ready ? l10n.authResendPrompt : l10n.authResendTimer, style: AppType.body2.copyWith(color: AppColors.textSecondary)),
        const SizedBox(width: AppSize.gap8),
        InkWell(
          onTap: ready ? onResend : null,
          borderRadius: BorderRadius.circular(AppSize.radius12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSize.pad12, vertical: AppSize.pad4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSize.radius12),
              border: Border.all(color: AppColors.accentPrimary, width: AppSize.stroke1),
            ),
            child: Text(ready ? l10n.authResendButton : timerLabel, style: AppType.button1.copyWith(color: AppColors.textPrimary)),
          ),
        ),
      ],
    );
  }
}

/// Плашка «Неверный код подтверждения» и пояснение («Вход - СМС код (неправильный код)»).
class _WrongCode extends StatelessWidget {
  const _WrongCode();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Container(
          width: double.infinity, // во всю ширину строки 343, как в кадре «Вход - СМС код (неправильный код)»
          padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16, vertical: AppSize.pad8),
          decoration: BoxDecoration(color: AppColors.statusError, borderRadius: BorderRadius.circular(AppSize.radius12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppIcon('essentional_danger_circle', size: AppSize.icon18, color: AppColors.textOnAccent),
              const SizedBox(width: AppSize.gap8),
              Text(l10n.authCodeErrorTitle, style: AppType.bodyFootnote.copyWith(color: AppColors.textOnAccent)),
            ],
          ),
        ),
        const SizedBox(height: AppSize.gap8),
        Text(
          l10n.authCodeErrorBody,
          textAlign: TextAlign.center,
          style: AppType.bodyFootnote.copyWith(color: AppColors.statusError),
        ),
      ],
    );
  }
}
