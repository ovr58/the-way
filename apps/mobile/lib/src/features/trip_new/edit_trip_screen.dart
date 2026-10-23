import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_routes.dart';
import '../../theme/app_size.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';
import 'data/trip_new_repository.dart';
import 'steps/datetime_step.dart';
import 'steps/price_step.dart';
import 'steps/publish_dialog.dart' show leaveTripFlow;
import 'steps/route_step.dart';
import 'steps/wizard_scaffold.dart';
import 'trip_new_actions.dart';
import 'wizard_controller.dart';

/// Правка поездки (`trip_new/edit`, «Редактирование - Изменений нет», «Редактирование - Изменения есть», «Редактирование - Изменений нет», «Редактирование - Изменения есть»): маршрут, дата и время, прибытие, места;
/// «Изменить стоимость» → экран цен в режиме правки. «Сохранить» активна, пока есть отличия от
/// исходной поездки; изменились остановки — сначала экран цен для новых пар.
class EditTripScreen extends StatefulWidget {
  const EditTripScreen({super.key, required this.tripId, this.repository});

  final String tripId;

  /// Репозиторий для тестов; иначе — на `TheWayApi` сессии.
  final TripNewRepository? repository;

  @override
  State<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends State<EditTripScreen> {
  late final TripNewRepository _repository = widget.repository ?? tripNewRepositoryOf(context);
  WizardController? _controller;
  TripDetails? _original;
  bool _failed = false;
  bool _saving = false;

  /// Подпись маршрута, для которого водитель уже подтвердил цены пар (экран цен завершён).
  String? _pricesConfirmedFor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final trip = await _repository.trip(widget.tripId);
      if (!mounted) return;
      setState(() {
        _original = trip;
        _controller = WizardController.fromTrip(_repository, trip);
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  bool get _routeChanged =>
      _controller!.routeSignature != _original!.stops.map((s) => WizardStop.fromStop(s).signature).join('>');

  bool _pricesChanged(WizardController c, TripDetails o) {
    if (c.priceFull != o.price || c.priceBoardingMin != o.priceBoardingMin) return true;
    final before = {for (final p in o.prices) '${p.fromIdx}-${p.toIdx}': p.price};
    final after = {for (final p in c.priceList) '${p.fromIdx}-${p.toIdx}': p.price};
    if (before.length != after.length) return true;
    return before.entries.any((e) => after[e.key] != e.value);
  }

  /// Есть что сохранять: маршрут, время, места или цены отличаются от исходных.
  bool _changed(WizardController c, TripDetails o) =>
      _routeChanged ||
      c.departsAt != o.departsAt ||
      c.arrivesAt != o.arrivesAt ||
      c.seatsTotal != o.seatsTotal ||
      _pricesChanged(c, o);

  bool _valid(WizardController c) =>
      c.routeStepComplete && c.priceComplete && c.carId != null;

  Future<void> _editPrices() async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => PriceStep(controller: _controller!, isEdit: true)),
    );
    if (done == true) _pricesConfirmedFor = _controller?.routeSignature;
  }

  Future<void> _save() async {
    final c = _controller!;
    final original = _original!;
    final l10n = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_routeChanged && _pricesConfirmedFor != c.routeSignature) {
      // Цены новых пар вводятся заново при любой смене маршрута: индексы пар сдвинулись.
      final before = Map.of(c.pairPrices);
      c.replacePairPrices(const {});
      final done = await nav.push<bool>(
        MaterialPageRoute<bool>(builder: (_) => PriceStep(controller: c, isEdit: true)),
      );
      if (!mounted) return;
      if (done != true) {
        // Вернулись «назад» без подтверждения: исходные цены остаются.
        c.replacePairPrices(before);
        return;
      }
      _pricesConfirmedFor = c.routeSignature;
    }
    setState(() => _saving = true);
    try {
      await _repository.update(original.id, c.toPatch());
      nav.pushNamedAndRemoveUntil(
        AppRoutes.driverTripsDetails,
        (r) => leaveTripFlow(r) && r.settings.name != AppRoutes.driverTripsDetails,
        arguments: original.id,
      );
      showTripSnack(messenger, l10n.tripNewEditSaved);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      showTripSnack(messenger, tripErrorText(l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = _controller;
    if (c == null) {
      return WizardScaffold(
        title: l10n.tripNewEditTitle,
        body: [SizedBox(height: 360, child: _failed ? AppErrorView(onRetry: _load) : const AppLoading())],
        bottom: AppButton(label: l10n.tripNewSave, onPressed: null),
      );
    }
    final original = _original!;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => WizardScaffold(
        title: l10n.tripNewEditTitle,
        dismissKeyboardOnDrag: false,
        body: [
          RouteBlock(
            controller: c,
            showTemplates: false,
            below: [
              DepartureBlock(controller: c),
              ArrivalBlock(controller: c),
              if (c.kind == TripKind.ride) SeatsBlock(controller: c),
            ],
          ),
        ],
        // Пара кнопок в один ряд, как «Сохранить» + «Далее» кадров «Редактирование - Изменений нет», «Редактирование - Изменения есть» (принятое решение 2026-10-22).
        bottom: Row(
          children: [
            Expanded(
              child: AppButton(
                label: l10n.tripNewEditPrice,
                kind: AppButtonKind.outline,
                size: AppButtonSize.medium,
                onPressed: _editPrices,
              ),
            ),
            const SizedBox(width: AppSize.gap8),
            Expanded(
              child: AppButton(
                label: l10n.tripNewSave,
                size: AppButtonSize.medium,
                loading: _saving,
                onPressed: _valid(c) && _changed(c, original) ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
