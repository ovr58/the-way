import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/avatar.dart';
import '../../../widgets/rating_line.dart';
import '../../../widgets/trip_card_view.dart';

/// Значки услуг заказа на карточке и в шторке — те же, что у карточки поездки («Базовые экраны - Поездки есть»).
const orderExtraIcons = {
  ServiceKind.pets: 'system_paw',
  ServiceKind.luggage: 'system_bag_smile',
  ServiceKind.childSeat: 'system_baby',
};

/// «2 места» или «Посылка M» (у поездки с посылкой — оба).
List<(String, String)> orderLoadTags(AppLocalizations l10n, int seats, ParcelSize parcel) => [
      if (seats > 0) ('users_user_rounded', l10n.driverOrdersSeats(seats)),
      if (parcel != ParcelSize.none) ('system_box', l10n.driverOrdersParcel(parcel.json ?? '')),
    ];

String orderExtraText(AppLocalizations l10n, ServiceKind kind) => switch (kind) {
      ServiceKind.pets => l10n.tripCardPets,
      ServiceKind.luggage => l10n.tripCardLuggage,
      _ => l10n.tripCardChildSeat,
    };

/// Карточка заказа пассажира в ленте водителя — раскладка карточки поездки «Базовые экраны - Поездки есть»: пассажир с
/// рейтингом и «N км», маршрут и «N остановки», «Прибытие ~», места или посылка, услуги, дата и
/// время выезда. Цены у открытого заказа нет — её назначает водитель откликом, низ карточки —
/// только дата. Части карточки поездки приватны в `widgets/trip_card_view.dart` (чужой шов), раскладка
/// повторена здесь по тем же числам кадра.
class OrderCardView extends StatelessWidget {
  const OrderCardView({super.key, required this.order, this.onTap});

  final OrderCard order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSize.radius12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSize.radius12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSize.pad16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OrderPassengerLine(passenger: order.passenger, distanceKm: order.distanceKm),
              const SizedBox(height: AppSize.gap12),
              _Way(order: order),
              const SizedBox(height: AppSize.gap12),
              OrderTag(icon: 'time_history', text: l10n.tripCardArrival(formatArrival(order.departsAt, order.arrivesAt))),
              const SizedBox(height: AppSize.gap12),
              Wrap(
                spacing: AppSize.gap12,
                runSpacing: AppSize.gap4,
                children: [
                  for (final (icon, text) in orderLoadTags(l10n, order.seats, order.parcelSize)) OrderTag(icon: icon, text: text),
                  for (final e in orderExtraIcons.keys)
                    if (order.extras.contains(e)) OrderTag(icon: orderExtraIcons[e]!, text: orderExtraText(l10n, e)),
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
                  child: OrderTag(icon: 'time_calendar', text: formatTripDateTime(order.departsAt)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Фото, имя и рейтинг пассажира, «N км» — строка `headline` «Базовые экраны - Поездки есть».
class OrderPassengerLine extends StatelessWidget {
  const OrderPassengerLine({super.key, required this.passenger, this.distanceKm});

  final UserBrief passenger;
  final num? distanceKm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final distance = distanceKm;
    return Row(
      children: [
        Avatar(url: passenger.photoUrl),
        const SizedBox(width: AppSize.gap12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                passenger.name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSize.gap2),
              Row(
                children: [
                  RatingLine(rating: passenger.rating, tripsCount: passenger.tripsCount, tripsWithReviews: false),
                  if (distance != null) ...[
                    const SizedBox(width: AppSize.gap8),
                    const AppIcon('map_map_point', size: AppSize.icon14, color: AppColors.textTertiary),
                    const SizedBox(width: AppSize.gap4),
                    Text(
                      l10n.tripCardDistance(distance.toStringAsFixed(1)),
                      style: AppType.body2.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Значок 14 и текст 15 — `tag` «Базовые экраны - Поездки есть».
class OrderTag extends StatelessWidget {
  const OrderTag({super.key, required this.icon, required this.text});

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

/// Маршрут заказа: точка старта, «N остановки» (если есть), точка финиша — `Way` «Базовые экраны - Поездки есть».
class _Way extends StatelessWidget {
  const _Way({required this.order});

  final OrderCard order;

  // Значки маршрута в кадре: квадрат 10, круг 6, линия 22 — в шкале размеров этих ступеней нет.
  static const _point = 10.0;
  static const _stopDot = 6.0;
  static const _lineHeight = 22.0;

  Widget _line() => SizedBox(
        width: _point,
        height: _lineHeight,
        child: Center(child: Container(width: AppSize.stroke1, color: AppColors.textPrimary)),
      );

  Widget _end(Stop s, BoxDecoration mark, TextStyle style) => Row(
        children: [
          Container(width: _point, height: _point, decoration: mark),
          const SizedBox(width: AppSize.gap8),
          Expanded(child: Text(cardAddress(s), maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = AppType.body2.copyWith(color: AppColors.textPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _end(
          order.from,
          BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(AppSize.radius2)),
          style,
        ),
        _line(),
        if (order.stopsCount > 0) ...[
          Row(
            children: [
              const SizedBox(width: AppSize.pad2),
              Container(
                width: _stopDot,
                height: _stopDot,
                decoration: const BoxDecoration(color: AppColors.textPrimary, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSize.gap12),
              Text(
                l10n.tripCardStops(order.stopsCount),
                style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          _line(),
        ],
        _end(
          order.to,
          BoxDecoration(
            border: Border.all(color: AppColors.textPrimary, width: AppSize.stroke2),
            borderRadius: BorderRadius.circular(AppSize.radius2),
          ),
          style,
        ),
      ],
    );
  }
}
