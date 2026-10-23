import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../features/trip_new/trip_new_args.dart';
import '../widgets/app_tab_bar.dart';
import 'app_routes.dart';
import 'session.dart';
import 'updates_watcher.dart';

/// Центральная «+» и «+ Создать заказ» пустых списков («Мои заказы - Нет заказов», «Базовые экраны - Поездок нет») — одно действие по режиму профиля:
/// водителю — мастер поездки, пассажиру — мастер заказа.
void openCreateFlow(BuildContext context) {
  final driver = AppSession.of(context).mode == UserMode.driver;
  Navigator.of(context).pushNamed(
    AppRoutes.tripNew,
    arguments: driver ? null : const TripNewArgs.passengerOrder(),
  );
}

/// Оболочка с нижней панелью: «Поездки · Мои заказы · Чаты · Профиль».
/// «Мои заказы» ведёт в раздел по режиму профиля.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  late int _tab = widget.initialTab.clamp(0, 3);

  Future<void> _check() => mounted ? checkUpdates(context) : Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Автообновление событий (принятое решение 2026-10-22): на старте — сразу, дальше раз в 30 с, пока приложение на
    // переднем плане.
    updatesPoller.attach(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) updatesPoller.resume();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    updatesPoller.detach(_check);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      updatesPoller.resume();
    } else {
      updatesPoller.pause();
    }
  }

  /// Переход на экран создания профиля уже запланирован (сборка может повториться до него).
  bool _toProfileSetup = false;

  @override
  Widget build(BuildContext context) {
    final session = AppSession.of(context);
    // Имя обязательно (ТЗ FR-02): вход с сохранённой сессией, а профиль пришёл без имени —
    // приложение закрыли на экране создания профиля. Профиль на старте перечитывает вкладка
    // «Профиль»; сессия перестраивает оболочку, когда он приходит.
    final me = session.me;
    if (me != null && (me.name ?? '').trim().isEmpty && !_toProfileSetup) {
      _toProfileSetup = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.profileSetup, (_) => false);
      });
    }
    final mode = session.mode;
    final ordersRoute = mode == UserMode.driver ? AppRoutes.driverTrips : AppRoutes.passengerTrips;
    return AppTabScaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          buildRoute(context, AppRoutes.search),
          KeyedSubtree(key: ValueKey(ordersRoute), child: buildRoute(context, ordersRoute)),
          buildRoute(context, AppRoutes.stub, AppLocalizations.of(context).systemStubChat),
          buildRoute(context, AppRoutes.profile),
        ],
      ),
      currentIndex: _tab,
      onTap: (i) => setState(() => _tab = i),
      onCreate: () => openCreateFlow(context),
    );
  }
}
