import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_routes.dart';
import '../../../app/session.dart';
import '../../../app/updates_watcher.dart';
import '../../booking/data/booking_changes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_empty.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_loading.dart';
import '../data/driver_trips_repository.dart';
import 'driver_trip_card.dart';

/// Путь картинки пустого списка (`image 20`, «Базовые экраны - Поездок нет»).
const driverTripsEmptyImage = 'assets/images/trips_empty.webp';

/// «Мои заказы» водителя («Базовые экраны - Поездок нет»): вкладки «Активные / Завершенные» по
/// `GET /trips/mine?status` и карточки поездок как «Базовые экраны - Поездок нет». «Создать заказ» ведёт в мастер.
class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({super.key, this.repository});

  final DriverTripsRepository? repository;

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  late DriverTripsRepository _repo;
  late Future<List<DriverTripCard>> _future;
  bool _started = false;
  ListStatus _status = ListStatus.active;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _repo = widget.repository ?? DriverTripsRepository(AppSession.of(context).api);
      _future = _repo.mine(_status);
    }
  }

  @override
  void initState() {
    super.initState();
    bookingChanges.addListener(_onBookingsChanged);
  }

  @override
  void dispose() {
    bookingChanges.removeListener(_onBookingsChanged);
    super.dispose();
  }

  /// Своё действие во всплывающем окне или события проверки (автообновление) — перечитать сразу.
  void _onBookingsChanged() {
    if (mounted) _reload();
  }

  Future<void> _reload() async {
    final next = _repo.mine(_status);
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // ошибку покажет сам экран
    }
  }

  void _select(ListStatus status) {
    if (status == _status) return;
    _status = status;
    _reload();
  }

  Future<void> _open(DriverTripCard t) async {
    await Navigator.of(context).pushNamed(AppRoutes.driverTripsDetails, arguments: t.id);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(title: l10n.driverTripsTitle),
          Padding(
            padding: const EdgeInsets.all(AppSize.pad16),
            child: _StatusSwitch(selected: _status, onChanged: _select),
          ),
          Expanded(
            child: FutureBuilder<List<DriverTripCard>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return AppErrorView(onRetry: _reload);
                if (!snapshot.hasData) return const AppLoading();
                final items = snapshot.data!;
                if (items.isEmpty) {
                  // пустые «Завершенные» — свой текст и без призыва создать заказ, как у пассажира.
                  if (_status == ListStatus.completed) {
                    return AppEmpty(title: l10n.passengerTripsEmptyCompleted, imageAsset: driverTripsEmptyImage);
                  }
                  return _Empty(onCreate: () => Navigator.of(context).pushNamed(AppRoutes.tripNew));
                }
                return RefreshIndicator(
                  // Ручное обновление — та же проверка событий, что таймер оболочки, и сброс таймера.
                  onRefresh: () {
                    refreshUpdates();
                    return _reload();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, AppSize.pad16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSize.gap12),
                    itemBuilder: (_, i) => DriverTripCardView(trip: items[i], onTap: () => _open(items[i])),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Переключатель «Активные / Завершенные» (слой `roles-switch`): рамка, выбранная вкладка залита зелёным.
class _StatusSwitch extends StatelessWidget {
  const _StatusSwitch({required this.selected, required this.onChanged});

  final ListStatus selected;
  final ValueChanged<ListStatus> onChanged;

  Widget _tab(String label, ListStatus status) {
    final on = selected == status;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSize.radius4),
        onTap: () => onChanged(status),
        child: Container(
          height: AppSize.height40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.accentPrimary : null,
            borderRadius: BorderRadius.circular(AppSize.radius4),
          ),
          child: Text(
            label,
            style: AppType.body2.copyWith(color: on ? AppColors.textOnAccent : AppColors.textMuted),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSize.pad4),
      decoration: BoxDecoration(
        color: AppColors.bgControl,
        border: Border.all(color: AppColors.borderMuted, width: AppSize.stroke1),
        borderRadius: BorderRadius.circular(AppSize.radius8),
      ),
      child: Row(
        children: [
          _tab(l10n.driverTripsTabActive, ListStatus.active),
          _tab(l10n.driverTripsTabCompleted, ListStatus.completed),
        ],
      ),
    );
  }
}

/// Пустой список («Базовые экраны - Поездок нет»): картинка, тексты и через 12 кнопка «+ Создать заказ» — одной группой по центру.
class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppEmpty(
      title: l10n.driverTripsEmptyTitle,
      subtitle: l10n.driverTripsEmptyBody,
      imageAsset: driverTripsEmptyImage,
      action: AppAddButton(label: l10n.driverTripsCreate, onPressed: onCreate),
    );
  }
}
