import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/expand_toggle.dart';
import '../../../widgets/trip_card_view.dart';
import '../limit_screen.dart';
import '../order_created_screen.dart';
import '../moscow_time.dart';
import '../trip_created_screen.dart';
import '../trip_new_actions.dart';
import '../wizard_controller.dart';

/// Маршруты мастера: после публикации они уходят из стека, остаётся то, откуда мастер открыли.
bool leaveTripFlow(Route<dynamic> route) {
  final name = route.settings.name;
  return name != null && name != AppRoutes.tripNew && name != AppRoutes.tripNewReturn && name != AppRoutes.tripNewEdit;
}

/// Данные окна «Опубликовать поездку?» («Новый заказ - Выбор доп услуг», «Обратное направление»): строки итога поездки; у заказа пассажира — без цены,
/// авто и типа бронирования, с местами.
class PublishSummary {
  const PublishSummary({
    required this.fromAddress,
    required this.toAddress,
    required this.extraStops,
    required this.dateTime,
    this.arrival,
    this.passengerSeats,
    this.priceFull,
    this.segments = const [],
    this.seats,
    this.extrasPrice,
    this.carLabel,
    this.extrasCount,
    this.parcels,
    this.modeLabel,
  });

  final String fromAddress;
  final String toAddress;
  final int extraStops;
  final String dateTime;

  /// «05.06.2026, 7:00 · в пути 23 ч» — дата и время прибытия и время в пути.
  final String? arrival;

  /// Места для пассажиров поездки — своей строкой, не в строке посылок.
  final int? passengerSeats;
  final int? priceFull;

  /// Места заказа пассажира.
  final int? seats;

  /// «Адрес - адрес» и цена каждого участка «между остановками».
  final List<(String, int)> segments;
  final int? extrasPrice;
  final String? carLabel;
  final int? extrasCount;
  final String? parcels;
  final String? modeLabel;

  static String _modeLabel(AppLocalizations l10n, BookingMode mode) =>
      mode == BookingMode.instant ? l10n.tripNewModeInstant : l10n.tripNewModeStandard;

  /// Строка прибытия: московские дата и время прибытия и время в пути.
  static String arrivalLine(AppLocalizations l10n, DateTime departs, DateTime arrives) {
    final at = moscowTime(arrives);
    return l10n.tripNewSumArrivalValue(
      '${ruDate(at)}, ${ruTime(TimeOfDay(hour: at.hour, minute: at.minute))}',
      travelTime(l10n, departs, arrives),
    );
  }

  static String _parcelSizes(Iterable<ExtraKind> kinds) =>
      kinds.map((k) => k.json!.split('_').last.toUpperCase()).join(', ');

  factory PublishSummary.fromController(AppLocalizations l10n, WizardController c) {
    final services = c.extras.entries.where((e) => !isParcelKind(e.key)).toList();
    return PublishSummary(
      fromAddress: c.stops.first.displayAddress,
      toAddress: c.stops.last.displayAddress,
      extraStops: c.stops.length - 2,
      dateTime: '${ruDate(c.date!)}, ${ruTime(c.departTime!)}',
      arrival: arrivalLine(l10n, c.departsAt!, c.arrivesAt!),
      passengerSeats: c.kind == TripKind.ride ? c.seatsTotal : null,
      priceFull: c.priceFull!,
      segments: [
        for (final p in c.pricePairs)
          ('${c.stops[p.$1].displayAddress} - ${c.stops[p.$2].displayAddress}', c.pairPrice(p.$1, p.$2) ?? 0),
      ],
      extrasPrice: services.fold<int>(0, (sum, e) => sum + e.value),
      carLabel: c.carLabel,
      extrasCount: services.length,
      parcels: c.hasParcel
          ? l10n.tripNewSumParcelsValue(_parcelSizes(parcelKinds.where(c.extraOn)), c.effectiveParcelSeats)
          : null,
      modeLabel: _modeLabel(l10n, c.bookingMode),
    );
  }

  /// Заказ пассажира: точки, дата, места (у поездки), число услуг, размер посылки.
  factory PublishSummary.fromOrder(AppLocalizations l10n, WizardController c) => PublishSummary(
        fromAddress: c.stops.first.displayAddress,
        toAddress: c.stops.last.displayAddress,
        extraStops: c.stops.length - 2,
        dateTime: '${ruDate(c.date!)}, ${ruTime(c.departTime!)}',
        arrival: arrivalLine(l10n, c.departsAt!, c.arrivesAt!),
        seats: c.kind == TripKind.ride ? c.seatsTotal : null,
        extrasCount: c.toOrderInput().extras.length,
        parcels: c.orderParcel == ParcelSize.none ? null : c.orderParcel.json,
      );

