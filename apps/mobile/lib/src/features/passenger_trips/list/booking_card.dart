import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/avatar.dart';
import '../../../widgets/status_chip.dart';
import '../../../widgets/trip_card_view.dart';
import 'booking_status.dart';

/// «16 мая, 12:00–15:00».
String tripRange(AppLocalizations l10n, DateTime departs, DateTime arrives) => l10n.passengerTripsRange(
      DateFormat('d MMMM', 'ru').format(moscowTime(departs)),
      formatTripTime(departs),
      formatArrival(departs, arrives),
    );

/// Карточка брони пассажира в списке («Мои заказы - Есть заказы»): номер и статус, маршрут, теги, время и цена.
class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking, this.onTap});

  final Booking booking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trip = booking.trip;
    final label = statusLabel(l10n, booking);
    return Material(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(AppSize.radius12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSize.radius12),
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSize.pad16, AppSize.pad12, AppSize.pad16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      // Бронь из заказа несёт номер заказа: номер не меняется при отклике.
                      l10n.passengerTripsOrder(booking.orderNumber ?? booking.number),
                      style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                  if (label != null) StatusChip(label),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16, vertical: AppSize.pad12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Way(from: cardAddress(booking.from), to: cardAddress(booking.to)),
                  const SizedBox(height: AppSize.gap16),
                  _Tag(icon: 'time_history', text: l10n.tripCardArrival(formatArrival(trip.departsAt, trip.arrivesAt))),
                  const SizedBox(height: AppSize.gap16),
                  Wrap(
                    spacing: AppSize.gap12,
                    runSpacing: AppSize.gap4,
                    children: [
                      if (booking.seats > 0)
                        _Tag(icon: 'users_user_rounded', text: l10n.passengerTripsSeats(booking.seats)),
                      if (booking.extras.any((e) => e.kind == ExtraKind.pets))
                        _Tag(icon: 'system_paw', text: l10n.tripCardPets),
                      if (booking.extras.any((e) => e.kind == ExtraKind.luggage))
                        _Tag(icon: 'system_bag_smile', text: l10n.tripCardLuggage),
                      if (booking.extras.any((e) => e.kind == ExtraKind.childSeat))
                        _Tag(icon: 'system_baby', text: l10n.tripCardChildSeat),
                      if (booking.parcelSize != ParcelSize.none)
                        _Tag(
                          icon: 'system_box',
                          text: l10n.passengerTripsParcel(booking.parcelSize.json ?? ''),
                        ),
                    ],
                  ),
                  if (showsDriverFound(booking)) ...[
                    const SizedBox(height: AppSize.gap12),
                    _DriverFound(driver: trip.driver),
                  ],
                  const SizedBox(height: AppSize.gap12),
                  Container(
                    padding: const EdgeInsets.all(AppSize.pad8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderDefault, width: AppSize.stroke1),
                      borderRadius: BorderRadius.circular(AppSize.radius8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: _Tag(
                            icon: 'time_calendar',
                            text: tripRange(l10n, trip.departsAt, trip.arrivesAt),
                          ),
                        ),
                        const SizedBox(width: AppSize.gap8),
                        Text(
                          l10n.commonPrice(booking.priceTotal),
                          style: AppType.title3.copyWith(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Карточка заказа пассажира в списке — раскладка карточки брони «Мои заказы - Есть заказы» без цены (её назначает водитель
/// откликом): «Заказ №» и плашка статуса, маршрут, «Прибытие ~», места или посылка, услуги, дата и
/// время выезда.
class PassengerOrderCard extends StatelessWidget {
  const PassengerOrderCard({super.key, required this.order, this.onTap});

  final OrderCard order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final o = order;
    return Material(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(AppSize.radius12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSize.radius12),
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSize.pad16, AppSize.pad12, AppSize.pad16, 0),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16, vertical: AppSize.pad12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Way(from: cardAddress(o.from), to: cardAddress(o.to)),
                  const SizedBox(height: AppSize.gap16),
                  _Tag(icon: 'time_history', text: l10n.tripCardArrival(formatArrival(o.departsAt, o.arrivesAt))),
                  const SizedBox(height: AppSize.gap16),
                  Wrap(
                    spacing: AppSize.gap12,
                    runSpacing: AppSize.gap4,
                    children: [
                      if (o.seats > 0) _Tag(icon: 'users_user_rounded', text: l10n.passengerTripsSeats(o.seats)),
                      if (o.extras.contains(ServiceKind.pets)) _Tag(icon: 'system_paw', text: l10n.tripCardPets),
                      if (o.extras.contains(ServiceKind.luggage))
                        _Tag(icon: 'system_bag_smile', text: l10n.tripCardLuggage),
                      if (o.extras.contains(ServiceKind.childSeat))
                        _Tag(icon: 'system_baby', text: l10n.tripCardChildSeat),
                      if (o.parcelSize != ParcelSize.none)
                        _Tag(icon: 'system_box', text: l10n.passengerTripsParcel(o.parcelSize.json ?? '')),
                    ],
                  ),
                  const SizedBox(height: AppSize.gap12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSize.pad8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderDefault, width: AppSize.stroke1),
                      borderRadius: BorderRadius.circular(AppSize.radius8),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _Tag(icon: 'time_calendar', text: tripRange(l10n, o.departsAt, o.arrivesAt)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Блок «Найден водитель» (`Component 4` в «Мои заказы - Есть заказы»): фото и имя водителя вместо плашки статуса.
class _DriverFound extends StatelessWidget {
  const _DriverFound({required this.driver});

  final UserBrief driver;

  // Фото в блоке кадра — 28; такой ступени в шкале размеров нет.
  static const _photo = 28.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Avatar(url: driver.photoUrl, size: _photo),
        const SizedBox(width: AppSize.gap4),
        Flexible(
          child: Text.rich(
            TextSpan(
              style: AppType.body2.copyWith(color: AppColors.textPrimary),
              children: [
                TextSpan(text: '${l10n.passengerTripsDriverFound} '),
                TextSpan(text: driver.name ?? '', style: AppType.titlesSubheadline),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Маршрут: старт (заливка), линия, финиш (контур).
class _Way extends StatelessWidget {
  const _Way({required this.from, required this.to});

  final String from;
  final String to;

  // Значок точки в кадре — 10, линия — 20; таких ступеней в шкале размеров нет.
  static const _point = 10.0;
  static const _line = 20.0;

  @override
  Widget build(BuildContext context) {
    final style = AppType.body2.copyWith(color: AppColors.textPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: _point,
              height: _point,
              decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(AppSize.radius2)),
            ),
            const SizedBox(width: AppSize.gap8),
            Expanded(child: Text(from, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
          ],
        ),
        SizedBox(
          width: _point,
          height: _line,
          child: Center(child: Container(width: AppSize.stroke1, color: AppColors.textPrimary)),
        ),
        Row(
          children: [
            Container(
              width: _point,
              height: _point,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.textPrimary, width: AppSize.stroke2),
                borderRadius: BorderRadius.circular(AppSize.radius2),
              ),
            ),
            const SizedBox(width: AppSize.gap8),
            Expanded(child: Text(to, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
          ],
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: AppSize.icon14, color: AppColors.textSecondary),
          const SizedBox(width: AppSize.gap4),
          Flexible(child: Text(text, style: AppType.body2.copyWith(color: AppColors.textPrimary))),
        ],
      );
}
