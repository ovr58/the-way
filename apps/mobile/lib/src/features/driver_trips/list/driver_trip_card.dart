import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/avatar.dart';
import '../../../widgets/status_chip.dart';
import '../../../widgets/trip_card_view.dart';
import 'trip_parts.dart';

/// Число откликов поездки: заявки в ожидании, на оплате и оплаченные.
int responsesOf(DriverTripCard t) => t.requested + t.awaitingPayment + t.paid;

/// Карточка поездки водителя ровно как «Базовые экраны - Поездок нет»: «Заказ №N» и «Завершен» у завершённой, маршрут,
/// теги, при откликах — аватары откликнувшихся, «+N» и «N отклика», время и цена. Подписей пассажира
/// («Место забронировано», «Найден водитель») здесь нет.
class DriverTripCardView extends StatelessWidget {
  const DriverTripCardView({super.key, required this.trip, this.onTap});

  final DriverTripCard trip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final responses = responsesOf(trip);
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
                      l10n.driverTripsOrder(trip.number),
                      style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                  if (trip.effectiveStatus == TripStatus.completed) StatusChip(l10n.driverTripsCompleted),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16, vertical: AppSize.pad12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TripWay(
                    from: cardAddress(trip.from),
                    to: cardAddress(trip.to),
                    // Промежуточные остановки — «1 остановка», как на карточке пассажира.
                    stops: trip.stopsCount > 0 ? l10n.tripCardStops(trip.stopsCount) : null,
                  ),
                  const SizedBox(height: AppSize.gap16),
                  IconTag(icon: 'time_history', text: l10n.tripCardArrival(formatArrival(trip.departsAt, trip.arrivesAt))),
                  const SizedBox(height: AppSize.gap16),
                  Wrap(
                    spacing: AppSize.gap12,
                    runSpacing: AppSize.gap4,
                    children: [
                      if (trip.seatsTotal > 0)
                        IconTag(
                          icon: 'users_user_rounded',
                          text: l10n.driverTripsSeatsOf(trip.seatsTotal - trip.seatsFree, trip.seatsTotal),
                        ),
                      if (trip.extras.contains(ServiceKind.pets)) IconTag(icon: 'system_paw', text: l10n.tripCardPets),
                      if (trip.extras.contains(ServiceKind.luggage))
                        IconTag(icon: 'system_bag_smile', text: l10n.tripCardLuggage),
                      if (trip.extras.contains(ServiceKind.childSeat))
                        IconTag(icon: 'system_baby', text: l10n.tripCardChildSeat),
                      if (trip.parcelAllowed)
                        IconTag(
                          icon: 'system_box',
                          text: l10n.tripCardParcels(
                            trip.parcelSizes.map((s) => s.json).join(', '),
                            trip.parcelSeatsTotal - trip.parcelSeatsFree,
                            trip.parcelSeatsTotal,
                          ),
                        ),
                    ],
                  ),
                  if (responses > 0) ...[
                    const SizedBox(height: AppSize.gap12),
                    _Responses(responders: trip.responders, total: responses),
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
                          child: IconTag(
                            icon: 'time_calendar',
                            text: tripRange(l10n, trip.departsAt, trip.arrivesAt),
                          ),
                        ),
                        const SizedBox(width: AppSize.gap8),
                        Text(
                          l10n.commonPrice(trip.price),
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

/// Стопка аватаров откликнувшихся, кружок «+N» (N = отклики − показанные) и «N отклика».
class _Responses extends StatelessWidget {
  const _Responses({required this.responders, required this.total});

  final List<Responder> responders;
  final int total;

  // Фото и наложение в кадре (`Component 4`): 28 и −12; в шкале размеров этих ступеней нет.
  static const _photo = 28.0;
  static const _step = 16.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final more = total - responders.length;
    final circles = responders.length + (more > 0 ? 1 : 0);
    return Row(
      children: [
        if (circles > 0)
          SizedBox(
            width: _photo + _step * (circles - 1),
            height: _photo,
            child: Stack(
              children: [
                for (var i = 0; i < responders.length; i++)
                  Positioned(
                    left: _step * i,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bgSurface, width: AppSize.stroke1),
                      ),
                      child: Avatar(url: responders[i].photoUrl, size: _photo),
                    ),
                  ),
                if (more > 0)
                  Positioned(
                    left: _step * responders.length,
                    child: Container(
                      width: _photo,
                      height: _photo,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bgSurface, width: AppSize.stroke1),
                      ),
                      child: Text('+$more', style: AppType.body2.copyWith(color: AppColors.textPrimary)),
                    ),
                  ),
              ],
            ),
          ),
        if (circles > 0) const SizedBox(width: AppSize.gap4),
        Text(l10n.driverTripsResponses(total), style: AppType.body2.copyWith(color: AppColors.textPrimary)),
      ],
    );
  }
}
