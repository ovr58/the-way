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
import '../../../widgets/app_loading.dart';
import '../data/driver_bookings_repository.dart';

/// События водителя «при открытии».
enum DriverEvent { newResponse, passengerPaid }

/// Окно события водителя поверх затемнения (маршрут прозрачный — `onGenerateAppRoute`): «Пришёл отклик» «Новый отклик» и «Пассажир оплатил» «Пассажир оплатил
/// поездку». Поездка берётся из брони (`GET /bookings/{id}`); кнопка заменяет окно экраном:
/// «Пришёл отклик» → `driver_bookings(tripId)`, «Пассажир оплатил» → `driver_trips/details(tripId)`. Замена, а не новый
/// экран — вызвавший окно ждёт его закрытия и после этого отмечает событие прочитанным.
class DriverEventScreen extends StatefulWidget {
  const DriverEventScreen({super.key, required this.bookingId, required this.event});

  final String bookingId;
  final DriverEvent event;

  @override
  State<DriverEventScreen> createState() => _DriverEventScreenState();
}

class _DriverEventScreenState extends State<DriverEventScreen> {
  // Размеры окна и картинки в кадре: 343 и 90×80 — в шкале размеров таких ступеней нет.
  static const _popupWidth = 343.0;
  static const _imageWidth = 90.0;
  static const _imageHeight = 80.0;
  static const _image = 'assets/images/event_popup.webp';

  Future<Booking>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<Booking> _load() => DriverBookingsRepository(AppSession.of(context).api).booking(widget.bookingId);

  void _go(Booking booking) {
    final route = widget.event == DriverEvent.newResponse ? AppRoutes.driverBookings : AppRoutes.driverTripsDetails;
    Navigator.of(context).pushReplacementNamed(route, arguments: booking.trip.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (title, body, action) = switch (widget.event) {
      DriverEvent.newResponse => (
          l10n.driverBookingsNewResponseTitle,
          l10n.driverBookingsNewResponseBody,
          l10n.driverBookingsNewResponseAction,
        ),
      DriverEvent.passengerPaid => (
          l10n.driverBookingsPassengerPaidTitle,
          l10n.driverBookingsPassengerPaidBody,
          l10n.driverBookingsPassengerPaidAction,
        ),
    };
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<Booking>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Окна нет — обычный экран ошибки на сплошном фоне, а не поверх ленты.
            return ColoredBox(
              color: AppColors.bgScreen,
              child: SafeArea(
                child: AppErrorView(
                  onRetry: () => setState(() {
                    _future = _load();
                  }),
                ),
              ),
            );
          }
          final booking = snapshot.data;
          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: const ColoredBox(color: AppColors.overlayScrim),
              ),
              if (booking == null)
                const AppLoading()
              else
                Center(
                  child: Container(
                    width: _popupWidth,
                    padding: const EdgeInsets.all(AppSize.pad16),
                    decoration: BoxDecoration(
                      color: AppColors.bgScreen,
                      borderRadius: BorderRadius.circular(AppSize.radius12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(_image, width: _imageWidth, height: _imageHeight, fit: BoxFit.cover),
                        const SizedBox(height: AppSize.gap16),
                        Text(title,
                            textAlign: TextAlign.center,
                            style: AppType.title3.copyWith(color: AppColors.textPrimary)),
                        const SizedBox(height: AppSize.gap8),
                        Text(body,
                            textAlign: TextAlign.center,
                            style: AppType.body2.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: AppSize.gap16),
                        AppButton(label: action, size: AppButtonSize.medium, onPressed: () => _go(booking)),
                      ],
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
