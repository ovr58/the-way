import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/avatar.dart';
import '../../../widgets/expand_toggle.dart';
import '../../../widgets/info_tile.dart';
import '../../../widgets/rating_line.dart';
import '../../../widgets/road_illustration.dart';
import '../../../widgets/route_fields.dart';
import '../../../widgets/trip_card_view.dart';
import '../../search/details/route_block.dart';

/// Заголовок блока («Маршрут», «Пассажиры»): 15/600, поля 16.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text, style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
        ),
      );
}

/// Белый блок на всю ширину экрана: поля 16, скругление 12.
class CardBlock extends StatelessWidget {
  const CardBlock({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSize.pad16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppSize.radius12),
        ),
        child: child,
      );
}

/// Тонкий разделитель внутри белого блока.
class BlockDivider extends StatelessWidget {
  const BlockDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(height: AppSize.stroke1, thickness: AppSize.stroke1, color: AppColors.borderDefault);
}

/// Метка с иконкой (значки услуг, места).
class IconTag extends StatelessWidget {
  const IconTag({super.key, required this.icon, required this.text});

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

// Кружок-разделитель в кадре — 6; в шкале размеров этой ступени нет.
const _stopDot = 6.0;

/// Маршрут поездки («Редактирование - Пассажиры есть», «Отлик»): картинка ([art]: дорога, у поездки-посылки — коробка) и общий блок
/// маршрута [RouteBlock].
class RouteCard extends StatelessWidget {
  const RouteCard({super.key, required this.stops, this.art = TripArt.road});

  final List<Stop> stops;
  final TripArt art;

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return const SizedBox.shrink();
    return CardBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RoadIllustration(art: art),
          const SizedBox(height: AppSize.gap12),
          RouteBlock(stops: stops),
        ],
      ),
    );
  }
}

/// Поле «подпись над значением» только для чтения (точки посадки и высадки, комментарий).
class ReadOnlyField extends StatelessWidget {
  const ReadOnlyField({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: AppSize.height52),
        padding: const EdgeInsets.symmetric(horizontal: AppSize.pad12, vertical: AppSize.pad8),
        decoration: BoxDecoration(border: Border.all(color: AppColors.textPrimary, width: AppSize.stroke1)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: AppType.bodyCaption1.copyWith(color: AppColors.textPrimary)),
            Text(value, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
          ],
        ),
      );
}

/// Маршрут пассажира («Отлик», «Профиль пассажира после принятия заявки»): точки посадки и высадки его брони и, если есть, комментарий
/// к посылке.
class PassengerRouteCard extends StatelessWidget {
  const PassengerRouteCard({super.key, required this.booking, this.road = false});

  final Booking booking;

  /// Картинка вверху карточки (293×85; по брони — дорога, коробка или обе): есть в «Отлик», в «Профиль пассажира после принятия заявки» её нет.
  final bool road;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final comment = booking.parcelComment;
    return CardBlock(
      child: Column(
        children: [
          if (road) ...[
            RoadIllustration(height: 85, art: TripArt.ofBooking(booking)),
            const SizedBox(height: AppSize.gap12),
          ],
          // Точки по центрам полей, пунктир, конец залит («Профиль пассажира после принятия заявки», «Отлик»; тема route-dots).
          RouteFields(
            end: RouteEnd.filled,
            fields: [
              ReadOnlyField(label: l10n.driverBookingsPickup, value: stopAddress(booking.from)),
              ReadOnlyField(label: l10n.driverBookingsDropoff, value: stopAddress(booking.to)),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: AppSize.gap8),
            ReadOnlyField(label: l10n.driverBookingsParcelComment, value: comment),
          ],
        ],
      ),
    );
  }
}

/// Блок сведений о поездке («Редактирование - Пассажиры есть», «Отлик»): дата, места, прибытие, услуги, посылки.
class TripInfoCard extends StatelessWidget {
  const TripInfoCard({super.key, required this.trip});

