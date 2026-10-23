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
import '../../../widgets/avatar.dart';
import '../../../widgets/info_tile.dart';
import '../../../widgets/profile_parts.dart';
import '../../auth/data/phone_format.dart';
import '../data/driver_bookings_repository.dart';
import '../widgets/blocks.dart';

class _Data {
  const _Data(this.user, this.booking);

  final UserBrief user;
  final Booking? booking;
}

/// Профиль пассажира («Профиль пассажира до принятия заявки», «Профиль пассажира после принятия заявки», «Профиль - Профиль пассажира», «Профиль - Профиль пассажира до оплаты»). Что видно, решают данные, а не режим экрана:
/// телефон — если сервер его отдал; «Маршрут пассажира» — если бронь принята
/// (`awaiting_payment`, `paid`); «Написать» — при открытии из брони («Профиль пассажира до принятия заявки», «Профиль пассажира после принятия заявки»), «Написать в
/// чат» — без брони при известном телефоне («Профиль - Профиль пассажира»), без телефона и брони кнопки нет («Профиль - Профиль пассажира до оплаты»).
class PassengerProfileScreen extends StatefulWidget {
  const PassengerProfileScreen({super.key, this.userId, this.bookingId})
      : assert(userId != null || bookingId != null);

  final String? userId;
  final String? bookingId;

  @override
  State<PassengerProfileScreen> createState() => _PassengerProfileScreenState();
}

class _PassengerProfileScreenState extends State<PassengerProfileScreen> {
  DriverBookingsRepository? _repo;
  Future<_Data>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo ??= DriverBookingsRepository(AppSession.of(context).api);
    _future ??= _load();
  }

  Future<_Data> _load() async {
    final repo = _repo!;
    final bookingId = widget.bookingId;
    final booking = bookingId == null ? null : await repo.booking(bookingId);
    final user = await repo.user(widget.userId ?? booking!.passenger.id);
    return _Data(user, booking);
  }

  bool _accepted(Booking? b) =>
      b != null && (b.status == BookingStatus.awaitingPayment || b.status == BookingStatus.paid);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          ProfileHeader(title: l10n.driverBookingsProfileTitle, onBack: () => Navigator.of(context).maybePop()),
          Expanded(
            child: FutureBuilder<_Data>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return AppErrorView(onRetry: () => setState(() {
                    _future = _load();
                  }));
                }
                final data = snapshot.data;
                if (data == null) return const AppLoading();
                return _content(context, l10n, data);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, AppLocalizations l10n, _Data data) {
    final user = data.user;
    final booking = data.booking;
    final phone = user.phone;
    final String? action = booking != null
        ? l10n.driverBookingsWrite
        : (phone != null ? l10n.driverBookingsWriteChat : null);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: AppSize.pad20, bottom: AppSize.pad20),
            children: [
              CardBlock(
                child: Column(
                  children: [
                    Row(children: [
                      Avatar(url: user.photoUrl),
                      const SizedBox(width: AppSize.gap12),
                      Expanded(
                        child: Text(user.name ?? '',
                            style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
                      ),
                    ]),
                    if (phone != null) ...[
                      const SizedBox(height: AppSize.gap12),
                      InfoTile(label: l10n.driverBookingsPhone, value: formatPhone(phone)),
                    ],
                    const SizedBox(height: AppSize.gap12),
                    ProfileRatingBox(user: user),
                  ],
                ),
              ),
              if (_accepted(booking)) ...[
                const SizedBox(height: AppSize.gap20),
                SectionTitle(l10n.driverBookingsPassengerRoute),
                const SizedBox(height: AppSize.gap12),
                PassengerRouteCard(booking: booking!),
              ],
            ],
          ),
        ),
        if (action != null)
          BottomBar(
            child: AppButton(
              label: action,
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.stub, arguments: l10n.systemStubChat),
            ),
          ),
      ],
    );
  }
}
