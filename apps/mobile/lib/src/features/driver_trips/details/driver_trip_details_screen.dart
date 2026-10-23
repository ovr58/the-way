import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_routes.dart';
import '../../../app/session.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/app_loading.dart';
import '../../../widgets/avatar.dart';
import '../../../widgets/expand_toggle.dart';
import '../../../widgets/info_tile.dart';
import '../../../widgets/rating_line.dart';
import '../../../widgets/road_illustration.dart';
import '../../../widgets/trip_card_view.dart';
import '../data/driver_trips_repository.dart';
import '../edit/trip_actions.dart';
import '../../search/details/route_block.dart';
import '../list/trip_parts.dart';
import 'trip_details_parts.dart';

/// Детали поездки водителя («Детали поездки созданной водителем - Без пассажиров» – «Детали поездки - С пассажирами»). Верх — «Стоимость» = `paidTotal` (сумма оплаченных броней);
/// строки «Комиссия» и «К оплате водителю» не верстаются. «Повторить поездку» скрыта.
class DriverTripDetailsScreen extends StatefulWidget {
  const DriverTripDetailsScreen({super.key, required this.tripId, this.repository});

  final String tripId;
  final DriverTripsRepository? repository;

  @override
  State<DriverTripDetailsScreen> createState() => _DriverTripDetailsScreenState();
}

class _DriverTripDetailsScreenState extends State<DriverTripDetailsScreen> {
  late DriverTripsRepository _repo;
  late Future<DriverTripData> _future;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _repo = widget.repository ?? DriverTripsRepository(AppSession.of(context).api);
      _future = _repo.details(widget.tripId);
    }
  }

  void _reload() => setState(() {
        _future = _repo.details(widget.tripId);
      });

  /// Заголовок «Пассажиры» → список заявок `driver_bookings`; по возврату детали перечитываются.
  Future<void> _openBookings() async {
    await Navigator.of(context).pushNamed(AppRoutes.driverBookings, arguments: widget.tripId);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: FutureBuilder<DriverTripData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final live = data != null &&
              (data.trip.effectiveStatus == TripStatus.active || data.trip.effectiveStatus == TripStatus.intakeClosed);
          final actions = data == null ? null : TripActions(repository: _repo, trip: data.trip, onChanged: _reload);
          return Column(
            children: [
              AppHeader(
                title: l10n.driverTripsDetailsTitle,
                bordered: false,
                onBack: () => Navigator.of(context).maybePop(),
                trailing: live
                    ? Builder(
                        builder: (buttonContext) => AppIconButton(
                          background: AppColors.bgSurfaceAlt,
                          onPressed: () => actions!.openMenu(buttonContext),
                          child: const AppIcon('system_menu_dots', size: AppSize.icon24),
                        ),
                      )
                    : null,
              ),
              Expanded(
                child: snapshot.hasError
                    ? AppErrorView(onRetry: _reload)
                    : data == null
                        ? const AppLoading()
                        : _Body(data: data, onOpenBookings: _openBookings),
              ),
              if (live)
                ColoredBox(
                  color: AppColors.bgScreen,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSize.pad16, AppSize.pad8, AppSize.pad16, AppSize.pad8),
                      child: _CancelButton(
                        label: l10n.driverTripsCancelAction,
                        onPressed: () => actions!.cancel(context),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Красная кнопка «Отменить поездку» («Детали поездки созданной водителем - Без пассажиров», «Детали поездки - С пассажирами»): заливка `status.error`.
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
            height: AppSize.height48,
            alignment: Alignment.center,
            child: Text(label, style: AppType.button1.copyWith(color: AppColors.textOnAccent)),
          ),
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.data, required this.onOpenBookings});

  final DriverTripData data;
  final VoidCallback onOpenBookings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trip = data.trip;
    // Белые блоки — во всю ширину экрана, как в кадре «Поездка завершена» (поля 16 внутри блока); заголовки — с полем 16.
    Widget side(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16), child: child);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSize.pad16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          side(SectionTitle(l10n.driverTripsRouteTitle)),
          const SizedBox(height: AppSize.gap12),
          WhiteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RoadIllustration(height: 290, art: TripArt.ofTrip(trip.kind)),
                const SizedBox(height: AppSize.gap12),
                RouteBlock(stops: trip.stops),
                const SizedBox(height: AppSize.gap12),
                InfoTile(label: l10n.driverTripsPaidLabel, value: l10n.commonPrice(trip.paidTotal ?? 0)),
              ],
            ),
          ),
          const SizedBox(height: AppSize.gap12),
          WhiteCard(child: _Facts(trip: trip)),
          if (data.bookings.isNotEmpty) ...[
            const SizedBox(height: AppSize.gap20),
            side(_PassengersHeader(onTap: onOpenBookings)),
            WhiteCard(child: _Passengers(bookings: data.bookings)),
          ],
          const SizedBox(height: AppSize.gap20),
          side(SectionTitle(l10n.driverTripsDriverTitle)),
          const SizedBox(height: AppSize.gap12),
          WhiteCard(
            child: _DriverAndCar(
              trip: trip,
              tall: data.bookings.isNotEmpty,
              onOpenProfile: () => Navigator.of(context).pushNamed(AppRoutes.profile),
            ),
          ),
          const SizedBox(height: AppSize.gap20),
          WhiteCard(child: _Prices(trip: trip)),
        ],
      ),
    );
  }
}

