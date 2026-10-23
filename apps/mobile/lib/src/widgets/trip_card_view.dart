import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';
import 'app_icon.dart';
import 'avatar.dart';
import 'rating_line.dart';

/// Время поездки показывается и вводится по Москве, каким бы ни был пояс телефона.
DateTime moscowTime(DateTime t) => t.toUtc().add(const Duration(hours: 3));

/// «15 мая, 09:00».
String formatTripDateTime(DateTime t) => DateFormat('d MMMM, HH:mm', 'ru').format(moscowTime(t));

/// «18:00».
String formatTripTime(DateTime t) => DateFormat('HH:mm', 'ru').format(moscowTime(t));

/// На сколько суток по Москве прибытие позже выезда: 0 — тот же день, 1 — следующий.
int arrivalDayShift(DateTime departs, DateTime arrives) {
  final d = moscowTime(departs);
  final a = moscowTime(arrives);
  return DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(d.year, d.month, d.day)).inDays;
}

/// Время прибытия: «18:00», на следующий день — «07:00 +1».
String formatArrival(DateTime departs, DateTime arrives) {
  final shift = arrivalDayShift(departs, arrives);
  return shift > 0 ? '${formatTripTime(arrives)} +$shift' : formatTripTime(arrives);
}

/// Прибытие в деталях поездки и брони: на следующий день — «Прибытие 16 мая, 07:00 · в пути 23 ч»,
/// в тот же день — `null` (деталям хватает строки выезда, как в кадрах).
String? arrivalNextDay(AppLocalizations l10n, DateTime departs, DateTime arrives) => arrivalDayShift(departs, arrives) > 0
    ? l10n.tripArrivalNextDay(formatTripDateTime(arrives), travelTime(l10n, departs, arrives))
    : null;

/// «в пути 23 ч», «в пути 2 ч 30 мин», «в пути 45 мин».
String travelTime(AppLocalizations l10n, DateTime departs, DateTime arrives) {
  final minutes = arrives.difference(departs).inMinutes;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return l10n.tripTravelMinutes(m);
  return m == 0 ? l10n.tripTravelHours(h) : l10n.tripTravelHoursMinutes(h, m);
}

/// «Город, улица, дом»: город спереди, если адрес с него не начинается; пустой адрес — город.
String withCity(String city, String address) {
  if (city.isEmpty) return address;
  if (address.isEmpty || address == city) return city;
  return address.startsWith('$city,') ? address : '$city, $address';
}

/// Адрес остановки в деталях и окне публикации — «Город, улица, дом».
String stopAddress(Stop s) => withCity(s.cityName, s.address);

/// Адрес остановки на карточке поездки — «Город, улица, дом» из короткого адреса (PN-2); точка-город —
/// полный адрес («Серов, Свердловская область»), если область в нём есть.
String cardAddress(Stop s) {
  final short = withCity(s.cityName, s.shortAddress);
  return short == s.cityName ? stopAddress(s) : short;
}

/// Карточка поездки в ленте («Базовые экраны - Поездки есть», «Базовые экраны - Идёт регистрация пассажиров»). Кнопок брони на ней нет — нажатие [onTap] открывает
/// детали. Плашка «Топ» или «Ближайший» у имени водителя — по `TripCard.badge` от сервера.
class TripCardView extends StatelessWidget {
  const TripCardView({super.key, required this.trip, this.onTap});

