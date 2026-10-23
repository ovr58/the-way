import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_routes.dart';
import '../../../app/session.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/app_input.dart';
import '../../../widgets/app_loading.dart';
import '../../../widgets/app_radio.dart';
import '../../../widgets/road_illustration.dart';
import '../../../widgets/app_switch.dart';
import '../../search/data/search_repository.dart';
import '../../search/details/route_block.dart';
import '../../search/filter/location_service.dart';
import '../data/booking_repository.dart';
import 'booking_new_args.dart';
import 'parcel_size_sheet.dart';
import 'stop_picker_sheet.dart';

/// Показывает форму брони шторкой поверх деталей поездки («Бронирование» – «Бронирование - С доп услугами») под именем маршрута
/// `booking/new`. Результат — [BookingOutcome] или `null`, если шторку закрыли.
Future<Object?> showBookingSheet(BuildContext context, BookingNewArgs args) =>
    showModalBottomSheet<Object?>(
      context: context,
      routeSettings: RouteSettings(name: AppRoutes.bookingNew, arguments: args),
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.overlayScrim,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: BookingFormScreen(args: args),
      ),
    );

/// Содержимое шторки брони («Бронирование», «Бронирование - С доп услугами» — место; «Бронирование», «Бронирование - С доп услугами» — посылка; «поиск адреса» — поиск адреса). Итог «Итого N ₽»
/// приходит только из `GET /trips/{id}/quote` — запрос при каждом изменении формы, ответ
/// устаревшего запроса отбрасывается.
class BookingFormScreen extends StatefulWidget {
  const BookingFormScreen({super.key, required this.args});

  final BookingNewArgs args;

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  /// Больше стольких вариантов точки — вместо списка радио поле с поиском адреса («поиск адреса»).
  static const _inlineMax = 5;

  // Высота шторки, пока поездка грузится или не загрузилась.
  static const _stateHeight = 240.0;

  SearchRepository? _search;
  BookingRepository? _bookings;
  TripDetails? _trip;
  bool _failed = false;

  int _fromIdx = 0;
  int _toIdx = 0;
  int _seats = 1;
  final _extras = <ServiceKind>{};
  ParcelSize _parcel = ParcelSize.none;
  bool _parcelOnly = false;
  final _comment = TextEditingController();

  int? _total;
  int _quoteSeq = 0;
  bool _submitting = false;
  String? _error;