  /// Обратная поездка («Обратное направление»): остановки в обратном порядке, цены — как у исходной.
  factory PublishSummary.fromTrip(
    AppLocalizations l10n,
    TripDetails t, {
    required DateTime date,
    required TimeOfDay departTime,
    String? arrival,
  }) {
    final stops = t.stops.reversed.toList();
    const addr = stopAddress;
    final services = t.extrasPriced.where((e) => !isParcelKind(e.kind)).toList();
    final last = stops.length - 1;
    return PublishSummary(
      fromAddress: addr(stops.first),
      toAddress: addr(stops.last),
      extraStops: stops.length - 2,
      dateTime: '${ruDate(date)}, ${ruTime(departTime)}',
      arrival: arrival,
      passengerSeats: t.kind == TripKind.ride ? t.seatsTotal : null,
      priceFull: t.price,
      // Участки: новый (k, k+1) — исходный (n−2−k, n−1−k).
      segments: [
        if (last > 1)
          for (var k = 0; k < last; k++) ('${addr(stops[k])} - ${addr(stops[k + 1])}', _price(t, last - k - 1, last - k)),
      ],
      extrasPrice: services.fold<int>(0, (sum, e) => sum + e.price),
      carLabel: '${t.car.brand} ${t.car.model}, ${t.car.plate}',
      extrasCount: services.length,
      modeLabel: _modeLabel(l10n, t.bookingMode),
    );
  }

  static int _price(TripDetails t, int from, int to) {
    final found = t.prices.where((p) => p.fromIdx == from && p.toIdx == to);
    return found.isEmpty ? 0 : found.first.price;
  }
}

/// Окно «Опубликовать поездку?» («Новый заказ - Выбор доп услуг», «Обратное направление»). [onConfirm] делает запрос и сам уходит на следующий
/// экран или закрывает окно при ошибке; пока оно выполняется, кнопка показывает загрузку.
Future<void> showPublishDialog(
  BuildContext context, {
  required PublishSummary summary,
  required Future<void> Function() onConfirm,
  bool order = false,
  String? body,
}) {
  final l10n = AppLocalizations.of(context);
  return AppBottomSheet.show<void>(
    context,
    title: order ? l10n.orderPublishTitle : l10n.tripNewPublishTitle,
    child: _PublishSheet(
      summary: summary,
      onConfirm: onConfirm,
      order: order,
      body: body ?? (order ? l10n.orderPublishBody : l10n.tripNewPublishBody),
    ),
  );
}

/// Публикация заказа пассажира (Б2.1): окно по «Новый заказ - Выбор доп услуг» «Опубликовать заказ?» → `POST /orders` → «Заказ
/// опубликован!» (по «Новый заказ - Заказ создан», без лимитов и обратного маршрута); ошибки — снэкбар по коду.
Future<void> publishOrder(BuildContext context, WizardController c) {
  final l10n = AppLocalizations.of(context);
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  return showPublishDialog(
    context,
    order: true,
    summary: PublishSummary.fromOrder(l10n, c),
    onConfirm: () async {
      try {
        await c.repository.orders.create(c.toOrderInput());
        nav.pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const OrderCreatedScreen()),
          leaveTripFlow,
        );
      } catch (e) {
        nav.pop();
        final text = orderErrorText(l10n, e);
        if (text != null) showTripSnack(messenger, text);
      }
    },
  );
}

/// Публикация мастера: подтверждение → `POST /trips` → «Заказ опубликован!»; `limit_reached` —
/// окно лимита («Новый заказ - Маршрут сохранен»), остальные ошибки — снэкбар по коду.
Future<void> publishTrip(BuildContext context, WizardController c) {
  final l10n = AppLocalizations.of(context);
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  return showPublishDialog(
    context,
    summary: PublishSummary.fromController(l10n, c),
    // Отклик новой поездкой: пассажир сразу получит предложение, правка поездки после оплаты закрыта.
    body: c.orderId != null ? l10n.orderRespondPublishBody : null,
    onConfirm: () async {
      try {
        final trip = await c.repository.publish(c.toInput());
        nav.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => TripCreatedScreen(trip: trip, repository: c.repository, respond: c.orderId != null),
          ),
          leaveTripFlow,
        );
      } catch (e) {
        nav.pop();
        if (apiErrorCode(e) == 'limit_reached') {
          await showLimitDialog(
            nav,
            messenger,
            repository: c.repository,
            carId: c.carId!,
            date: c.date!,
            controller: c,
          );
        } else if (apiErrorCode(e) != 'blocked') {
          // `blocked` показывает экран блокировки (перехватчик), своей подсказки нет.
          showTripSnack(messenger, tripErrorText(l10n, e));
        }
      }
    },
  );
}

