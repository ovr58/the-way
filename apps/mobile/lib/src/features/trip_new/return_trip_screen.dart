import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_type.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/route_fields.dart';
import 'data/trip_new_repository.dart';
import 'limit_screen.dart';
import 'steps/datetime_step.dart';
import 'steps/publish_dialog.dart';
import 'steps/wizard_scaffold.dart';
import 'trip_created_screen.dart';
import 'trip_new_actions.dart';
import 'wizard_controller.dart';

/// Обратная поездка (`trip_new/return`, «Обратное направление», «Обратное направление - Дата и время выставлены», «Обратное направление»): остановки исходной в обратном порядке,
/// дата и время выезда, время прибытия; `POST /trips/{id}/reverse`.
class ReturnTripScreen extends StatefulWidget {
  const ReturnTripScreen({super.key, required this.tripId, this.repository});

  final String tripId;

  /// Репозиторий для тестов; иначе — на `TheWayApi` сессии.
  final TripNewRepository? repository;

  @override
  State<ReturnTripScreen> createState() => _ReturnTripScreenState();
}

class _ReturnTripScreenState extends State<ReturnTripScreen> {
  late final TripNewRepository _repository = widget.repository ?? tripNewRepositoryOf(context);
  TripDetails? _trip;
  WizardController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final trip = await _repository.trip(widget.tripId);
      if (!mounted) return;
      // Дата и время — заново: поездка «обратно» отправляется позже исходной.
      final c = WizardController.fromTrip(_repository, trip)
        ..date = null
        ..departTime = null
        ..arriveTime = null;
      c.stops.setAll(0, c.stops.reversed.toList());
      setState(() {
        _trip = trip;
        _controller = c;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _publish() async {
    final trip = _trip!;
    final c = _controller!;
    final l10n = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await showPublishDialog(
      context,
      summary: PublishSummary.fromTrip(
        l10n,
        trip,
        date: c.date!,
        departTime: c.departTime!,
        arrival: PublishSummary.arrivalLine(l10n, c.departsAt!, c.arrivesAt!),
      ),
      onConfirm: () async {
        try {
          final created = await _repository.reverse(
            trip.id,
            ReverseInput(departsAt: c.departsAt!, arrivesAt: c.arrivesAt!),
          );
          nav.pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => TripCreatedScreen(trip: created, repository: _repository)),
            leaveTripFlow,
          );
        } catch (e) {
          nav.pop();
          if (apiErrorCode(e) == 'limit_reached') {
            await showLimitDialog(nav, messenger, repository: _repository, carId: trip.car.id, date: c.date!);
          } else if (apiErrorCode(e) != 'blocked') {
            // `blocked` показывает экран блокировки (перехватчик), своей подсказки нет.
            showTripSnack(messenger, tripErrorText(l10n, e));
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = _controller;
    if (c == null) {
      return WizardScaffold(
        title: l10n.tripNewReturnTitle,
        body: [
          SizedBox(
            height: 360,
            child: _failed ? AppErrorView(onRetry: _load) : const AppLoading(),
          ),
        ],
        bottom: AppButton(label: l10n.tripNewPublish, onPressed: null),
      );
    }
    final trip = _trip!;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => WizardScaffold(
        title: l10n.tripNewReturnTitle,
        body: [
          WizardCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.tripNewPriceTotal,
                    style: AppType.bodyFootnote.copyWith(color: AppColors.textPrimary),
                  ),
                ),
                Text(
                  l10n.commonPrice(trip.price),
                  style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          WizardSection(
            title: l10n.tripNewRouteTitle,
            // Точки и пунктир — как в мастере (тема route-dots); поле без правки и без значка: выбора нет.
            child: RouteFields(
              fields: [
                for (var i = 0; i < c.stops.length; i++)
                  PickerField(
                    key: ValueKey('return-stop-$i'),
                    label: i == c.stops.length - 1
                        ? l10n.tripNewDestinationPoint
                        : i > 0
                            ? l10n.tripNewStopPoint
                            : l10n.tripNewBoardingPoint,
                    value: c.stops[i].displayAddress,
                    onTap: () {},
                  ),
              ],
            ),
          ),
          DepartureBlock(controller: c),
          ArrivalBlock(controller: c),
        ],
        bottom: AppButton(
          label: l10n.tripNewPublish,
          onPressed: c.timeComplete ? _publish : null,
        ),
      ),
    );
  }
}
