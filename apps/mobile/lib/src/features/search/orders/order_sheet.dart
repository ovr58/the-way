import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/session.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/app_loading.dart';
import '../../../widgets/app_radio.dart';
import '../../../widgets/road_illustration.dart';
import '../../../widgets/trip_card_view.dart';
import '../../auth/data/api_error.dart';
import '../../orders/data/order_repository.dart';
import '../details/route_block.dart';
import 'order_card_view.dart';

/// Чем закончилась шторка отклика: экран ленты по нему показывает снэкбар, перечитывает ленту или
/// открывает мастер поездки.
sealed class OrderSheetResult {
  const OrderSheetResult();
}

/// Отклик своей поездкой принят: у пассажира бронь «Ожидает оплаты».
class OrderResponded extends OrderSheetResult {
  const OrderResponded();
}

/// Заказ уже не открыт (`order_unavailable`; деталей нет — `not_found`).
class OrderUnavailable extends OrderSheetResult {
  const OrderUnavailable();
}

/// «Создать поездку»: мастер водителя, заполненный из [order].
class OrderCreateTrip extends OrderSheetResult {
  const OrderCreateTrip(this.order);

  final OrderDetails order;
}

/// Шторка «Откликнуться на заказ» поверх ленты заказов — раскладка шторки брони «Бронирование».
Future<OrderSheetResult?> showOrderSheet(BuildContext context, String orderId) =>
    showModalBottomSheet<OrderSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.overlayScrim,
      builder: (_) => OrderSheet(orderId: orderId),
    );

