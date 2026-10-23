import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
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
import '../../../widgets/info_tile.dart';
import '../../../widgets/rating_line.dart';
import '../../../widgets/road_illustration.dart';
import '../../../widgets/trip_card_view.dart';
import '../../auth/data/phone_format.dart';
import '../../booking/cancel/cancel_flow.dart';
import '../../booking/data/booking_changes.dart';
import '../data/passenger_trips_repository.dart';
import '../../search/details/route_block.dart';

/// Детали брони пассажира («Детали поездки - Бронь есть» – «Детали поездки - Скролл», «Экран поездки после оплаты»): маршрут, время и места, водитель с авто, цены и нижняя
/// панель кнопок: «Отменить бронь» — окно отмены (`runBookingCancel`), «Оплатить» — оплата брони.
class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({super.key, required this.bookingId, this.repository});

  final String bookingId;
  final PassengerTripsRepository? repository;

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  late PassengerTripsRepository _repo;
  late Future<BookingDetailsData> _future;
  bool _started = false;
  bool _paying = false;

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

  /// Оплата или отмена во всплывающем окне («Пришёл ответ») — в том числе поверх деталей — перечитать бронь.
  void _onBookingsChanged() {
    if (mounted) _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _repo = widget.repository ?? PassengerTripsRepository(AppSession.of(context).api);
      _future = _repo.details(widget.bookingId);
    }
  }

  void _reload() => setState(() {
        _future = _repo.details(widget.bookingId);
      });

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      await _repo.pay(widget.bookingId);
      if (!mounted) return;
      await Navigator.of(context).pushNamed(AppRoutes.bookingPaid, arguments: widget.bookingId);
      if (mounted) _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_payErrorText(AppLocalizations.of(context), e))));
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// Отмена брони: после неё (или если бронь уже изменилась) бронь перечитывается — через
  /// [bookingChanges], его сообщает `runBookingCancel`.
  Future<void> _cancel(Booking booking) => runBookingCancel(context, booking.id, booking.status);

  /// Текст ошибки оплаты по коду ошибки; неизвестный код — общий.
  String _payErrorText(AppLocalizations l10n, Object error) {
    String? code;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['code'] is String) code = data['code'] as String;
    }
    return switch (code) {
      'invalid_transition' => l10n.passengerTripsErrorInvalidTransition,
      'trip_unavailable' => l10n.passengerTripsErrorTripUnavailable,
      'not_found' => l10n.passengerTripsErrorNotFound,
      'forbidden' => l10n.passengerTripsErrorForbidden,
      _ => l10n.passengerTripsPayFailed,
    };
  }

  void _openChat() => Navigator.of(context).pushNamed(
        AppRoutes.stub,
        arguments: AppLocalizations.of(context).systemStubChat,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(title: l10n.passengerTripsDetailsTitle, onBack: () => Navigator.of(context).maybePop(), bordered: false),
          Expanded(
            child: FutureBuilder<BookingDetailsData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return AppErrorView(onRetry: _reload);
                if (!snapshot.hasData) return const AppLoading();
                final data = snapshot.data!;
                final booking = data.booking;
                final live = booking.trip.effectiveStatus == TripStatus.active ||
                    booking.trip.effectiveStatus == TripStatus.intakeClosed;
                final canPay = booking.status == BookingStatus.awaitingPayment && live;
                final canWrite = live &&
                    (booking.status == BookingStatus.requested ||
                        booking.status == BookingStatus.awaitingPayment ||
                        booking.status == BookingStatus.paid);
                return Column(
                  children: [
                    Expanded(child: _Body(data: data)),
                    if (canPay || canWrite)
                      _ActionBar(
                        rows: [
                          [
                            // «Детали поездки - Бронь есть», «Экран поездки после оплаты»: «Отменить бронь» слева; у брони, ждущей оплаты, слева «Оплатить» (строка 41
                            // реестра отходов), а «Отменить бронь» уходит под ряд во всю ширину.
                            if (canPay)
                              AppButton(
                                key: const Key('booking_pay'),
                                label: l10n.passengerTripsPay,
                                size: AppButtonSize.medium,
                                loading: _paying,
                                onPressed: _pay,
                              )
                            else if (canWrite)
                              AppButton(
                                key: const Key('booking_cancel'),
                                label: l10n.cancelButton,
                                size: AppButtonSize.medium,
                                kind: AppButtonKind.dangerOutline,
                                onPressed: () => _cancel(booking),
                              ),
                            if (canWrite)
                              AppButton(
                                key: const Key('booking_write'),
                                label: l10n.passengerTripsMessageDriver,
                                size: AppButtonSize.medium,
                                kind: canPay ? AppButtonKind.neutral : AppButtonKind.primary,
                                onPressed: _openChat,
                              ),
                          ],
                          if (canPay)
                            [
                              AppButton(
                                key: const Key('booking_cancel'),
                                label: l10n.cancelButton,
                                size: AppButtonSize.medium,
                                kind: AppButtonKind.dangerOutline,
                                onPressed: () => _cancel(booking),
                              ),
                            ],
                        ],
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

/// Закреплённая нижняя панель кнопок (`CTA`): фон `bg.surface`, безопасная зона снизу. Строка — ряд
/// кнопок поровну (зазор кадра 9, ступени в шкале нет); строки друг под другом через 8.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.rows});

  final List<List<Widget>> rows;

  static const _rowGap = 9.0;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.bgSurface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSize.pad16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var r = 0; r < rows.length; r++) ...[
                  if (r > 0) const SizedBox(height: AppSize.gap8),
                  Row(
                    children: [
                      for (var i = 0; i < rows[r].length; i++) ...[
                        if (i > 0) const SizedBox(width: _rowGap),
                        Expanded(child: rows[r][i]),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.data});

  final BookingDetailsData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final booking = data.booking;
    final trip = data.trip;
    // Белые блоки — во всю ширину экрана, как в кадре «Детали поездки - Скролл» (поля 16 внутри блока); заголовки — с полем 16.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSize.pad16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(l10n.passengerTripsRouteTitle),
          const SizedBox(height: AppSize.gap12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoadIllustration(art: TripArt.ofBooking(booking)),
                const SizedBox(height: AppSize.gap12),
                RouteBlock(stops: trip.stops),
              ],
            ),
          ),
          const SizedBox(height: AppSize.gap12),
          _Card(child: _TripFacts(trip: trip)),
          const SizedBox(height: AppSize.gap20),
          _SectionTitle(l10n.passengerTripsDriverTitle),
          const SizedBox(height: AppSize.gap12),
          _Card(child: _DriverBlock(driver: trip.driver, car: trip.car)),
          const SizedBox(height: AppSize.gap20),
          _Card(child: _Prices(booking: booking, trip: trip)),
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

/// Дата и время, места, бейджи услуг и посылки поездки.
class _TripFacts extends StatelessWidget {
  const _TripFacts({required this.trip});

  final TripDetails trip;

  Widget _badge(String icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: AppSize.icon14, color: AppColors.textSecondary),
          const SizedBox(width: AppSize.gap4),
          Text(text, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
        ],
      );

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
            InfoTile(label: l10n.passengerTripsDepartureLabel, value: formatTripDateTime(trip.departsAt)),
            InfoTile(
              label: l10n.passengerTripsSeatsLabel,
              // «Мест свободно N из M» — свободно в поездке, как в ленте и деталях поездки (принятое решение
              // 2026-10-22; в кадрах «Экран поездки после оплаты», «Детали поездки - Бронь есть» – «Детали поездки - Скролл» — «Мест для пассажиров», занято).
              value: l10n.passengerTripsSeatsOf(trip.seatsFree, trip.seatsTotal),
            ),
          ],
        ),
        // Прибытие на следующий день — дата и время в пути.
        if (arrivalNextDay(l10n, trip.departsAt, trip.arrivesAt) case final arrival?) ...[
          const SizedBox(height: AppSize.gap12),
          Text(arrival, style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary)),
        ],
        const SizedBox(height: AppSize.gap12),
        Wrap(
          spacing: AppSize.gap12,
          runSpacing: AppSize.gap4,
          children: [
            if (trip.extras.contains(ServiceKind.luggage)) _badge('system_bag_smile', l10n.tripCardLuggage),
            if (trip.extras.contains(ServiceKind.pets)) _badge('system_paw', l10n.tripCardPets),
            if (trip.extras.contains(ServiceKind.childSeat)) _badge('system_baby', l10n.tripCardChildSeat),
          ],
        ),
        if (trip.parcelAllowed) ...[
          const SizedBox(height: AppSize.gap12),
          Row(
            children: [
              _badge('system_box', l10n.passengerTripsWithParcel),
              _dot(),
              Text(
                trip.parcelSizes.map((s) => s.json).join(', '),
                style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
              ),
              _dot(),
              Text(
                l10n.passengerTripsSeatsOf(trip.parcelSeatsFree, trip.parcelSeatsTotal),
                style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Водитель с рейтингом, телефоном (после принятия заявки), фото и данными авто.
class _DriverBlock extends StatelessWidget {
  const _DriverBlock({required this.driver, required this.car});

  final UserBrief driver;
  final Car car;

  // Размер фото авто в кадре — 150 по высоте; в шкале размеров его нет.
  static const _carPhotoHeight = 150.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phone = driver.phone;
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
            // Стрелка к профилю водителя (по образцу «Профиль - Профиль пассажира»).
            Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSize.radius12),
                side: const BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSize.radius12),
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.searchDriver, arguments: driver.id),
                child: const SizedBox(
                  width: AppSize.height38,
                  height: AppSize.height38,
                  child: Center(child: AppIcon('arrows_alt_arrow_right', size: AppSize.icon14)),
                ),
              ),
            ),
          ],
        ),
        if (phone != null) ...[
          const SizedBox(height: AppSize.gap16),
          InfoTile(label: l10n.passengerTripsPhoneLabel, value: formatPhone(phone)),
        ],
        const SizedBox(height: AppSize.gap16),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSize.radius8),
          child: AppImage(car.photoUrl, width: double.infinity, height: _carPhotoHeight),
        ),
        const SizedBox(height: AppSize.gap16),
        Row(
          children: [
            AppIcon(car.kind == VehicleKind.bus ? 'system_bus' : 'system_car', size: AppSize.icon16),
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

/// Нижний блок цен: «Стоимость поездки» — `trip.price`, «Между остановками» —
/// `Booking.segmentPrice`; у посылки — ещё стоимость перевозки (второй строкой, «Детали поездки - Скролл»). Последней — «Ваша бронь:
/// N мест, услуги» с суммой брони `priceTotal`.
class _Prices extends StatelessWidget {
  const _Prices({required this.booking, required this.trip});

  final Booking booking;
  final TripDetails trip;

  ExtraKind? _parcelKind() => switch (booking.parcelSize) {
        ParcelSize.s => ExtraKind.parcelS,
        ParcelSize.m => ExtraKind.parcelM,
        ParcelSize.l => ExtraKind.parcelL,
        _ => null,
      };

  /// «2 места, багаж, животное» / «посылка S»: что взято в брони.
  String _details(AppLocalizations l10n) => [
        if (booking.seats > 0) l10n.passengerTripsSeats(booking.seats),
        if (booking.parcelSize != ParcelSize.none) l10n.passengerTripsYourParcel(booking.parcelSize.json ?? ''),
        for (final e in booking.extras)
          ?switch (e.kind) {
            ExtraKind.luggage => l10n.passengerTripsYourLuggage,
            ExtraKind.pets => l10n.passengerTripsYourPets,
            ExtraKind.childSeat => l10n.passengerTripsYourChildSeat,
            _ => null,
          },
      ].join(', ');

  Widget _row(BuildContext context, String label, int price) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: AppType.body2.copyWith(color: AppColors.textPrimary))),
        const SizedBox(width: AppSize.gap8),
        Text(l10n.commonPrice(price), style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final parcelKind = _parcelKind();
    final parcelPrice = parcelKind == null
        ? null
        : booking.extras.where((e) => e.kind == parcelKind).map((e) => e.price).firstOrNull;
    // «Детали поездки - Скролл»: поездка → посылка → между остановками, между строками линия `border.default`.
    final rows = [
      _row(context, l10n.passengerTripsTripPrice, trip.price),
      if (parcelPrice != null) _row(context, l10n.passengerTripsParcelPrice, parcelPrice),
      // бронь на весь маршрут (в том числе поездка без остановок) — отрезок совпадает с поездкой, строки нет.
      if (booking.fromIdx != 0 || booking.toIdx != trip.stops.length - 1)
        _row(context, l10n.passengerTripsBetweenStops, booking.segmentPrice),
      _row(context, l10n.passengerTripsYourBooking(_details(l10n)), booking.priceTotal),
    ];
    return Column(
      key: const Key('booking_prices'),
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) ...[
            const SizedBox(height: AppSize.gap12),
            const Divider(height: AppSize.stroke1, thickness: AppSize.stroke1, color: AppColors.borderDefault),
            const SizedBox(height: AppSize.gap12),
          ],
          row,
        ],
      ],
    );
  }
}
