import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_routes.dart';
import '../../app/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_size.dart';
import '../../theme/app_type.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_radio.dart';

/// Выбор роли («Профиль - сменить режим»): «Водитель» и «Пассажир» радиокнопками. Выбор сразу меняет режим
/// (`PATCH /me {mode}`) и возвращает к оболочке — вкладки перестраиваются.
class SwitchModeScreen extends StatefulWidget {
  const SwitchModeScreen({super.key});

  @override
  State<SwitchModeScreen> createState() => _SwitchModeScreenState();
}

class _SwitchModeScreenState extends State<SwitchModeScreen> {
  bool _busy = false;

  Future<void> _pick(UserMode mode) async {
    final session = AppSession.of(context);
    final navigator = Navigator.of(context);
    if (_busy) return;
    if (mode == session.mode) {
      navigator.popUntil((route) => route.settings.name == AppRoutes.shell || route.isFirst);
      return;
    }
    setState(() => _busy = true);
    try {
      await session.setMode(mode);
      navigator.popUntil((route) => route.settings.name == AppRoutes.shell || route.isFirst);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).profileErrorGeneric)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = AppSession.of(context).mode;
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(title: l10n.profileRoleTitle, onBack: Navigator.of(context).maybePop),
          // Список на сером фоне экрана, без подложки — как в кадре «Профиль - сменить режим».
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
            child: Column(
              children: [
                _RoleRow(label: l10n.profileRoleDriver, selected: current == UserMode.driver, onTap: () => _pick(UserMode.driver)),
                _RoleRow(label: l10n.profileRolePassenger, selected: current == UserMode.passenger, onTap: () => _pick(UserMode.passenger)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        // Строка выбора не ниже 48 под палец (в кадре шаг строк 15 + 24) — отход, реестр.
        constraints: const BoxConstraints(minHeight: AppSize.height48),
        child: Row(
          children: [
            AppRadio(selected: selected, onTap: onTap),
            const SizedBox(width: AppSize.gap8),
            Text(label, style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
