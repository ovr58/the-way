import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_routes.dart';
import '../../app/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_size.dart';
import '../../theme/app_type.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/avatar.dart';
import '../../widgets/rating_line.dart';
import 'complaints/complaints_screen.dart';
import 'personal_data/personal_data_screen.dart';

const double _avatarSize = 96;
const double _menuIconBox = 48;
const double _menuArrowBox = 38;

/// Мой профиль («Профиль - Базовый экран» — пассажир, «Профиль ВОДИТЕЛЯ» — водитель): шапка с фото, именем и рейтингом,
/// «Перейти в режим …», меню, «Выйти из аккаунта». Вкладка оболочки: профиль берётся из сессии,
/// при открытии перечитывается (`GET /me`).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void>? _load;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load ??= AppSession.of(context).refresh();
  }

  void _reload() {
    final future = AppSession.of(context).refresh();
    setState(() {
      _load = future;
    });
  }

  Future<void> _logout() async {
    final session = AppSession.of(context);
    final navigator = Navigator.of(context);
    await session.logout();
    navigator.pushNamedAndRemoveUntil(AppRoutes.auth, (_) => false);
  }

  /// Окно «Профиль - Базовый экран»: «Выйдите из аккаунта?» с «Выйти» и «Отмена»; слой пояснения в кадре скрыт.
  void _confirmLogout() {
    final l10n = AppLocalizations.of(context);
    AppDialog.show(
      context,
      title: l10n.profileLogoutTitle,
      actions: [
        AppDialogAction(l10n.profileLogoutConfirm, primary: true, onPressed: _logout),
        AppDialogAction(l10n.commonCancel),
      ],
    );
  }

  void _open(String route) => Navigator.of(context).pushNamed(route);

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = AppSession.of(context).me;
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(title: l10n.profileTitle),
          Expanded(
            child: FutureBuilder<void>(
              future: _load,
              builder: (context, snapshot) {
                if (me != null) return _content(context, me, l10n);
                if (snapshot.hasError) return AppErrorView(onRetry: _reload);
                return const AppLoading();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, Me me, AppLocalizations l10n) {
    final driver = me.mode == UserMode.driver;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSize.pad16, AppSize.pad16, AppSize.pad16, AppSize.pad16),
      children: [
        Center(child: Avatar(url: me.photoUrl, size: _avatarSize, silhouette: true)),
        const SizedBox(height: AppSize.gap8),
        Text(
          me.name ?? me.phone,
          textAlign: TextAlign.center,
          style: AppType.title3.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSize.gap2),
        Center(child: RatingLine(rating: me.rating, tripsCount: me.tripsCount, variant: RatingLineVariant.profile)),
        const SizedBox(height: AppSize.gap20),
        _MenuItem(
          icon: 'users_user_id',
          title: driver ? l10n.profileSwitchToPassenger : l10n.profileSwitchToDriver,
          onTap: () => _open(AppRoutes.profileSwitchMode),
        ),
        _MenuItem(icon: 'users_user_circle', title: l10n.profilePersonalData, hint: l10n.profilePersonalDataHint, onTap: () => _push(const PersonalDataScreen())),
        if (driver)
          _MenuItem(icon: 'system_car', title: l10n.profileVehicles, hint: l10n.profileVehiclesHint, onTap: () => _open(AppRoutes.cars)),
        _MenuItem(icon: 'map_map', title: l10n.profileSavedRoutes, hint: l10n.profileSavedRoutesHint, onTap: () => _open(AppRoutes.stub)),
        _MenuItem(icon: 'system_clipboard', title: l10n.profileOrderHistory, hint: l10n.profileOrderHistoryHint, onTap: () => _open(AppRoutes.stub)),
        _MenuItem(icon: 'essentional_danger_circle', title: l10n.profileComplaints, hint: l10n.profileComplaintsHint, onTap: () => _push(const ComplaintsScreen())),
        _MenuItem(icon: 'system_bell_bing', title: l10n.profileNotifications, hint: l10n.profileNotificationsHint, onTap: () => _open(AppRoutes.stub)),
        _MenuItem(icon: 'system_wallet_money', title: l10n.profilePayment, hint: l10n.profilePaymentHint, onTap: () => _open(AppRoutes.stub)),
        _MenuItem(icon: 'system_smartphone', title: l10n.profileFaq, onTap: () => _open(AppRoutes.stub)),
        _MenuItem(icon: 'system_smartphone', title: l10n.profileAbout, hint: l10n.profileAboutHint, onTap: () => _open(AppRoutes.stub)),
        _LogoutButton(label: l10n.profileLogout, onPressed: _confirmLogout),
      ],
    );
  }
}

/// Пункт меню: карточка 72 с круглым значком, заголовком, пояснением и стрелкой.
class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.title, required this.onTap, this.hint});

  final String icon;
  final String title;
  final String? hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSize.radius12));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSize.gap10),
      child: Material(
        color: AppColors.bgSurface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16, vertical: AppSize.pad12),
            child: Row(
              children: [
                Container(
                  width: _menuIconBox,
                  height: _menuIconBox,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.bgControl, shape: BoxShape.circle),
                  child: AppIcon(icon, size: AppSize.icon24, color: AppColors.textSecondary),
                ),
                const SizedBox(width: AppSize.gap8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
                      if (hint != null) ...[
                        const SizedBox(height: AppSize.gap4),
                        Text(hint!, style: AppType.body2.copyWith(color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: _menuArrowBox,
                  height: _menuArrowBox,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSize.radius12),
                    border: Border.all(color: AppColors.borderDefault, width: AppSize.stroke1),
                  ),
                  child: const AppIcon('arrows_alt_arrow_right', size: AppSize.icon14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «Выйти из аккаунта»: зелёная кнопка 48 со значком выхода.
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSize.radius12));
    return Material(
      color: AppColors.accentPrimary,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onPressed,
        child: SizedBox(
          height: AppSize.height48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppIcon('system_logout', size: AppSize.icon16, color: AppColors.textOnAccent),
              const SizedBox(width: AppSize.gap4),
              Text(label, style: AppType.button1.copyWith(color: AppColors.textOnAccent)),
            ],
          ),
        ),
      ),
    );
  }
}
