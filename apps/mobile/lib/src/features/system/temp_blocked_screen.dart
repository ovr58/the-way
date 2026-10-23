import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/notice_plaque.dart';
import '../../widgets/notification_layout.dart';
import '../../widgets/success_badge.dart';

/// Кому показан экран: от роли зависит вторая фраза текста.
enum TempBlockedRole { passenger, driver }

/// «Бронь отменена» «Аккаунт временно заблокирован»: после отмены брони, давшей блокировку, при отказе сервера
/// `blocked` на бронь или публикацию и водителю после отмены поездки. «Понятно» закрывает экран.
class TempBlockedScreen extends StatelessWidget {
  const TempBlockedScreen({super.key, required this.role});

  final TempBlockedRole role;

  /// Имя маршрута видит перехватчик переходов (`app/http.dart`): открытый `system/…` экран второй
  /// раз не открывается. В `app_routes.dart` имени нет — экран открывают только `push` по этому методу.
  static const routeName = 'system/temp_blocked';

  static Route<void> route(TempBlockedRole role) => MaterialPageRoute<void>(
        settings: const RouteSettings(name: routeName),
        builder: (_) => TempBlockedScreen(role: role),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NotificationLayout(
      badge: const SuccessBadge(failure: true),
      title: l10n.cancelBlockedTitle,
      body: role == TempBlockedRole.driver ? l10n.cancelBlockedBodyDriver : l10n.cancelBlockedBodyPassenger,
      notice: NoticePlaque(l10n.cancelBlockedNotice),
      buttons: [
        AppButton(
          key: const Key('blocked_ok'),
          label: l10n.cancelBlockedOk,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
