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
import '../../booking/cancel/cancel_flow.dart';
import '../../booking/data/booking_repository.dart';
import '../../booking/new/booking_form_screen.dart';
import '../../booking/new/booking_new_args.dart';
import '../data/search_repository.dart';
import 'route_block.dart';

/// Детали поездки («Детали поездки - Места есть» развёрнуто, «Детали поездки - Мест нет» свёрнуто, «Детали поездки - Мест нет» «Мест нет»; «Детали поездки - Бронь есть» — своя бронь).
/// Состояние берётся из флагов ответа `GET /trips/{id}`, правил на клиенте нет.
class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  SearchRepository? _repo;
  Future<TripDetails>? _trip;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repo != null) return;
    _repo = SearchRepository(AppSession.of(context).api);
    _load();
  }

  void _load() {
    final next = _repo!.trip(widget.tripId);
    setState(() {
      _trip = next;
    });
  }

  /// Форма брони закрывается результатом: «Заявка отправлена» или ошибка оплаты.
  Future<void> _book(BookingFormMode mode) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await showBookingSheet(context, BookingNewArgs(tripId: widget.tripId, mode: mode));
    if (!mounted) return;
    _load();
    if (result is BookingOutcome) {
      final text = result.payFailed
          ? bookingErrorText(l10n, result.payErrorCode)
          : l10n.tripDetailsRequestSent;
      messenger.showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void _chat() => Navigator.of(context)
      .pushNamed(AppRoutes.stub, arguments: AppLocalizations.of(context).systemStubChat);

  /// Отмена своей брони («Детали поездки - Бронь есть»): после неё (или если бронь уже изменилась) поездка перечитывается.
  Future<void> _cancel(Booking booking) async {
    final changed = await runBookingCancel(context, booking.id, booking.status);
    if (changed && mounted) _load();
  }

  /// Стрелка у водителя — профиль водителя (по образцу «Профиль - Профиль пассажира»).
  void _driver(String id) => Navigator.of(context).pushNamed(AppRoutes.searchDriver, arguments: id);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(title: l10n.tripDetailsTitle, onBack: Navigator.of(context).maybePop, bordered: false),
          Expanded(
            child: FutureBuilder<TripDetails>(
              future: _trip,
              builder: (context, snapshot) {
                if (snapshot.hasError) return AppErrorView(onRetry: _load);
                final trip = snapshot.data;
                if (trip == null) return const AppLoading();
                return Column(
                  children: [
                    Expanded(child: _Body(trip: trip, onDriver: () => _driver(trip.driver.id))),
                    _ActionBar(trip: trip, onBook: _book, onChat: _chat, onCancel: _cancel),
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

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSize.pad16, 0, AppSize.pad16, AppSize.pad12),
              child: Text(label!, style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSize.pad16),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppSize.radius12),
            ),
            child: child,
          ),
        ],
      );
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
          Text(text, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
        ],
      );
}

class _Body extends StatefulWidget {
  const _Body({required this.trip, required this.onDriver});

  final TripDetails trip;
  final VoidCallback onDriver;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _pricesOpen = false;