  bool get _isParcel => widget.args.mode == BookingFormMode.parcel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_search != null) return;
    final api = AppSession.of(context).api;
    _search = SearchRepository(api);
    _bookings = BookingRepository(api);
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final trip = await _search!.trip(widget.args.tripId);
      if (!mounted) return;
      final last = trip.stops.length - 1;
      setState(() {
        _trip = trip;
        _fromIdx = widget.args.fromIdx ?? 0;
        // Посылка: всегда на весь маршрут, точек нет.
        _toIdx = widget.args.toIdx ?? last;
        if (_isParcel) {
          _fromIdx = 0;
          _toIdx = last;
          _parcelOnly = trip.seatsFree == 0 && trip.parcelOnlyAllowed;
        }
      });
      _refreshQuote();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  int get _seatsParam => _isParcel ? (_parcelOnly ? 0 : 1) : _seats;

  Future<void> _refreshQuote() async {
    final trip = _trip;
    if (trip == null) return;
    if (_isParcel && _parcel == ParcelSize.none) {
      setState(() => _total = null);
      return;
    }
    final seq = ++_quoteSeq;
    try {
      final quote = await _bookings!.quote(
        trip.id,
        fromIdx: _fromIdx,
        toIdx: _toIdx,
        seats: _seatsParam,
        parcelSize: _parcel,
        extras: _extras.toList(),
      );
      if (!mounted || seq != _quoteSeq) return;
      setState(() => _total = quote.priceTotal);
    } catch (_) {
      if (!mounted || seq != _quoteSeq) return;
      setState(() => _total = null);
    }
  }

  void _change(VoidCallback change) {
    setState(() {
      _error = null;
      change();
    });
    _refreshQuote();
  }

  // ---- точки посадки и высадки: любые по порядку маршрута — цена есть у каждого отрезка ----

  List<Stop> _pickupOptions(TripDetails t) => t.stops.where((s) => s.idx < _toIdx).toList();

  List<Stop> _dropoffOptions(TripDetails t) => t.stops.where((s) => s.idx > _fromIdx).toList();

  Future<void> _submit() async {
    final trip = _trip!;
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    final Booking booking;
    try {
      final comment = _comment.text.trim();
      booking = await _bookings!.create(
        trip.id,
        BookingInput(
          fromIdx: _fromIdx,
          toIdx: _toIdx,
          seats: _seatsParam,
          parcelSize: _parcel,
          parcelOnly: _isParcel && _parcelOnly,
          parcelComment: _isParcel && comment.isNotEmpty ? comment : null,
          extras: _extras.toList(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Шторка закрывает снэкбар деталей — ошибка показывается в ней самой.
      setState(() {
        _submitting = false;
        // Отказ `blocked` показывает экран блокировки (перехватчик), своего текста у шторки нет.
        final code = apiErrorCode(e);
        _error = code == 'blocked' ? null : bookingErrorText(l10n, code);
      });
      return;
    }
    if (booking.status != BookingStatus.awaitingPayment) {
      // Стандартное бронирование: заявка ждёт ответа водителя.
      navigator.pop(const BookingOutcome.requested());
      return;
    }
    // Быстрое бронирование: тем же нажатием оплата → «Заказ - Оплата прошла».
    try {
      await _bookings!.pay(booking.id);
      navigator.pushReplacementNamed(AppRoutes.bookingPaid, arguments: booking.id);
    } catch (e) {
      navigator.pop(BookingOutcome.payFailed(apiErrorCode(e)));
    }
  }

  // ---- вёрстка ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trip = _trip;
    final Widget body;
    if (_failed) {
      body = SizedBox(height: _stateHeight, child: AppErrorView(onRetry: _load));
    } else if (trip == null) {
      body = const SizedBox(height: _stateHeight, child: AppLoading());
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(child: _isParcel ? _parcelForm(l10n, trip) : _seatForm(l10n, trip)),
          ),
          _bottomBar(l10n, trip),
        ],
      );
    }
    return AppBottomSheet(
      title: l10n.bookingTitle,
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
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppSize.radius12),
        ),
        child: child,
      );

  /// Иллюстрация вверху карточки выбора точки («Бронирование»: дорога 284×164; «Бронирование», посылка: коробка), под ней — варианты.
  Widget _roadAnd(Widget points, {TripArt art = TripArt.road}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RoadIllustration(width: 284, height: 164, art: art),
          const SizedBox(height: AppSize.gap12),
          points,
        ],
      );

  Widget _seatForm(AppLocalizations l10n, TripDetails trip) {
    final extras = trip.extrasPriced
        .where((e) => e.kind == ExtraKind.childSeat || e.kind == ExtraKind.luggage || e.kind == ExtraKind.pets)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(l10n.bookingPickup),
        _card(
          child: _roadAnd(
            _points(
              title: l10n.bookingPickup,
              keyPrefix: 'pickup',
              options: _pickupOptions(trip),
              selected: _fromIdx,
              onPick: (idx) => _change(() => _fromIdx = idx),
              // «Ближайшая ко мне» — только у посадки: сесть ближе к себе; высадка — куда еду.
              location: const GeolocatorService(),
            ),
          ),
        ),
        const SizedBox(height: AppSize.gap16),
        _label(l10n.bookingDropoff),
        _card(
          child: _roadAnd(
            _points(
              title: l10n.bookingDropoff,
              keyPrefix: 'dropoff',
              options: _dropoffOptions(trip),
              selected: _toIdx,
              onPick: (idx) => _change(() => _toIdx = idx),
            ),
          ),
        ),
        const SizedBox(height: AppSize.gap16),
        _label(l10n.bookingExtras),
        _card(
          child: Column(
            children: [
              for (final e in extras) _extraRow(l10n, e),
              _passengers(l10n, trip),
            ],
          ),
        ),
      ],
    );
  }

  Widget _points({
    required String title,
    required String keyPrefix,
    required List<Stop> options,
    required int selected,
    required ValueChanged<int> onPick,
    LocationService? location,
  }) {
    if (options.length > _inlineMax) {
      final current = options.where((s) => s.idx == selected);
      return InkWell(
        key: Key('${keyPrefix}_field'),
        onTap: () async {
          final idx = await showStopPicker(context, stops: options, location: location);
          if (idx != null) onPick(idx);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: AppSize.pad12, vertical: AppSize.pad8),
          decoration: BoxDecoration(border: Border.all(color: AppColors.borderDefault, width: AppSize.stroke1)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppType.bodyCaption1.copyWith(color: AppColors.textSecondary)),
              Text(
                current.isEmpty ? '' : stopLabel(current.first),
                style: AppType.body2.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final s in options)
          InkWell(
            key: Key('${keyPrefix}_${s.idx}'),
            onTap: () => onPick(s.idx),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSize.height48),
              child: Row(
                children: [
                  AppRadio(selected: s.idx == selected),
                  const SizedBox(width: AppSize.gap8),
                  Expanded(
                    child: Text(stopLabel(s), style: AppType.body2.copyWith(color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _switchRow({
    required String icon,
    required String title,
    String? hint,
    Widget? price,
    required Widget control,
  }) =>
      Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(vertical: AppSize.pad8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1)),
        ),
        child: Row(
          children: [
            AppIcon(icon, size: AppSize.icon18, color: AppColors.textSecondary),
            const SizedBox(width: AppSize.gap8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.titlesFootnote.copyWith(color: AppColors.textPrimary)),
                  if (hint != null)
                    Text(hint, style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (price != null) ...[price, const SizedBox(width: AppSize.gap8)],
            control,
          ],
        ),
      );

  Widget _extraRow(AppLocalizations l10n, Extra e) {
    final kind = switch (e.kind) {
      ExtraKind.childSeat => ServiceKind.childSeat,
      ExtraKind.luggage => ServiceKind.luggage,
      _ => ServiceKind.pets,
    };
    final (String icon, String title, String hint) = switch (kind) {
      ServiceKind.childSeat => ('system_baby', l10n.bookingExtraChildSeat, l10n.bookingExtraChildSeatHint),
      ServiceKind.luggage => ('system_bag_smile', l10n.bookingExtraLuggage, l10n.bookingExtraLuggageHint),
      _ => ('system_paw', l10n.bookingExtraPets, l10n.bookingExtraPetsHint),
    };
    return _switchRow(
      icon: icon,
      title: title,
      hint: hint,
      price: Text(
        l10n.bookingExtraPrice(e.price),
        style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
      ),
      control: AppSwitch(
        key: Key('extra_${kind.json}'),
        value: _extras.contains(kind),
        onChanged: (on) => _change(() => on ? _extras.add(kind) : _extras.remove(kind)),
      ),
    );
  }

  Widget _stepButton(Key key, IconData icon, VoidCallback? onTap) => Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(AppSize.radius12),
          onTap: onTap,
          child: Container(
            width: AppSize.height40,
            height: AppSize.height40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSize.radius12),
              border: Border.all(color: AppColors.borderDefault, width: AppSize.stroke1),
            ),
            child: Icon(icon, size: AppSize.icon20, color: AppColors.textPrimary),
          ),
        ),
      );

  Widget _passengers(AppLocalizations l10n, TripDetails trip) => SizedBox(
        height: AppSize.height52,
        child: Row(
          children: [
            Expanded(
              child: Text(l10n.bookingPassengers, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
            ),
            _stepButton(
              const Key('seats_minus'),
              Icons.remove,
              _seats > 1 ? () => _change(() => _seats--) : null,
            ),
            SizedBox(
              width: AppSize.height48,
              child: Text(
                '$_seats',
                textAlign: TextAlign.center,
                style: AppType.body2.copyWith(color: AppColors.textPrimary),
              ),
            ),
            _stepButton(
              const Key('seats_plus'),
              Icons.add,
              _seats < trip.seatsFree ? () => _change(() => _seats++) : null,
            ),
          ],
        ),
      );

  // ---- посылка («Бронирование», «Бронирование - С доп услугами») ----------------------------------------------------------------

  List<ParcelOption> _parcelOptions(TripDetails trip) {
    final result = <ParcelOption>[];
    for (final carried in trip.parcelSizes) {
      final (size, kind) = switch (carried) {
        CarriedParcelSize.s => (ParcelSize.s, ExtraKind.parcelS),
        CarriedParcelSize.m => (ParcelSize.m, ExtraKind.parcelM),
        _ => (ParcelSize.l, ExtraKind.parcelL),
      };
      final priced = trip.extrasPriced.where((e) => e.kind == kind);
      if (priced.isNotEmpty) result.add(ParcelOption(size, priced.first.price));
    }
    return result;
  }

  Future<void> _pickParcel(TripDetails trip) async {
    final size = await showParcelSizeSheet(context, options: _parcelOptions(trip), selected: _parcel);
    if (size != null) _change(() => _parcel = size);
  }

  Widget _parcelForm(AppLocalizations l10n, TripDetails trip) {
    final options = _parcelOptions(trip);
    final chosen = options.where((o) => o.size == _parcel);
    final String priceText;
    if (chosen.isNotEmpty) {
      priceText = l10n.bookingExtraPrice(chosen.first.price);
    } else {
      final top = options.isEmpty ? 0 : options.map((o) => o.price).reduce((a, b) => a > b ? a : b);
      priceText = l10n.bookingParcelUpTo(top);
    }
    final counter = '${_comment.text.runes.length}/250';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(l10n.bookingRoute),
        _card(child: _roadAnd(RouteBlock(stops: trip.stops), art: TripArt.box)),
        const SizedBox(height: AppSize.gap16),
        _label(l10n.bookingExtras),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                key: const Key('parcel_row'),
                onTap: () => _pickParcel(trip),
                child: _switchRow(
                  icon: 'system_box',
                  title: l10n.bookingParcel,
                  hint: l10n.bookingParcelHint,
                  control: Text(priceText, style: AppType.body2.copyWith(color: AppColors.accentPrimary)),
                ),
              ),
              const SizedBox(height: AppSize.gap12),
              AppInput(
                key: const Key('parcel_comment'),
                label: l10n.bookingComment,
                controller: _comment,
                maxLength: 250,
                onChanged: (_) => setState(() {}),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSize.pad2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.bookingCommentHint,
                      style: AppType.bodyCaption1.copyWith(color: AppColors.textTertiary),
                    ),
                    Text(counter, style: AppType.bodyCaption1.copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
              if (trip.parcelOnlyAllowed)
                _switchRow(
                  icon: 'users_user_cross',
                  title: l10n.bookingParcelOnly,
                  hint: l10n.bookingParcelOnlyHint,
                  control: AppSwitch(
                    key: const Key('parcel_only_switch'),
                    value: _parcelOnly,
                    // Мест нет — «Без проезда» включён и не выключается.
                    onChanged: trip.seatsFree == 0 ? null : (on) => _change(() => _parcelOnly = on),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bottomBar(AppLocalizations l10n, TripDetails trip) {
    final instant = trip.bookingMode == BookingMode.instant;
    final canSubmit = !_isParcel || _parcel != ParcelSize.none;
    final total = _total;
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
                key: const Key('booking_error'),
                textAlign: TextAlign.center,
                style: AppType.body2.copyWith(color: AppColors.statusError),
              ),
            ),
          if (total != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSize.pad12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.bookingTotal, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
                  Text(
                    l10n.commonPrice(total),
                    key: const Key('booking_total'),
                    style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          AppButton(
            key: const Key('booking_submit'),
            label: instant ? l10n.bookingPay : l10n.bookingSubmit,
            loading: _submitting,
            kind: canSubmit ? AppButtonKind.primary : AppButtonKind.neutral,
            onPressed: canSubmit ? _submit : null,
          ),
        ],
      ),
    );
  }
}