class _PublishSheet extends StatefulWidget {
  const _PublishSheet({required this.summary, required this.onConfirm, required this.body, this.order = false});

  final PublishSummary summary;
  final Future<void> Function() onConfirm;
  final bool order;
  final String body;

  @override
  State<_PublishSheet> createState() => _PublishSheetState();
}

class _PublishSheetState extends State<_PublishSheet> {
  bool _loading = false;
  bool _showPrices = false;

  Future<void> _confirm() async {
    setState(() => _loading = true);
    try {
      await widget.onConfirm();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = widget.summary;
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.body, style: AppType.body2.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppSize.gap12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(AppSize.radius12),
                  ),
                  child: Column(
                    children: [
                      _SumRow(label: l10n.tripNewSumFrom, value: s.fromAddress),
                      _SumRow(label: l10n.tripNewSumTo, value: s.toAddress),
                      _SumRow(label: l10n.tripNewSumStops, value: '${s.extraStops}'),
                      _SumRow(label: l10n.tripNewSumDateTime, value: s.dateTime),
                      if (s.arrival != null) _SumRow(label: l10n.tripNewSumArrival, value: s.arrival),
                      if (s.seats != null) _SumRow(label: l10n.orderSumSeats, value: '${s.seats}'),
                      if (s.passengerSeats != null) _SumRow(label: l10n.tripNewSumSeats, value: '${s.passengerSeats}'),
                      if (s.priceFull != null)
                        _SumRow(label: l10n.tripNewSumPrice, value: l10n.commonPrice(s.priceFull!)),
                      if (s.segments.isNotEmpty) ...[
                        _SumRow(
                          label: l10n.tripNewSumBetween,
                          trailing: ExpandToggle(
                            label: l10n.tripNewSumShowPrices,
                            expanded: _showPrices,
                            chipKey: const Key('publish_prices_chip'),
                            closeKey: const Key('publish_prices_collapse'),
                            onTap: () => setState(() => _showPrices = !_showPrices),
                          ),
                        ),
                        // цены участков выплывают тем же движением, что остановки маршрута.
                        ExpandReveal(
                          expanded: _showPrices,
                          child: Column(
                            children: [
                              for (final (label, price) in s.segments)
                                _SumRow(label: label, value: l10n.commonPrice(price), small: true),
                            ],
                          ),
                        ),
                      ],
                      if (s.extrasPrice != null)
                        _SumRow(label: l10n.tripNewSumExtrasPrice, value: l10n.commonPrice(s.extrasPrice!)),
                      if (s.carLabel != null) _SumRow(label: l10n.tripNewSumCar, value: s.carLabel!),
                      if (s.extrasCount != null)
                        _SumRow(
                          label: l10n.tripNewSumExtras,
                          value: '${s.extrasCount}',
                          last: s.parcels == null && s.modeLabel == null,
                        ),
                      if (s.parcels != null)
                        _SumRow(
                          label: widget.order ? l10n.orderSumParcel : l10n.tripNewSumParcels,
                          value: s.parcels!,
                          last: s.modeLabel == null,
                        ),
                      if (s.modeLabel != null)
                        _SumRow(label: l10n.tripNewSumMode, value: s.modeLabel!, last: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSize.gap16),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: l10n.commonCancel,
                kind: AppButtonKind.outline,
                size: AppButtonSize.medium,
                onPressed: _loading ? null : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSize.gap8),
            Expanded(
              child: AppButton(
                label: l10n.tripNewPublishYes,
                size: AppButtonSize.medium,
                loading: _loading,
                onPressed: _confirm,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SumRow extends StatelessWidget {
  const _SumRow({required this.label, this.value, this.trailing, this.small = false, this.last = false});

  final String label;
  final String? value;
  final Widget? trailing;
  final bool small;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: AppSize.height42),
      padding: const EdgeInsets.symmetric(vertical: AppSize.pad12),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: (small ? AppType.bodyFootnote : AppType.body2).copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSize.gap12),
          if (trailing != null) trailing! else
            Expanded(
              flex: 5,
              child: Text(
                value ?? '',
                textAlign: TextAlign.end,
                style: AppType.body2.copyWith(color: AppColors.textPrimary),
              ),
            ),
        ],
      ),
    );
  }
}
