import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/session.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/info_tile.dart';
import '../../../widgets/road_illustration.dart';
import '../../driver_trips/edit/trip_actions.dart' show TripMenuButton;
import '../data/driver_bookings_repository.dart';
import '../widgets/blocks.dart';

/// Решение водителя по заявке.
enum BookingAnswer { confirmed, rejected }

/// Отклик одной заявки («Отлик»): маршрут поездки и пассажира, сведения о поездке, пассажир, цена
/// брони и кнопки «Отклонить бронь» / «Подтвердить бронь». Телефона пассажира здесь нет.
/// В шапке «⋯» — то же меню поездки, что в деталях («Отлик»). Закрывается, вернув [BookingAnswer],
/// когда сервер принял решение.
class BookingResponseScreen extends StatefulWidget {
  const BookingResponseScreen({super.key, required this.trip, required this.booking});

  final TripDetails trip;
  final Booking booking;

  @override
  State<BookingResponseScreen> createState() => _BookingResponseScreenState();
}

class _BookingResponseScreenState extends State<BookingResponseScreen> {
  BookingAnswer? _busy;
  late TripDetails _trip = widget.trip;

  /// Действие меню поменяло поездку (места, приём): перечитать её для блока сведений.
  Future<void> _reloadTrip() async {
    try {
      final trip = await DriverBookingsRepository(AppSession.of(context).api).trip(_trip.id);
      if (mounted) setState(() => _trip = trip);
    } catch (_) {
      // Сведения останутся прежними; список заявок перечитается по возврату.
    }
  }

  Future<void> _answer(BookingAnswer answer) async {
    final repo = DriverBookingsRepository(AppSession.of(context).api);
    final id = widget.booking.id;
    setState(() => _busy = answer);
    try {
      if (answer == BookingAnswer.confirmed) {
        await repo.confirm(id);
      } else {
        await repo.reject(id);
      }
      if (mounted) Navigator.of(context).pop(answer);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = null);
      final l10n = AppLocalizations.of(context);
      showErrorSnack(
        context,
        switch (apiErrorCode(error)) {
          'invalid_transition' => l10n.driverBookingsErrorInvalidTransition,
          'no_seats' => l10n.driverBookingsErrorNoSeats,
          _ => l10n.driverBookingsErrorGeneric,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trip = _trip;
    final booking = widget.booking;
    const gap = SizedBox(height: AppSize.gap20);
    const smallGap = SizedBox(height: AppSize.gap12);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(
            title: l10n.driverBookingsTripTitle,
            bordered: false,
            onBack: () => Navigator.of(context).maybePop(),
            trailing: TripMenuButton.shownFor(trip) ? TripMenuButton(trip: trip, onChanged: _reloadTrip) : null,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSize.pad20),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSize.pad8),
                  child: InfoTile(label: l10n.driverBookingsCost, value: l10n.commonPrice(booking.priceTotal)),
                ),
                gap,
                SectionTitle(l10n.driverBookingsTripRoute),
                smallGap,
                RouteCard(stops: trip.stops, art: TripArt.ofTrip(trip.kind)),
                gap,
                SectionTitle(l10n.driverBookingsPassengerRoute),
                smallGap,
                PassengerRouteCard(booking: booking, road: true),
                gap,
                TripInfoCard(trip: trip),
                gap,
                SectionTitle(l10n.driverBookingsPassengers),
                smallGap,
                CardBlock(child: PassengerRow(booking: booking)),
                gap,
                PriceCard(price: booking.priceTotal),
              ],
            ),
          ),
          BottomBar(
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: l10n.driverBookingsReject,
                    kind: AppButtonKind.outline,
                    size: AppButtonSize.medium,
                    loading: _busy == BookingAnswer.rejected,
                    onPressed: _busy == null ? () => _answer(BookingAnswer.rejected) : null,
                  ),
                ),
                const SizedBox(width: AppSize.gap8),
                Expanded(
                  child: AppButton(
                    label: l10n.driverBookingsConfirm,
                    size: AppButtonSize.medium,
                    loading: _busy == BookingAnswer.confirmed,
                    onPressed: _busy == null ? () => _answer(BookingAnswer.confirmed) : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