/// Дата и время, места, прибытие, бейджи услуг и посылки.
class _Facts extends StatelessWidget {
  const _Facts({required this.trip});

  final TripDetails trip;

  Widget _dot() => Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: AppSize.pad8),
        decoration: const BoxDecoration(color: AppColors.textSecondary, shape: BoxShape.circle),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoTileRow(
          children: [
            InfoTile(label: l10n.driverTripsDepartureLabel, value: formatTripDateTime(trip.departsAt)),
            InfoTile(
              label: l10n.driverTripsSeatsLabel,
              value: l10n.driverTripsSeatsOf(trip.seatsTotal - trip.seatsFree, trip.seatsTotal),
            ),
          ],
        ),
        const SizedBox(height: AppSize.gap12),
        IconTag(
          icon: 'time_history',
          text: arrivalNextDay(l10n, trip.departsAt, trip.arrivesAt) ?? l10n.tripCardArrival(formatArrival(trip.departsAt, trip.arrivesAt)),
        ),
        const SizedBox(height: AppSize.gap12),
        Wrap(
          spacing: AppSize.gap12,
          runSpacing: AppSize.gap4,
          children: [
            if (trip.extras.contains(ServiceKind.luggage)) IconTag(icon: 'system_bag_smile', text: l10n.tripCardLuggage),
            if (trip.extras.contains(ServiceKind.pets)) IconTag(icon: 'system_paw', text: l10n.tripCardPets),
            if (trip.extras.contains(ServiceKind.childSeat)) IconTag(icon: 'system_baby', text: l10n.tripCardChildSeat),
          ],
        ),
        if (trip.parcelAllowed) ...[
          const SizedBox(height: AppSize.gap12),
          Row(
            children: [
              IconTag(icon: 'system_box', text: l10n.driverTripsWithParcel),
              _dot(),
              Text(
                trip.parcelSizes.map((s) => s.json).join(', '),
                style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
              ),
              _dot(),
              Text(
                l10n.driverTripsSeatsOf(trip.parcelSeatsTotal - trip.parcelSeatsFree, trip.parcelSeatsTotal),
                style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Заголовок «Пассажиры» («Детали поездки - С пассажирами») со стрелкой: ведёт на список заявок. Стрелки в кадре нет — она
/// показывает, что заголовок нажимается; зона касания 48 в потоке.
class _PassengersHeader extends StatelessWidget {
  const _PassengersHeader({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: SizedBox(
          height: AppSize.height48,
          child: Row(
            children: [
              Expanded(child: SectionTitle(AppLocalizations.of(context).driverTripsPassengersTitle)),
              const AppIcon('arrows_alt_arrow_right', size: AppSize.icon18),
            ],
          ),
        ),
      );
}

/// Пассажиры поездки («Детали поездки - С пассажирами»): строка ведёт на профиль пассажира `driver_bookings/passenger`.
class _Passengers extends StatelessWidget {
  const _Passengers({required this.bookings});

  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < bookings.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSize.gap16),
          InkWell(
            borderRadius: BorderRadius.circular(AppSize.radius8),
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.driverBookingsPassenger,
              arguments: {'userId': bookings[i].passenger.id, 'bookingId': bookings[i].id},
            ),
            child: Row(
              children: [
                Avatar(url: bookings[i].passenger.photoUrl),
                const SizedBox(width: AppSize.gap12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NameAndOrderType(booking: bookings[i]),
                      const SizedBox(height: AppSize.gap4),
                      _RatingAndDistance(booking: bookings[i]),
                    ],
                  ),
                ),
                const SizedBox(width: AppSize.gap8),
                const AppIcon('arrows_alt_arrow_right', size: AppSize.icon18),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Рейтинг пассажира и расстояние его отрезка («3.2 км», `segmentKm`); нет расстояния — только рейтинг.
class _RatingAndDistance extends StatelessWidget {
  const _RatingAndDistance({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final km = booking.segmentKm;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSize.gap8,
      runSpacing: AppSize.gap2,
      children: [
        RatingLine(
          rating: booking.passenger.rating,
          tripsCount: booking.passenger.tripsCount,
          tripsWithReviews: false,
        ),
        if (km != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon('map_map_point', size: AppSize.icon14, color: AppColors.textSecondary),
              const SizedBox(width: AppSize.gap4),
              Text(
                AppLocalizations.of(context).tripCardDistance(km.toStringAsFixed(1)),
                style: AppType.body2.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
      ],
    );
  }
}

/// Первая строка пассажира («Детали поездки - С пассажирами»): имя слева, метка типа заказа справа. Метка занимает не больше
/// трёх четвертей строки и сокращается многоточием; остальное — имя (тоже с многоточием).
class _NameAndOrderType extends StatelessWidget {
  const _NameAndOrderType({required this.booking});

  final Booking booking;

  // Доля строки, которую может занять метка: имени остаётся не меньше четверти.
  static const _labelShare = 0.75;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(
              child: Text(
                booking.passenger.name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: AppSize.gap8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * _labelShare),
              child: _OrderType(booking: booking),
            ),
          ],
        ),
      );
}

/// Тип заказа (`order-type` «Детали поездки - С пассажирами»): «Поездка», «Поездка + посылка S/M/L» или «Посылка S/M/L» (`parcelOnly`, `parcelSize`).
/// Слой в кадрах скрыт, но трасса кадра требует тип заказа: без него посылку не отличить от места.
class _OrderType extends StatelessWidget {
  const _OrderType({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final parcel = booking.parcelOnly;
    final size = booking.parcelSize.json ?? '';
    final text = parcel
        ? l10n.driverTripsOrderParcel(size)
        : booking.parcelSize == ParcelSize.none
            ? l10n.driverTripsOrderTrip
            : l10n.driverTripsOrderTripParcel(size);
    return Container(
      key: ValueKey('order-type-${booking.id}'),
      padding: const EdgeInsets.symmetric(horizontal: AppSize.pad8, vertical: AppSize.pad4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.accentPrimary, width: AppSize.stroke1),
        borderRadius: BorderRadius.circular(AppSize.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(parcel ? 'system_box' : 'system_car', size: AppSize.icon14),
          const SizedBox(width: AppSize.gap4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.titlesFootnote.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Водитель (он сам) и авто с фото; при пассажирах фото выше (кадр «Детали поездки - С пассажирами»). Кнопка со стрелкой справа
/// открывает профиль (как в «Редактирование - Пассажиры есть» — `profile`).
class _DriverAndCar extends StatelessWidget {
  const _DriverAndCar({required this.trip, required this.tall, required this.onOpenProfile});

  final TripDetails trip;
  final bool tall;
  final VoidCallback onOpenProfile;

  // Высота фото авто в кадре: 150 без пассажиров, 236 с пассажирами; в шкале размеров их нет.
  static const _photoHeight = 150.0;
  static const _photoHeightTall = 236.0;

  @override
  Widget build(BuildContext context) {
    final driver = trip.driver;
    final car = trip.car;
    return Column(
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
                  Text(
                    driver.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: AppSize.gap2),
                  RatingLine(rating: driver.rating, tripsCount: driver.tripsCount),
                ],
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(AppSize.radius12),
              onTap: onOpenProfile,
              child: SizedBox(
                width: AppSize.height48,
                height: AppSize.height48,
                child: Center(
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
            ),
          ],
        ),
        const SizedBox(height: AppSize.gap16),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSize.radius8),
          child: AppImage(car.photoUrl, width: double.infinity, height: tall ? _photoHeightTall : _photoHeight),
        ),
        const SizedBox(height: AppSize.gap16),
        Row(
          children: [
            AppIcon(
              car.kind == VehicleKind.bus ? 'system_bus' : 'system_car',
              size: AppSize.icon16,
              color: AppColors.textSecondary,
            ),
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
    );
  }
}

/// Нижний блок цен: «Стоимость поездки» = `price`; «Между остановками» — «Смотреть стоимость»
/// раскрывает список цен отрезков (`prices`), как «Детали поездки - Мест нет».
class _Prices extends StatefulWidget {
  const _Prices({required this.trip});

  final TripDetails trip;

  @override
  State<_Prices> createState() => _PricesState();
}

class _PricesState extends State<_Prices> {
  bool _open = false;

  String _name(int idx) {
    final stops = widget.trip.stops;
    return idx >= 0 && idx < stops.length ? stopText(stops[idx]) : '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trip = widget.trip;
    final label = AppType.body2.copyWith(color: AppColors.textPrimary);
    final value = AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.driverTripsTripPrice, style: label),
            Text(l10n.commonPrice(trip.price), style: value),
          ],
        ),
        if (trip.prices.isNotEmpty) ...[
          const SizedBox(height: AppSize.gap12),
          const Divider(height: AppSize.stroke1, thickness: AppSize.stroke1, color: AppColors.borderDefault),
          const SizedBox(height: AppSize.gap12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // На 320 подпись и «Смотреть стоимость» не помещаются в строку — подпись переносится.
              Expanded(child: Text(l10n.driverTripsBetweenStops, style: label)),
              const SizedBox(width: AppSize.gap8),
              ExpandToggle(
                label: l10n.driverTripsShowPrices,
                expanded: _open,
                // Высота прежней таблетки: строка подписи 11 × 1,18 ≈ 13 и поля 4 + 4.
                height: 21,
                chipKey: const Key('driver_prices_chip'),
                closeKey: const Key('driver_prices_collapse'),
                onTap: () => setState(() => _open = !_open),
              ),
            ],
          ),
          // цены участков выплывают тем же движением, что остановки маршрута.
          ExpandReveal(
            expanded: _open,
            child: Column(
              children: [
                for (final p in trip.prices) ...[
                  const SizedBox(height: AppSize.gap8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${_name(p.fromIdx)} — ${_name(p.toIdx)}',
                          style: AppType.bodyFootnote.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                      Text(l10n.commonPrice(p.price), style: value),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