/// Содержимое шторки: заказ (пассажир, дата, места или посылка, точки, услуги — без переключателей) и
/// «Ваши поездки в этот день» (`matchingTrips`) с суммой брони; выбор одной → `POST /orders/{id}/respond`.
class OrderSheet extends StatefulWidget {
  const OrderSheet({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<OrderSheet> {
  // Высота шторки, пока заказ грузится или не загрузился — как у шторки брони.
  static const _stateHeight = 240.0;
  // Строка поездки и строка услуги в кадре «Бронирование» — 58 (в шкале высот этой ступени нет).
  static const _rowHeight = 58.0;

  OrderRepository? _repo;
  OrderDetails? _order;
  bool _failed = false;
  String? _tripId;
  bool _submitting = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repo != null) return;
    _repo = OrderRepository(AppSession.of(context).api);
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final order = await _repo!.details(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        // Единственная подходящая поездка выбрана сама; из двух и больше выбирает водитель.
        if (order.matchingTrips.length == 1) _tripId = order.matchingTrips.single.trip.id;
      });
    } catch (e) {
      if (!mounted) return;
      // Заказ взяли или отменили, пока лента была открыта: чужой не открытый заказ — 404.
      if (apiErrorCode(e) == 'not_found') {
        Navigator.of(context).pop(const OrderUnavailable());
        return;
      }
      setState(() => _failed = true);
    }
  }

  Future<void> _respond() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repo!.respond(widget.orderId, _tripId!);
      navigator.pop(const OrderResponded());
    } catch (e) {
      if (!mounted) return;
      final code = apiErrorCode(e);
      if (code == 'order_unavailable') {
        navigator.pop(const OrderUnavailable());
        return;
      }
      setState(() {
        _submitting = false;
        // `blocked` показывает экран блокировки (перехватчик), своего текста у шторки нет.
        _error = switch (code) {
          'blocked' => null,
          'order_mismatch' => l10n.driverOrdersErrorMismatch,
          _ => l10n.driverOrdersErrorGeneric,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final order = _order;
    final Widget body;
    if (_failed) {
      body = SizedBox(height: _stateHeight, child: AppErrorView(onRetry: _load));
    } else if (order == null) {
      body = const SizedBox(height: _stateHeight, child: AppLoading());
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: SingleChildScrollView(child: _form(l10n, order))),
          _bottomBar(l10n, order),
        ],
      );
    }
    return AppBottomSheet(
      title: l10n.driverOrdersSheetTitle,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: body,
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSize.pad8),
        child: Text(text, style: AppType.titlesFootnote.copyWith(color: AppColors.textPrimary)),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSize.pad16),
        decoration: BoxDecoration(color: AppColors.bgSurface, borderRadius: BorderRadius.circular(AppSize.radius12)),
        child: child,
      );

  TripArt _art(OrderDetails o) => o.parcelOnly
      ? TripArt.box
      : (o.parcelSize == ParcelSize.none ? TripArt.road : TripArt.roadWithBox);

  /// Отмеченная точка — как выбранный вариант точки «Бронирование»: точки задал пассажир, водитель их не выбирает.
  Widget _pointRow(Stop s) => Row(
        children: [
          const AppRadio(selected: true),
          const SizedBox(width: AppSize.gap8),
          Expanded(child: Text(stopLabel(s), style: AppType.body2.copyWith(color: AppColors.textPrimary))),
        ],
      );

  /// Промежуточные остановки заказа — тем же видом, что точки, без дороги.
  Widget _middle(List<Stop> stops) => _card(
        child: Column(
          children: [
            for (var i = 0; i < stops.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSize.gap16),
              _pointRow(stops[i]),
            ],
          ],
        ),
      );

  /// Точка отправления или конечная: дорога «Бронирование» и отмеченная точка.
  Widget _point(OrderDetails o, Stop s) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RoadIllustration(width: 284, height: 164, art: _art(o)),
            const SizedBox(height: AppSize.gap12),
            _pointRow(s),
          ],
        ),
      );

  Widget _extraRow(AppLocalizations l10n, ServiceKind kind) {
    final (String title, String hint) = switch (kind) {
      ServiceKind.childSeat => (l10n.bookingExtraChildSeat, l10n.bookingExtraChildSeatHint),
      ServiceKind.luggage => (l10n.bookingExtraLuggage, l10n.bookingExtraLuggageHint),
      _ => (l10n.bookingExtraPets, l10n.bookingExtraPetsHint),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: _rowHeight),
      padding: const EdgeInsets.symmetric(vertical: AppSize.pad8),
      child: Row(
        children: [
          AppIcon(orderExtraIcons[kind]!, size: AppSize.icon18, color: AppColors.textSecondary),
          const SizedBox(width: AppSize.gap8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.titlesFootnote.copyWith(color: AppColors.textPrimary)),
                Text(hint, style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripRow(AppLocalizations l10n, OrderTripMatch m) {
    final trip = m.trip;
    return InkWell(
      key: Key('order_trip_${trip.id}'),
      onTap: () => setState(() {
        _tripId = trip.id;
        _error = null;
      }),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _rowHeight),
        child: Row(
          children: [
            AppRadio(selected: _tripId == trip.id),
            const SizedBox(width: AppSize.gap8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.driverOrdersTripLine(trip.number, formatTripTime(trip.departsAt)),
                    style: AppType.titlesFootnote.copyWith(color: AppColors.textPrimary),
                  ),
                  Text(
                    l10n.driverOrdersTripSeats(trip.seatsFree),
                    style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              l10n.driverOrdersTotal(m.priceTotal),
              style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(AppLocalizations l10n, OrderDetails o) {
    final extras = orderExtraIcons.keys.where(o.extras.contains).toList();
    final comment = o.parcelComment;
    final middle = o.stops.length > 2 ? o.stops.sublist(1, o.stops.length - 1) : const <Stop>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OrderPassengerLine(passenger: o.passenger, distanceKm: o.distanceKm),
              const SizedBox(height: AppSize.gap12),
              Wrap(
                spacing: AppSize.gap12,
                runSpacing: AppSize.gap4,
                children: [
                  OrderTag(icon: 'time_calendar', text: formatTripDateTime(o.departsAt)),
                  OrderTag(icon: 'time_history', text: l10n.tripCardArrival(formatArrival(o.departsAt, o.arrivesAt))),
                  for (final (icon, text) in orderLoadTags(l10n, o.seats, o.parcelSize)) OrderTag(icon: icon, text: text),
                ],
              ),
              if (comment != null && comment.isNotEmpty) ...[
                const SizedBox(height: AppSize.gap8),
                Text(comment, style: AppType.body2.copyWith(color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSize.gap16),
        _label(l10n.bookingPickup),
        _point(o, o.from),
        if (middle.isNotEmpty) ...[
          const SizedBox(height: AppSize.gap16),
          _label(l10n.driverOrdersStops),
          _middle(middle),
        ],
        const SizedBox(height: AppSize.gap16),
        _label(l10n.bookingDropoff),
        _point(o, o.to),
        if (extras.isNotEmpty) ...[
          const SizedBox(height: AppSize.gap16),
          _label(l10n.bookingExtras),
          _card(child: Column(children: [for (final e in extras) _extraRow(l10n, e)])),
        ],
        const SizedBox(height: AppSize.gap16),
        _label(l10n.driverOrdersMyTrips),
        _card(
          child: o.matchingTrips.isEmpty
              ? Text(l10n.driverOrdersNoTrips, style: AppType.body2.copyWith(color: AppColors.textSecondary))
              : Column(children: [for (final m in o.matchingTrips) _tripRow(l10n, m)]),
        ),
      ],
    );
  }

  Widget _bottomBar(AppLocalizations l10n, OrderDetails o) {
    final hasTrips = o.matchingTrips.isNotEmpty;
    final chosen = _tripId != null;
    return Padding(
      padding: const EdgeInsets.only(top: AppSize.pad12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSize.pad8),
              child: Text(
                _error!,
                key: const Key('order_error'),
                textAlign: TextAlign.center,
                style: AppType.body2.copyWith(color: AppColors.statusError),
              ),
            ),
          if (hasTrips) ...[
            AppButton(
              key: const Key('order_respond'),
              label: l10n.driverOrdersRespond,
              loading: _submitting,
              kind: chosen ? AppButtonKind.primary : AppButtonKind.neutral,
              onPressed: chosen ? _respond : null,
            ),
            const SizedBox(height: AppSize.gap8),
          ],
          AppButton(
            key: const Key('order_create_trip'),
            label: l10n.driverOrdersCreateTrip,
            kind: hasTrips ? AppButtonKind.outline : AppButtonKind.primary,
            onPressed: () => Navigator.of(context).pop(OrderCreateTrip(o)),
          ),
        ],
      ),
    );
  }
}