  final TripDetails trip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tags = [
      if (trip.extras.contains(ServiceKind.luggage)) IconTag(icon: 'system_bag_smile', text: l10n.tripCardLuggage),
      if (trip.extras.contains(ServiceKind.pets)) IconTag(icon: 'system_paw', text: l10n.tripCardPets),
      if (trip.extras.contains(ServiceKind.childSeat)) IconTag(icon: 'system_baby', text: l10n.tripCardChildSeat),
    ];
    final dot = Container(
      width: _stopDot,
      height: _stopDot,
      decoration: const BoxDecoration(color: AppColors.textSecondary, shape: BoxShape.circle),
    );
    final bold = AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary);
    return CardBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoTileRow(
            children: [
              InfoTile(label: l10n.driverBookingsDateTime, value: formatTripDateTime(trip.departsAt)),
              InfoTile(
                label: l10n.driverBookingsPassengerSeats,
                value: l10n.driverBookingsSeatsOf(trip.seatsTotal - trip.seatsFree, trip.seatsTotal),
              ),
            ],
          ),
          const SizedBox(height: AppSize.gap12),
          IconTag(icon: 'time_history', text: l10n.tripCardArrival(formatArrival(trip.departsAt, trip.arrivesAt))),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: AppSize.gap12),
            Wrap(spacing: AppSize.gap12, runSpacing: AppSize.gap4, children: tags),
          ],
          if (trip.parcelAllowed) ...[
            const SizedBox(height: AppSize.gap12),
            Wrap(
              spacing: AppSize.gap8,
              runSpacing: AppSize.gap4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconTag(icon: 'system_box', text: l10n.driverBookingsWithParcel),
                dot,
                Text(trip.parcelSizes.map((s) => s.json).join(', '), style: bold),
                dot,
                Text(
                  l10n.driverBookingsSeatsOf(trip.parcelSeatsTotal - trip.parcelSeatsFree, trip.parcelSeatsTotal),
                  style: bold,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Строка пассажира: фото, имя, рейтинг, метки мест и посылки; справа — подпись статуса и стрелка.
class PassengerRow extends StatelessWidget {
  const PassengerRow({super.key, required this.booking, this.statusLabel, this.statusColor, this.onTap});

  final Booking booking;
  final String? statusLabel;
  final Color? statusColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final passenger = booking.passenger;
    final km = booking.segmentKm;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.height48),
        child: Row(
          children: [
            Avatar(url: passenger.photoUrl),
            const SizedBox(width: AppSize.gap12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(passenger.name ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
                      ),
                      if (statusLabel != null)
                        Text(statusLabel!, style: AppType.bodyFootnote.copyWith(color: statusColor)),
                    ],
                  ),
                  const SizedBox(height: AppSize.gap2),
                  Wrap(
                    spacing: AppSize.gap8,
                    runSpacing: AppSize.gap2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      RatingLine(rating: passenger.rating, tripsCount: passenger.tripsCount, tripsWithReviews: false),
                      if (km != null)
                        IconTag(icon: 'map_map_point', text: l10n.tripCardDistance(km.toStringAsFixed(1))),
                      if (booking.seats > 0)
                        IconTag(icon: 'users_user_rounded', text: l10n.driverBookingsSeats(booking.seats)),
                      if (booking.parcelSize != ParcelSize.none)
                        IconTag(
                          icon: 'system_box',
                          text: l10n.driverBookingsParcelSize(booking.parcelSize.json ?? ''),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSize.gap8),
              const AppIcon('arrows_alt_arrow_right', size: AppSize.icon18, color: AppColors.borderStrong),
            ],
          ],
        ),
      ),
    );
  }
}

/// Блок «Водитель» («Редактирование - Пассажиры есть»): водитель, фото и название авто, госномер.
class DriverCard extends StatelessWidget {
  const DriverCard({super.key, required this.trip, this.onOpenProfile});