  final TripCard trip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final highlighted = trip.registrationOpen && trip.duplicates > 1;
    final parcelSizes = trip.parcelSizes.map((s) => s.json).join(', ');
    return Material(
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.radius12),
        side: highlighted
            ? const BorderSide(color: AppColors.accentPrimary, width: AppSize.stroke1)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSize.radius12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSize.pad16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Driver(trip: trip),
              const SizedBox(height: AppSize.gap12),
              _Way(trip: trip),
              const SizedBox(height: AppSize.gap12),
              _Tag(icon: 'time_history', text: l10n.tripCardArrival(formatArrival(trip.departsAt, trip.arrivesAt))),
              const SizedBox(height: AppSize.gap12),
              Wrap(
                spacing: AppSize.gap12,
                runSpacing: AppSize.gap4,
                children: [
                  if (trip.seatsTotal > 0)
                    _Tag(
                      icon: 'users_user_rounded',
                      text: trip.seatsFree > 0 ? l10n.tripCardSeatsFree(trip.seatsFree) : l10n.tripCardNoSeats,
                    ),
                  if (trip.extras.contains(ServiceKind.pets)) _Tag(icon: 'system_paw', text: l10n.tripCardPets),
                  if (trip.extras.contains(ServiceKind.luggage)) _Tag(icon: 'system_bag_smile', text: l10n.tripCardLuggage),
                  if (trip.extras.contains(ServiceKind.childSeat)) _Tag(icon: 'system_baby', text: l10n.tripCardChildSeat),
                  // Только размеры, как в деталях поездки («Детали поездки - Места есть» «Посылка S, M»): счёта мест на карточке
                  // ленты нет — принятое решение.
                  if (trip.parcelAllowed)
                    _Tag(icon: 'system_box', text: l10n.tripCardParcelSizes(parcelSizes)),
                ],
              ),
              if (highlighted) ...[
                const SizedBox(height: AppSize.gap12),
                Text(
                  l10n.tripCardRegistrationOpen,
                  style: AppType.body2.copyWith(color: AppColors.accentPrimary),
                ),
              ],
              const SizedBox(height: AppSize.gap12),
              _Footer(trip: trip),
            ],
          ),
        ),
      ),
    );
  }
}

class _Driver extends StatelessWidget {
  const _Driver({required this.trip});

  final TripCard trip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final driver = trip.driver;
    final distance = trip.distanceKm;
    final badge = switch (trip.badge) {
      TripBadge.top => _Badge(icon: 'system_star', text: l10n.tripCardBadgeTop),
      TripBadge.nearest => _Badge(icon: 'time_clock_square', text: l10n.tripCardBadgeNearest),
      _ => null,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              Row(
                children: [
                  RatingLine(rating: driver.rating, tripsCount: driver.tripsCount, tripsWithReviews: false),
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
        if (badge != null) ...[const SizedBox(width: AppSize.gap8), badge],
      ],
    );
  }
}

/// Плашка у имени водителя (`order-type` на «Базовые экраны - Поездки есть»): обводка accentPrimary 1, таблетка, значок 14, текст 13/600.
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSize.pad8, vertical: AppSize.pad4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.accentPrimary, width: AppSize.stroke1),
          borderRadius: BorderRadius.circular(AppSize.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: AppSize.icon14),
            const SizedBox(width: AppSize.gap4),
            Text(text, style: AppType.titlesFootnote.copyWith(color: AppColors.textPrimary)),
          ],
        ),
      );
}

/// Маршрут: точка старта, «N остановки» (если есть), точка финиша.
class _Way extends StatelessWidget {
  const _Way({required this.trip});

  final TripCard trip;

  // Значки маршрута в кадре: квадрат 10, круг 6, линия 22 — в шкале размеров этих ступеней нет.
  static const _point = 10.0;
  static const _stopDot = 6.0;
  static const _lineHeight = 22.0;

  String _address(Stop s) => cardAddress(s);

  Widget _line() => SizedBox(
        width: _point,
        height: _lineHeight,
        child: Center(child: Container(width: AppSize.stroke1, color: AppColors.textPrimary)),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = AppType.body2.copyWith(color: AppColors.textPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: _point,
              height: _point,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(AppSize.radius2),
              ),
            ),
            const SizedBox(width: AppSize.gap8),
            Expanded(child: Text(_address(trip.from), maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
          ],
        ),
        _line(),
        if (trip.stopsCount > 0) ...[
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
                l10n.tripCardStops(trip.stopsCount),
                style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          _line(),
        ],
        Row(
          children: [
            Container(
              width: _point,
              height: _point,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.textPrimary, width: AppSize.stroke2),
                borderRadius: BorderRadius.circular(AppSize.radius2),
              ),
            ),
            const SizedBox(width: AppSize.gap8),
            Expanded(child: Text(_address(trip.to), maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
          ],
        ),
      ],
    );
  }
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
          Flexible(child: Text(text, style: AppType.body2.copyWith(color: AppColors.textPrimary))),
        ],
      );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.trip});

  final TripCard trip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSize.pad8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderDefault, width: AppSize.stroke1),
        borderRadius: BorderRadius.circular(AppSize.radius8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Tag(icon: 'time_calendar', text: formatTripDateTime(trip.departsAt)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(l10n.commonPrice(trip.price), style: AppType.title3.copyWith(color: AppColors.textPrimary)),
              const SizedBox(width: AppSize.gap4),
              Text(l10n.tripCardPerPerson, style: AppType.body2.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
