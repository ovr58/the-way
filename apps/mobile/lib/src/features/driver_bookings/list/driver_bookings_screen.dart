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
import '../../../widgets/confirm_sheet.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_loading.dart';
import '../../../widgets/info_tile.dart';
import '../../../widgets/road_illustration.dart';
import '../../driver_trips/edit/trip_actions.dart';
import '../../system/temp_blocked_screen.dart';
import '../data/driver_bookings_repository.dart';
import '../response/booking_response_screen.dart';
import '../widgets/blocks.dart';

class _Data {
  const _Data(this.trip, this.bookings);

  final TripDetails trip;
  final List<Booking> bookings;
}

/// «Пассажиры» поездки водителя («Редактирование - Пассажиры есть» – «Бронь отклонена»): стоимость, маршрут, сведения о поездке, список всех
/// заявок, водитель с авто и цены. Нажатие на заявку `requested` открывает отклик («Отлик»), на
/// остальные — профиль пассажира.
class DriverBookingsScreen extends StatefulWidget {
  const DriverBookingsScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<DriverBookingsScreen> createState() => _DriverBookingsScreenState();
}

class _DriverBookingsScreenState extends State<DriverBookingsScreen> {
  DriverBookingsRepository? _repo;
  Future<_Data>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo ??= DriverBookingsRepository(AppSession.of(context).api);
    _future ??= _load();
  }

  Future<_Data> _load() async {
    final repo = _repo!;
    final result = await Future.wait<Object>([repo.trip(widget.tripId), repo.tripBookings(widget.tripId)]);
    return _Data(result[0] as TripDetails, result[1] as List<Booking>);
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

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _open(_Data data, Booking booking) async {
    final navigator = Navigator.of(context);
    if (booking.status != BookingStatus.requested) {
      navigator.pushNamed(
        AppRoutes.driverBookingsPassenger,
        arguments: {'userId': booking.passenger.id, 'bookingId': booking.id},
      );
      return;
    }
    final answer = await navigator.push<BookingAnswer>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'driver_bookings/response'),
        builder: (_) => BookingResponseScreen(trip: data.trip, booking: booking),
      ),
    );
    if (!mounted || answer == null) return;
    _reload();
    final l10n = AppLocalizations.of(context);
    showSuccessSnack(
      context,
      answer == BookingAnswer.confirmed ? l10n.driverBookingsConfirmed : l10n.driverBookingsRejected,
    );
  }

  bool _cancelable(TripDetails trip) => TripMenuButton.shownFor(trip);

  /// «Отменить поездку»: окно с последствиями для аккаунта, затем `POST /cancel` и возврат к деталям.
  Future<void> _cancelTrip(_Data data) async {
    final l10n = AppLocalizations.of(context);
    final repo = _repo!;
    try {
      final preview = await repo.cancelPreview(widget.tripId);
      if (!mounted) return;
      await showConfirmSheet(
        context,
        title: l10n.driverBookingsCancelTitle,
        body: data.trip.editLocked
            ? l10n.driverBookingsCancelWithPassengers(preview.cancellationsLast30)
            : l10n.driverBookingsCancelPlain,
        confirmLabel: l10n.driverBookingsCancelTrip,
        backLabel: l10n.driverBookingsCancelBack,
        onConfirm: _doCancel,
      );
    } catch (_) {
      if (mounted) showErrorSnack(context, l10n.driverBookingsErrorGeneric);
    }
  }

  Future<void> _doCancel() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    try {
      final result = await _repo!.cancelTrip(widget.tripId);
      // Экран открыт из деталей поездки: возвращаемся к ним с результатом, детали перечитываются.
      navigator.pop(true);
      // Отмена дала блокировку (две за 30 дней): экран «Бронь отменена» поверх деталей.
      if (result.blockedUntil != null) navigator.push(TempBlockedScreen.route(TempBlockedRole.driver));
    } catch (_) {
      if (mounted) showErrorSnack(context, l10n.driverBookingsErrorGeneric);
    }
  }

  (String, Color)? _status(AppLocalizations l10n, BookingStatus status) => switch (status) {
        BookingStatus.requested => (l10n.driverBookingsStatusRequested, AppColors.accentWarning),
        BookingStatus.awaitingPayment => (l10n.driverBookingsStatusAwaitingPayment, AppColors.accentPrimary),
        BookingStatus.paid => (l10n.driverBookingsStatusPaid, AppColors.accentPrimary),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: FutureBuilder<_Data>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          return Column(
            children: [
              AppHeader(
                title: l10n.driverBookingsTripTitle,
                bordered: false,
                onBack: () => Navigator.of(context).maybePop(),
                // «⋯» («Редактирование - Пассажиры есть»): то же меню поездки, что в деталях; после действия заявки перечитываются.
                trailing: data != null && _cancelable(data.trip)
                    ? TripMenuButton(trip: data.trip, onChanged: _reload)
                    : null,
              ),
              Expanded(
                child: snapshot.hasError
                    ? AppErrorView(onRetry: _reload)
                    : data == null
                        ? const AppLoading()
                        : Column(children: [
                            Expanded(child: _content(context, l10n, data)),
                            if (_cancelable(data.trip))
                              BottomBar(
                                child: _CancelButton(
                                  label: l10n.driverBookingsCancelTrip,
                                  onPressed: () => _cancelTrip(data),
                                ),
                              ),
                          ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, AppLocalizations l10n, _Data data) {
    final trip = data.trip;
    const gap = SizedBox(height: AppSize.gap20);
    const smallGap = SizedBox(height: AppSize.gap12);
    // Ручное обновление — та же проверка событий, что таймер оболочки, и сброс таймера.
    return RefreshIndicator(
      onRefresh: () {
        refreshUpdates();
        final next = _load();
        setState(() => _future = next);
        return next.then<void>((_) {}, onError: (_) {});
      },
      child: ListView(
      padding: const EdgeInsets.only(bottom: AppSize.pad20),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSize.pad8),
          child: InfoTile(label: l10n.driverBookingsCost, value: l10n.commonPrice(trip.paidTotal ?? 0)),
        ),
        gap,
        SectionTitle(l10n.driverBookingsRoute),
        smallGap,
        RouteCard(stops: trip.stops, art: TripArt.ofTrip(trip.kind)),
        smallGap,
        TripInfoCard(trip: trip),
        gap,
        SectionTitle(l10n.driverBookingsPassengers),
        smallGap,
        CardBlock(
          child: data.bookings.isEmpty
              ? Text(l10n.driverBookingsNoRequests, style: AppType.body2.copyWith(color: AppColors.textSecondary))
              : Column(
                  children: [
                    for (final b in data.bookings) ...[
                      PassengerRow(
                        booking: b,
                        statusLabel: _status(l10n, b.status)?.$1,
                        statusColor: _status(l10n, b.status)?.$2,
                        onTap: () => _open(data, b),
                      ),
                      if (b != data.bookings.last) const SizedBox(height: AppSize.gap16),
                    ],
                  ],
                ),
        ),
        gap,
        SectionTitle(l10n.driverBookingsDriver),
        smallGap,
        DriverCard(
          trip: trip,
          onOpenProfile: () => Navigator.of(context).pushNamed(AppRoutes.profile),
        ),
        gap,
        PriceCard(price: trip.price, stops: trip.stops, prices: trip.prices),
        ],
      ),
    );
  }
}

/// Красная кнопка «Отменить поездку» («Редактирование - Пассажиры есть»): заливка `status.error`, высота 48.
class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.statusError,
        borderRadius: BorderRadius.circular(AppSize.radius12),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSize.radius12),
          onTap: onPressed,
          child: Container(
            width: double.infinity,
            height: AppSize.height48,
            alignment: Alignment.center,
            child: Text(label, style: AppType.button1.copyWith(color: AppColors.textOnAccent)),
          ),
        ),
      );
}