  final TripDetails trip;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final driver = trip.driver;
    final car = trip.car;
    final photo = car.photoUrl;
    return CardBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(url: driver.photoUrl),
              const SizedBox(width: AppSize.gap12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
                    const SizedBox(height: AppSize.gap2),
                    RatingLine(rating: driver.rating, tripsCount: driver.tripsCount),
                  ],
                ),
              ),
              if (onOpenProfile != null)
                InkWell(
                  borderRadius: BorderRadius.circular(AppSize.radius12),
                  onTap: onOpenProfile,
                  child: Container(
                    width: AppSize.height48,
                    height: AppSize.height48,
                    alignment: Alignment.center,
                    child: Container(
                      width: AppSize.height38,
                      height: AppSize.height38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderDefault, width: AppSize.stroke1),
                        borderRadius: BorderRadius.circular(AppSize.radius12),
                      ),
                      child: const AppIcon('arrows_alt_arrow_right', size: AppSize.icon14),
                    ),
                  ),
                ),
            ],
          ),
          if (photo != null && photo.isNotEmpty) ...[
            const SizedBox(height: AppSize.gap16),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSize.radius8),
              child: AppImage(photo, width: double.infinity, height: _carPhotoHeight),
            ),
          ],
          const SizedBox(height: AppSize.gap16),
          Row(
            children: [
              AppIcon(car.kind == VehicleKind.bus ? 'system_bus' : 'system_car',
                  size: AppSize.icon16, color: AppColors.textSecondary),
              const SizedBox(width: AppSize.gap4),
              Expanded(
                child: Text('${car.brand} ${car.model}', style: AppType.body2.copyWith(color: AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSize.pad12, vertical: AppSize.pad4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.textPrimary, width: AppSize.stroke1),
                  borderRadius: BorderRadius.circular(AppSize.radius4),
                ),
                child: Text(car.plate, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Высота фото авто в кадре — 236; такой ступени в шкале нет.
  static const _carPhotoHeight = 236.0;
}

/// Блок цен поездки: «Стоимость поездки» и, если [prices] не пусты, «Между остановками» с
/// раскрывающимся списком цен отрезков (как «Детали поездки - Мест нет»).
class PriceCard extends StatefulWidget {
  const PriceCard({super.key, required this.price, this.stops = const [], this.prices = const []});

  final int price;
  final List<Stop> stops;
  final List<Price> prices;

  @override
  State<PriceCard> createState() => _PriceCardState();
}

class _PriceCardState extends State<PriceCard> {
  bool _open = false;

  String _name(int idx) {
    for (final s in widget.stops) {
      if (s.idx == idx) return stopAddress(s);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = AppType.body2.copyWith(color: AppColors.textPrimary);
    final value = AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary);
    return CardBlock(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.driverBookingsTripPrice, style: label),
              Text(l10n.commonPrice(widget.price), style: value),
            ],
          ),
          if (widget.prices.isNotEmpty) ...[
            const SizedBox(height: AppSize.gap12),
            const BlockDivider(),
            const SizedBox(height: AppSize.gap12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.driverBookingsBetweenStops, style: label),
                ExpandToggle(
                  label: l10n.driverBookingsShowPrices,
                  expanded: _open,
                  // Высота прежней таблетки: строка подписи 11 × 1,18 ≈ 13 и поля 4 + 4.
                  height: 21,
                  chipKey: const Key('booking_prices_chip'),
                  closeKey: const Key('booking_prices_collapse'),
                  onTap: () => setState(() => _open = !_open),
                ),
              ],
            ),
            // цены участков выплывают тем же движением, что остановки маршрута.
            ExpandReveal(
              expanded: _open,
              child: Column(
                children: [
                  for (final p in widget.prices) ...[
                    const SizedBox(height: AppSize.gap12),
                    const BlockDivider(),
                    const SizedBox(height: AppSize.gap12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('${_name(p.fromIdx)} - ${_name(p.toIdx)}',
                              style: AppType.bodyFootnote.copyWith(color: AppColors.textPrimary)),
                        ),
                        const SizedBox(width: AppSize.gap8),
                        Text(l10n.commonPrice(p.price), style: label),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Нижняя панель кнопок экрана: фон экрана, безопасная зона снизу (CTA кадров).
class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.bgScreen,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSize.pad16, AppSize.pad8, AppSize.pad16, AppSize.pad8),
            child: child,
          ),
        ),
      );
}

/// Зелёный снэкбар успеха («Бронь подтверждена», «Бронь отклонена»): галочка и текст.
void showSuccessSnack(BuildContext context, String text) => _snack(context, text, AppColors.accentPrimary, 'essentional_check_circle');

/// Красный снэкбар ошибки действия.
void showErrorSnack(BuildContext context, String text) => _snack(context, text, AppColors.statusError, 'essentional_danger_circle');

void _snack(BuildContext context, String text, Color color, String icon) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSize.radius12)),
        content: Row(children: [
          AppIcon(icon, size: AppSize.icon20, color: AppColors.textOnAccent),
          const SizedBox(width: AppSize.gap8),
          Expanded(child: Text(text, style: AppType.bodyFootnote.copyWith(color: AppColors.textOnAccent))),
          InkWell(
            onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            child: const Padding(
              padding: EdgeInsets.all(AppSize.pad12),
              child: AppIcon('snackbar_close', size: AppSize.icon14, color: AppColors.textOnAccent),
            ),
          ),
        ]),
      ),
    );
}
