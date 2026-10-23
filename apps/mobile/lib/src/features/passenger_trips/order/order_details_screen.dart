import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/session.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/app_loading.dart';
import '../../../widgets/info_tile.dart';
import '../../../widgets/road_illustration.dart';
import '../../../widgets/status_chip.dart';
import '../../../widgets/trip_card_view.dart';
import '../../booking/cancel/cancel_popup.dart';
import '../../booking/data/booking_changes.dart';
import '../../search/details/route_block.dart';
import '../../trip_new/trip_new_actions.dart' show apiErrorCode;
import '../data/passenger_trips_repository.dart';
import '../list/booking_status.dart';

/// Детали заказа пассажира (Б2.4) — раскладка деталей брони «Детали поездки - Бронь есть» без блока водителя и без цены: «Заказ №»
/// и плашка статуса, маршрут, дата и время выезда, «Примерное время прибытия», места или посылка с
/// комментарием, услуги. У открытого заказа — «Отменить заказ»: окно по «Детали поездки - Отмена брони» без счётчика отмен (отмена
/// заказа в счёт 2/30 не идёт) → `POST /orders/{id}/cancel` → снэкбар «Заказ отменён».
class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, required this.orderId, this.repository});

  final String orderId;
  final PassengerTripsRepository? repository;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late PassengerTripsRepository _repo;
  late Future<OrderDetails> _future;
  bool _started = false;
  bool _cancelling = false;

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

  void _onBookingsChanged() {
    if (mounted) _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _repo = widget.repository ?? PassengerTripsRepository(AppSession.of(context).api);
      _future = _repo.order(widget.orderId);
    }
  }

  void _reload() => setState(() {
        _future = _repo.order(widget.orderId);
      });

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showCancelPopup(
      context,
      CancelPopup(
        title: l10n.orderCancelTitle,
        body: l10n.orderCancelBody,
        keepLabel: l10n.cancelKeep,
        confirmLabel: l10n.cancelConfirm,
      ),
    );
    if (!confirmed || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await _repo.cancelOrder(widget.orderId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.orderCancelled)));
    } catch (e) {
      final text = apiErrorCode(e) == 'invalid_transition' ? l10n.orderErrorChanged : l10n.tripNewErrorGeneric;
      messenger.showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted) setState(() => _cancelling = false);
      // Заказ на сервере мог измениться: перечитать детали и список «Мои заказы».
      notifyBookingsChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(title: l10n.orderDetailsTitle, onBack: () => Navigator.of(context).maybePop(), bordered: false),
          Expanded(
            child: FutureBuilder<OrderDetails>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return AppErrorView(onRetry: _reload);
                if (!snapshot.hasData) return const AppLoading();
                final order = snapshot.data!;
                return Column(
                  children: [
                    Expanded(child: _Body(order: order)),
                    if (order.status == OrderStatus.open)
                      ColoredBox(
                        color: AppColors.bgSurface,
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSize.pad16),
                            child: AppButton(
                              key: const Key('order_cancel'),
                              label: l10n.orderCancel,
                              size: AppButtonSize.medium,
                              kind: AppButtonKind.dangerOutline,
                              loading: _cancelling,
                              onPressed: _cancel,
                            ),
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

class _Body extends StatelessWidget {
  const _Body({required this.order});

  final OrderDetails order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final o = order;
    final art = o.kind == TripKind.parcel
        ? TripArt.box
        : (o.parcelSize == ParcelSize.none ? TripArt.road : TripArt.roadWithBox);
    final amount = [
      if (o.kind == TripKind.ride) InfoTile(label: l10n.orderSeatsLabel, value: '${o.seats}'),
      if (o.parcelSize != ParcelSize.none) InfoTile(label: l10n.orderParcelLabel, value: o.parcelSize.json ?? ''),
    ];
    final comment = o.parcelComment;
    // Белые блоки — во всю ширину, как в деталях брони («Детали поездки - Бронь есть»); заголовки — с полем 16.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSize.pad16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.passengerTripsOrder(o.number),
                    style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
                  ),
                ),
                StatusChip(orderStatusLabel(l10n, o.status)),
              ],
            ),
          ),
          const SizedBox(height: AppSize.gap20),
          _SectionTitle(l10n.passengerTripsRouteTitle),
          const SizedBox(height: AppSize.gap12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoadIllustration(art: art),
                const SizedBox(height: AppSize.gap12),
                RouteBlock(stops: o.stops),
              ],
            ),
          ),
          const SizedBox(height: AppSize.gap12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoTileRow(
                  children: [
                    InfoTile(label: l10n.passengerTripsDepartureLabel, value: formatTripDateTime(o.departsAt)),
                    InfoTile(label: l10n.tripNewArrival, value: formatArrival(o.departsAt, o.arrivesAt)),
                  ],
                ),
                if (amount.isNotEmpty) ...[
                  const SizedBox(height: AppSize.gap12),
                  InfoTileRow(children: amount),
                ],
                if (comment != null && comment.isNotEmpty) ...[
                  const SizedBox(height: AppSize.gap12),
                  InfoTile(label: l10n.driverBookingsParcelComment, value: comment),
                ],
                if (o.extras.isNotEmpty) ...[
                  const SizedBox(height: AppSize.gap12),
                  Wrap(
                    spacing: AppSize.gap12,
                    runSpacing: AppSize.gap4,
                    children: [
                      if (o.extras.contains(ServiceKind.luggage)) _Badge('system_bag_smile', l10n.tripCardLuggage),
                      if (o.extras.contains(ServiceKind.pets)) _Badge('system_paw', l10n.tripCardPets),
                      if (o.extras.contains(ServiceKind.childSeat)) _Badge('system_baby', l10n.tripCardChildSeat),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
        child: Text(text, style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSize.pad16),
        decoration: BoxDecoration(color: AppColors.bgSurface, borderRadius: BorderRadius.circular(AppSize.radius12)),
        child: child,
      );
}

class _Badge extends StatelessWidget {
  const _Badge(this.icon, this.text);

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: AppSize.icon14, color: AppColors.textSecondary),
          const SizedBox(width: AppSize.gap4),
          Text(text, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
        ],
      );
}
