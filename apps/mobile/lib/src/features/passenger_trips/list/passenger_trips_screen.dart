import 'dart:math' as math;

import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_routes.dart';
import '../../../app/home_shell.dart';
import '../../../app/session.dart';
import '../../../app/updates_watcher.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_empty.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_loading.dart';
import '../../booking/data/booking_changes.dart';
import '../data/passenger_trips_repository.dart';
import 'booking_card.dart';
import 'booking_status.dart';

/// Путь картинки пустого списка (`image 20`, «Мои заказы - Нет заказов»).
const tripsEmptyImage = 'assets/images/trips_empty.webp';

/// «Мои заказы» пассажира («Мои заказы - Нет заказов», «Мои заказы - Есть заказы»): фильтры «Все · Созданные · Активные · Завершенные» над
/// одним списком броней и заказов пассажира, новые сверху (Б2.3). Взятый заказ показан своей
/// бронью. «+ Создать заказ» пустого списка — мастер заказа.
class PassengerTripsScreen extends StatefulWidget {
  const PassengerTripsScreen({super.key, this.repository});

  /// Источник данных; в тестах подставляется репозиторий над поддельным [Dio].
  final PassengerTripsRepository? repository;

  @override
  State<PassengerTripsScreen> createState() => _PassengerTripsScreenState();
}

class _PassengerTripsScreenState extends State<PassengerTripsScreen> {
  late PassengerTripsRepository _repo;
  late Future<(List<Booking>, List<OrderCard>)> _future;
  BookingFilter _filter = BookingFilter.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _repo = widget.repository ?? PassengerTripsRepository(AppSession.of(context).api);
      _future = _load();
    }
  }

  /// Брони и заказы вместе: не загрузился один из списков — экран ошибки, а не список без половины.
  Future<(List<Booking>, List<OrderCard>)> _load() => (_repo.mine(), _repo.orders()).wait;

  bool _started = false;

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

  /// Действие во всплывающем окне ответа или отмены поверх списка — перечитать сразу.
  void _onBookingsChanged() {
    if (mounted) _reload();
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // ошибку покажет сам экран
    }
  }

  Future<void> _open(Booking b) async {
    await Navigator.of(context).pushNamed(AppRoutes.passengerTripsDetails, arguments: b.id);
    if (mounted) _reload();
  }

  Future<void> _openOrder(OrderCard o) async {
    await Navigator.of(context).pushNamed(AppRoutes.passengerTripsOrder, arguments: o.id);
    if (mounted) _reload();
  }

  /// Карточки вкладки [_filter]: брони и заказы, новые сверху (при равном времени — порядок сервера).
  List<Widget> _cards((List<Booking>, List<OrderCard>) data) {
    final (bookings, orders) = data;
    final entries = <(DateTime, Widget)>[
      for (final b in bookings)
        if (matches(_filter, b)) (b.createdAt, BookingCard(booking: b, onTap: () => _open(b))),
      for (final o in orders)
        if (orderMatches(_filter, o))
          (o.createdAt, PassengerOrderCard(key: Key('order_card_${o.id}'), order: o, onTap: () => _openOrder(o))),
    ];
    final indexed = entries.indexed.toList()
      ..sort((a, b) {
        final byTime = b.$2.$1.compareTo(a.$2.$1);
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    return [for (final (_, (_, card)) in indexed) card];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(title: l10n.passengerTripsTitle),
          Expanded(
            child: FutureBuilder<(List<Booking>, List<OrderCard>)>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return AppErrorView(onRetry: _reload);
                if (!snapshot.hasData) return const AppLoading();
                final items = _cards(snapshot.data!);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSize.pad16),
                      child: _Filters(
                        selected: _filter,
                        onChanged: (f) => setState(() => _filter = f),
                      ),
                    ),
                    Expanded(
                      child: items.isEmpty && _filter == BookingFilter.completed
                          // пустые «Завершенные» — свой текст, без призыва создать заказ.
                          ? AppEmpty(title: l10n.passengerTripsEmptyCompleted, imageAsset: tripsEmptyImage)
                          : items.isEmpty
                          ? AppEmpty(
                              title: l10n.passengerTripsEmptyTitle,
                              subtitle: l10n.passengerTripsEmptyBody,
                              imageAsset: tripsEmptyImage,
                              // «+ Создать заказ» («Мои заказы - Нет заказов») — то же, что «+» нижней панели (принятое решение 2026-10-22).
                              action: AppAddButton(label: l10n.passengerTripsCreate, onPressed: () => openCreateFlow(context)),
                            )
                          : RefreshIndicator(
                              // Ручное обновление — та же проверка событий, что таймер оболочки, и сброс таймера.
                              onRefresh: () {
                                refreshUpdates();
                                return _reload();
                              },
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(0, 0, 0, AppSize.pad16),
                                itemCount: items.length,
                                separatorBuilder: (_, _) => const SizedBox(height: AppSize.gap12),
                                itemBuilder: (_, i) => items[i],
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Четыре фильтра в ряд (`filter-tag`): выбранный — зелёная рамка и жирный текст.
class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onChanged});

  final BookingFilter selected;
  final ValueChanged<BookingFilter> onChanged;

  // Поля чипа кадра 12×8 минус обводка 1 — ступеней 11 и 7 в шкале нет.
  static const _chipPadX = 11.0;
  static const _chipPadY = 7.0;
  static const _rowWidth = 343.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = {
      BookingFilter.all: l10n.passengerTripsFilterAll,
      BookingFilter.created: l10n.passengerTripsFilterCreated,
      BookingFilter.active: l10n.passengerTripsFilterActive,
      BookingFilter.completed: l10n.passengerTripsFilterCompleted,
    };
    // Ряд рассчитан на ширину кадра 343: на более узком экране весь ряд сжимается целиком, а не
    // переполняется.
    return LayoutBuilder(
      builder: (context, box) => FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: math.max(box.maxWidth, _rowWidth),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final entry in labels.entries)
                InkWell(
                  borderRadius: BorderRadius.circular(AppSize.radius12),
                  onTap: () => onChanged(entry.key),
                  child: Container(
                    // В кадре обводка чипа не прибавляет размера (47 = 23 + 2×12, высота 34): в Flutter она
                    // снаружи содержимого, поэтому поле меньше на её толщину.
                    padding: const EdgeInsets.symmetric(horizontal: _chipPadX, vertical: _chipPadY),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: entry.key == selected ? AppColors.accentPrimary : AppColors.borderDefault,
                        width: AppSize.stroke1,
                      ),
                      borderRadius: BorderRadius.circular(AppSize.radius12),
                    ),
                    child: Text(
                      entry.value,
                      style: (entry.key == selected ? AppType.titlesFootnote : AppType.bodyFootnote)
                          .copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