  Widget _tags(AppLocalizations l10n, TripDetails t) {
    final tags = <Widget>[
      if (t.extras.contains(ServiceKind.luggage)) _Tag(icon: 'system_bag_smile', text: l10n.tripCardLuggage),
      if (t.extras.contains(ServiceKind.pets)) _Tag(icon: 'system_paw', text: l10n.tripCardPets),
      if (t.extras.contains(ServiceKind.childSeat)) _Tag(icon: 'system_baby', text: l10n.tripCardChildSeat),
      // Только размеры, как в кадрах «Детали поездки - Мест нет»: счёт «занято из всего» рядом с «Мест свободно» читается
      // наоборот; он — на экранах водителя и брони.
      if (t.parcelAllowed)
        _Tag(icon: 'system_box', text: l10n.passengerTripsParcel(t.parcelSizes.map((s) => s.json).join(', '))),
    ];
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSize.pad12),
      child: Wrap(spacing: AppSize.gap12, runSpacing: AppSize.gap8, children: tags),
    );
  }

  Widget _driver(AppLocalizations l10n, TripDetails t) {
    final driver = t.driver;
    final car = t.car;
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
            Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSize.radius12),
                side: const BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1),
              ),
              child: InkWell(
                key: const Key('details_driver_chat'),
                borderRadius: BorderRadius.circular(AppSize.radius12),
                onTap: widget.onDriver,
                child: const SizedBox(
                  width: AppSize.height38,
                  height: AppSize.height38,
                  child: Center(child: AppIcon('arrows_alt_arrow_right', size: AppSize.icon14)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSize.gap16),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSize.radius12),
          // Рамка фото авто в кадре — 343×150.
          child: AppImage(car.photoUrl, width: double.infinity, height: 150),
        ),
        const SizedBox(height: AppSize.gap16),
        Row(
          children: [
            _Tag(icon: 'system_car', text: '${car.brand} ${car.model}'),
            const SizedBox(width: AppSize.gap8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSize.pad12, vertical: AppSize.pad4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSize.radius4),
                border: Border.all(color: AppColors.textPrimary, width: AppSize.stroke1),
              ),
              child: Text(car.plate, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _prices(AppLocalizations l10n, TripDetails t) {
    String name(int idx) {
      final stop = t.stops.where((s) => s.idx == idx);
      return stop.isEmpty ? '' : stopLabel(stop.first);
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.tripDetailsPrice, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
            Text(l10n.commonPrice(t.price), style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
          ],
        ),
        if (t.prices.isNotEmpty) ...[
          const SizedBox(height: AppSize.gap12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.tripDetailsBetweenStops, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
              ExpandToggle(
                label: l10n.tripDetailsShowPrices,
                expanded: _pricesOpen,
                chipKey: const Key('details_prices_chip'),
                closeKey: const Key('details_prices_collapse'),
                onTap: () => setState(() => _pricesOpen = !_pricesOpen),
              ),
            ],
          ),
          // цены участков выплывают тем же движением, что остановки маршрута.
          ExpandReveal(
            expanded: _pricesOpen,
            child: Column(
              children: [
                for (final p in t.prices)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSize.pad12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${name(p.fromIdx)} - ${name(p.toIdx)}',
                            style: AppType.bodyFootnote.copyWith(color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: AppSize.gap16),
                        Text(
                          l10n.commonPrice(p.price),
                          style: AppType.body2.copyWith(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = widget.trip;
    const gap = SizedBox(height: AppSize.gap20);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSize.pad20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Section(
            label: l10n.tripDetailsRoute,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoadIllustration(art: TripArt.ofTrip(t.kind)),
                const SizedBox(height: AppSize.gap12),
                RouteBlock(stops: t.stops),
              ],
            ),
          ),
          const SizedBox(height: AppSize.gap12),
          _Section(
            label: null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoTileRow(
                  children: [
                    InfoTile(label: l10n.tripDetailsDateTime, value: formatTripDateTime(t.departsAt)),
                    if (t.seatsTotal > 0)
                      InfoTile(label: l10n.tripDetailsSeatsFree, value: l10n.tripDetailsSeatsOf(t.seatsFree, t.seatsTotal)),
                  ],
                ),
                // Прибытие на следующий день — дата и время в пути.
                if (arrivalNextDay(l10n, t.departsAt, t.arrivesAt) case final arrival?) ...[
                  const SizedBox(height: AppSize.gap12),
                  Text(arrival, style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary)),
                ],
                _tags(l10n, t),
              ],
            ),
          ),
          gap,
          _Section(label: l10n.tripDetailsDriver, child: _driver(l10n, t)),
          gap,
          _Section(label: null, child: _prices(l10n, t)),
        ],
      ),
    );
  }
}

/// Закреплённая панель кнопок (В `CTA` кадра нет заливки — Figma её не перенёс, фон `bg.surface`).
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.trip, required this.onBook, required this.onChat, required this.onCancel});

  final TripDetails trip;
  final ValueChanged<BookingFormMode> onBook;
  final VoidCallback onChat;
  final ValueChanged<Booking> onCancel;

  // Зазор ряда кнопок в кадре «Детали поездки - Бронь есть» — 9, ступени в шкале нет.
  static const _rowGap = 9.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final buttons = <Widget>[];
    final mine = trip.myBooking;
    if (mine != null) {
      // «Детали поездки - Бронь есть»: своя бронь — ряд «Отменить бронь» | «Написать водителю» 50/50. «Отменить бронь» видна у
      // брони в работе, пока поездка не закончена.
      final live = trip.effectiveStatus == TripStatus.active || trip.effectiveStatus == TripStatus.intakeClosed;
      final cancellable = live &&
          (mine.status == BookingStatus.requested ||
              mine.status == BookingStatus.awaitingPayment ||
              mine.status == BookingStatus.paid);
      final chat = AppButton(
        key: const Key('details_chat'),
        label: l10n.tripDetailsWrite,
        size: AppButtonSize.medium,
        onPressed: onChat,
      );
      buttons.add(cancellable
          ? Row(
              children: [
                Expanded(
                  child: AppButton(
                    key: const Key('details_cancel'),
                    label: l10n.cancelButton,
                    size: AppButtonSize.medium,
                    kind: AppButtonKind.outline,
                    onPressed: () => onCancel(mine),
                  ),
                ),
                const SizedBox(width: _rowGap),
                Expanded(child: chat),
              ],
            )
          : chat);
    } else {
      if (trip.bookable) {
        buttons.add(AppButton(
          key: const Key('details_book'),
          label: l10n.tripDetailsBook,
          size: AppButtonSize.medium,
          onPressed: () => onBook(BookingFormMode.seat),
        ));
      } else if (trip.seatsTotal > 0 && trip.seatsFree == 0 && !trip.isMine) {
        buttons.add(AppButton(
          key: const Key('details_no_seats'),
          label: l10n.tripDetailsNoSeats,
          size: AppButtonSize.medium,
          kind: AppButtonKind.neutral,
          onPressed: null,
        ));
      }
      if (trip.parcelBookable) {
        buttons.add(AppButton(
          key: const Key('details_parcel'),
          label: l10n.tripDetailsSendParcel,
          size: AppButtonSize.medium,
          kind: AppButtonKind.outline,
          onPressed: () => onBook(BookingFormMode.parcel),
        ));
      }
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Container(
      color: AppColors.bgSurface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSize.pad16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSize.gap8),
                buttons[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
