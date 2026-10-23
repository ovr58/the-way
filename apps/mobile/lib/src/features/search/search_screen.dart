import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_routes.dart';
import '../../app/session.dart';
import '../../app/updates_watcher.dart';
import '../booking/data/booking_changes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_size.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_empty.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/trip_card_view.dart';
import '../orders/data/order_repository.dart';
import '../trip_new/trip_new_args.dart';
import 'data/search_filter.dart';
import 'data/search_repository.dart';
import 'filter/filter_sheet.dart';
import 'filter/geo_prompt.dart';
import 'filter/location_service.dart';
import 'orders/order_sheet.dart';
import 'orders/orders_feed.dart';
import 'search_images.dart';
import 'segmented_tabs.dart';

/// Лента поездок («Базовые экраны - Поездки есть», «Базовые экраны - Идёт регистрация пассажиров»; пусто — «Базовые экраны - Поездок нет», «Фильтр- поездок нет»): вкладки «Автомобили / Автобусы», карточки
/// в порядке сервера, тап — детали, кнопка в шапке — фильтр. Вкладка «Автобусы» — та же лента поездок
/// на автобусе.
/// В режиме водителя вкладки — «Поездки / Заказы пассажиров» (образец «Пришёл отклик»): вторая — лента
/// заказов пассажиров с тем же фильтром, тап — шторка отклика.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.location = const GeolocatorService()});

  /// Источник координат; подменяется в тестах.
  final LocationService location;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Промежуток между карточками в кадре — 14; такой ступени в шкале нет.
  static const _cardGap = 14.0;
  // Красная точка на кнопке фильтра («Фильтр- поездок нет») — 9×9, на углу воронки: на 6 ниже и на 5 левее угла кнопки.
  static const _dot = 9.0;
  static const _dotTop = 6.0;
  static const _dotRight = 5.0;

  SearchRepository? _repo;
  OrderRepository? _orderRepo;
  SearchFilter _filter = SearchFilter.empty;
  Coords? _coords;
  /// Выбранная вкладка: у пассажира 1 — «Автобусы», у водителя 1 — «Заказы пассажиров».
  int _tab = 0;
  Future<List<TripCard>>? _trips;
  /// Лента заказов; `null` — вкладку заказов ещё не открывали.
  Future<List<OrderCard>>? _orders;

  bool get _driver => AppSession.of(context).mode == UserMode.driver;

  @override
  void initState() {
    super.initState();
    bookingChanges.addListener(_onBookingsChanged);
    updatesPoller.ticks.addListener(_onUpdatesTick);
  }

  @override
  void dispose() {
    bookingChanges.removeListener(_onBookingsChanged);
    updatesPoller.ticks.removeListener(_onUpdatesTick);
    super.dispose();
  }

  /// После событий проверки (автообновление) и своих действий — перечитать открытую ленту заказов.
  void _onBookingsChanged() {
    if (mounted && _orders != null) _reloadOrders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repo != null) return;
    final api = AppSession.of(context).api;
    _repo = SearchRepository(api);
    _orderRepo = OrderRepository(api);
    _reload();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocation());
  }

  /// Тип ТС ленты: у пассажира вкладка 1 — «Автобусы»; у водителя лента поездок — легковые.
  VehicleKind get _vehicleKind => !_driver && _tab == 1 ? VehicleKind.bus : VehicleKind.car;

  void _reload() {
    final next = _repo!.trips(_filter, where: _coords, vehicleKind: _vehicleKind);
    setState(() {
      _trips = next;
    });
    if (_orders != null) _reloadOrders();
  }

  /// Идущий запрос ленты заказов: тик автообновления и жест «потянуть вниз» к нему присоединяются.
  Future<List<OrderCard>>? _ordersInFlight;

  /// `GET /orders` с фильтром ленты: координаты — если известны, `near` — только вместе с ними. [join] —
  /// присоединиться к идущему запросу (тик, жест), а не слать второй; смена фильтра шлёт новый.
  Future<List<OrderCard>>? _reloadOrders({bool join = false}) {
    final inFlight = _ordersInFlight;
    if (join && inFlight != null) return inFlight;
    late final Future<List<OrderCard>> next;
    next = _orderRepo!.feed(
      fromCityId: _filter.from?.id,
      toCityId: _filter.to?.id,
      lat: _coords?.lat,
      lng: _coords?.lng,
      near: _filter.near && _coords != null ? true : null,
      kind: _filter.kind,
    ).whenComplete(() {
      if (identical(_ordersInFlight, next)) _ordersInFlight = null;
    });
    _ordersInFlight = next;
    setState(() {
      _orders = next;
    });
    return next;
  }

  /// Тик автообновления (30 с, принятое решение 2026-10-22): лента заказов перечитывается, пока она на
  /// экране — вкладка открыта, вкладка оболочки видна и не закрыта другим экраном (`TickerMode`: скрытая
  /// вкладка `IndexedStack` и экран под непрозрачным маршрутом его выключают).
  void _onUpdatesTick() {
    if (!mounted || !_driver || _tab != 1 || _orders == null) return;
    if (!TickerMode.valuesOf(context).enabled) return;
    _reloadOrders(join: true);
  }

  void _selectTab(int i) {
    setState(() => _tab = i);
    if (!_driver) {
      _reload();
    } else if (i == 1 && _orders == null) {
      _reloadOrders();
    }
  }

  Future<void> _openOrder(OrderCard order) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final result = await showOrderSheet(context, order.id);
    if (!mounted) return;
    switch (result) {
      case OrderResponded():
        messenger.showSnackBar(SnackBar(content: Text(l10n.driverOrdersResponded)));
        _reloadOrders();
      case OrderUnavailable():
        messenger.showSnackBar(SnackBar(content: Text(l10n.driverOrdersErrorUnavailable)));
        _reloadOrders();
      case OrderCreateTrip(:final order):
        await navigator.pushNamed(AppRoutes.tripNew, arguments: TripNewArgs.respond(order));
        if (mounted) _reloadOrders();
      case null:
        break;
    }
  }

  /// Окно «Доступ к локации» — при первом открытии вкладки; позже координаты берутся без окна, если
  /// разрешение уже выдано.
  Future<void> _initLocation() async {
    if (!mounted) return;
    final session = AppSession.of(context);
    Coords? coords;
    if (!session.geoPromptShown) {
      final answer = showGeoPrompt(context);
      session.geoPromptShown = true;
      coords = await answer == true ? await widget.location.request() : null;
    } else {
      coords = await widget.location.ifGranted();
    }
    if (!mounted || coords == null) return;
    _coords = coords;
    _reload();
  }

  Future<void> _openFilter() async {
    // при открытии ленты место могло не определиться (нет фикса, таймаут) — доступ выдан, а координат
    // нет; без повтора «Поблизости» остаётся неактивным с подписью «нужен доступ» до перезапуска.
    _coords ??= await widget.location.ifGranted();
    if (!mounted) return;
    final result = await showFilterSheet(context, filter: _filter, nearAvailable: _coords != null);
    if (result == null || !mounted) return;
    _filter = result;
    _reload();
  }

  Widget _filterButton() => Stack(
        clipBehavior: Clip.none,
        children: [
          AppIconButton(
            key: const Key('search_filter_button'),
            background: AppColors.bgSurfaceAlt,
            onPressed: _openFilter,
            // Воронка в кадрах всегда чёрная 50% (`System / Filter`), включённость — по кружку.
            child: const AppIcon('system_filter', size: AppSize.icon24, color: AppColors.textSecondary),
          ),
          if (_filter.isActive)
            Positioned(
              top: _dotTop,
              right: _dotRight,
              child: Container(
                key: const Key('search_filter_dot'),
                width: _dot,
                height: _dot,
                decoration: const BoxDecoration(color: AppColors.statusError, shape: BoxShape.circle),
              ),
            ),
        ],
      );

  Widget _empty(AppLocalizations l10n) => AppEmpty(
        title: l10n.searchEmptyTitle,
        subtitle: l10n.searchEmptySubtitle,
        imageAsset: searchEmptyImage,
      );

  Widget _feed(AppLocalizations l10n) {
    return FutureBuilder<List<TripCard>>(
      future: _trips,
      builder: (context, snapshot) {
        if (snapshot.hasError) return AppErrorView(onRetry: _reload);
        final trips = snapshot.data;
        if (trips == null) return const AppLoading();
        if (trips.isEmpty) return _empty(l10n);
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _trips;
          },
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: AppSize.pad16),
            itemCount: trips.length,
            separatorBuilder: (_, _) => const SizedBox(height: _cardGap),
            itemBuilder: (context, i) => TripCardView(
              trip: trips[i],
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.searchDetails, arguments: trips[i].id),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final driver = _driver;
    final Widget content;
    if (driver && _tab == 1) {
      content = OrdersFeed(orders: _orders, onReload: () => _reloadOrders(join: true), onTap: _openOrder);
    } else {
      content = _feed(l10n);
    }
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(title: l10n.searchTitle, trailing: _filterButton()),
          Padding(
            padding: const EdgeInsets.all(AppSize.pad16),
            child: SegmentedTabs(
              key: Key(driver ? 'search_tabs_driver' : 'search_tabs_passenger'),
              labels: driver
                  ? [l10n.driverOrdersTabTrips, l10n.driverOrdersTabOrders]
                  : [l10n.searchTabCars, l10n.searchTabBuses],
              index: _tab,
              onChanged: _selectTab,
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}
