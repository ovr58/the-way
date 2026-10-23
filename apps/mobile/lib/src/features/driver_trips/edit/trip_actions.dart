import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_routes.dart';
import '../../../app/session.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_menu.dart';
import '../../../widgets/confirm_sheet.dart';
import '../../../widgets/app_icon.dart';
import '../../system/temp_blocked_screen.dart';
import '../data/driver_trips_repository.dart';
import '../list/saved_snack_bar.dart';

/// Пункты меню поездки («Редактирование - Пассажиры есть»): «Передать пассажиров» не показывается.
enum TripMenuItem { seats, edit, closeIntake }

/// Код ошибки API из ответа Dio; `null` — не ошибка API.
String? apiErrorCode(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['code'] is String) return data['code'] as String;
  }
  return null;
}

/// Текст ошибки действия по коду ошибки; неизвестный код — общий.
String tripActionErrorText(AppLocalizations l10n, Object error) => switch (apiErrorCode(error)) {
      'invalid_transition' => l10n.driverTripsErrorInvalidTransition,
      'not_found' => l10n.driverTripsErrorNotFound,
      'forbidden' => l10n.driverTripsErrorForbidden,
      _ => l10n.driverTripsActionFailed,
    };

/// Действия над поездкой: места, приём пассажиров, правка, отмена. Каждое после успеха зовёт
/// [onChanged] — экран деталей перечитывает поездку.
class TripActions {
  TripActions({required this.repository, required this.trip, required this.onChanged});

  final DriverTripsRepository repository;
  final TripDetails trip;
  final VoidCallback onChanged;

  /// Меню у кнопки в шапке (`Tool tip` «Редактирование - Пассажиры есть», общий [showAppMenu]): места · правка · завершить приём. Три
  /// пункта всегда; «Завершить приём» неактивен, когда приём уже закрыт (`intake_closed`).
  Future<void> openMenu(BuildContext buttonContext) async {
    final l10n = AppLocalizations.of(buttonContext);
    final picked = await showAppMenu<TripMenuItem>(buttonContext, [
      AppMenuItem(TripMenuItem.seats, 'system_seat', l10n.driverTripsMenuSeats),
      AppMenuItem(TripMenuItem.edit, 'system_pen', l10n.driverTripsMenuEdit),
      AppMenuItem(
        TripMenuItem.closeIntake,
        'users_user_cross',
        l10n.driverTripsMenuClose,
        enabled: trip.effectiveStatus == TripStatus.active,
      ),
    ]);
    if (picked == null || !buttonContext.mounted) return;
    switch (picked) {
      case TripMenuItem.seats:
        await changeSeats(buttonContext);
      case TripMenuItem.edit:
        await edit(buttonContext);
      case TripMenuItem.closeIntake:
        await closeIntake(buttonContext);
    }
  }

  void _failed(BuildContext context, Object error) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(tripActionErrorText(AppLocalizations.of(context), error))));

  /// «Редактировать»: при `editLocked` — окно «Редактирование недоступно» («Редактирование - Пассажиры есть»), иначе мастер правки.
  Future<void> edit(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    if (trip.editLocked) {
      await AppBottomSheet.show<void>(
        context,
        title: l10n.driverTripsEditLockedTitle,
        child: Builder(
          builder: (sheet) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.driverTripsEditLockedBody,
                style: AppType.body2.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSize.gap16),
              AppButton(
                label: l10n.driverTripsEditLockedOk,
                kind: AppButtonKind.outline,
                onPressed: () => Navigator.of(sheet).pop(),
              ),
              const SizedBox(height: AppSize.gap8),
            ],
          ),
        ),
      );
      return;
    }
    // Мастер правки сам уходит на детали и показывает «Изменения сохранены» (U3): результата не ждём.
    unawaited(Navigator.of(context).pushNamed(AppRoutes.tripNewEdit, arguments: trip.id));
  }

  /// «Изменить количество мест» («Редактирование - Изменение кол-ва мест» – «Редактирование - Нельзя выбрать кол-во мест меньше чем УЖЕ занято»): лист со счётчиком.
  Future<void> changeSeats(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final saved = await AppBottomSheet.show<bool>(
      context,
      title: l10n.driverTripsSeatsTitle,
      child: SeatsSheetBody(repository: repository, trip: trip),
    );
    if (saved == true) {
      onChanged();
      if (context.mounted) showSavedSnackBar(context);
    }
  }

  /// «Завершить приём пассажиров»: `POST /close-intake`.
  Future<void> closeIntake(BuildContext context) async {
    try {
      await repository.closeIntake(trip.id);
      onChanged();
    } catch (e) {
      if (context.mounted) _failed(context, e);
    }
  }

  /// «Отменить поездку»: окно по образцу «Новый заказ - Выбор доп услуг» с текстом по `cancel-preview`, затем `POST /cancel`.
  /// Есть присоединившиеся пассажиры (`editLocked`, считает сервер): тогда в тексте число отмен за 30 дней.
  Future<void> cancel(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final CancelPreview preview;
    try {
      preview = await repository.cancelPreview(trip.id);
    } catch (e) {
      if (context.mounted) _failed(context, e);
      return;
    }
    if (!context.mounted) return;
    await showConfirmSheet(
      context,
      title: l10n.driverTripsCancelTitle,
      body: trip.editLocked
          ? l10n.driverTripsCancelBodyPassengers(preview.cancellationsLast30)
          : l10n.driverTripsCancelBodyPlain,
      confirmLabel: l10n.driverTripsCancelAction,
      backLabel: l10n.driverTripsCancelKeep,
      onConfirm: () async {
        try {
          final result = await repository.cancel(trip.id);
          onChanged();
          // Отмена дала блокировку (две за 30 дней): экран «Бронь отменена» поверх деталей.
          if (result.blockedUntil != null && context.mounted) {
            Navigator.of(context).push(TempBlockedScreen.route(TempBlockedRole.driver));
          }
        } catch (e) {
          if (context.mounted) _failed(context, e);
        }
      },
    );
  }
}

/// «⋯» в шапке экранов водителя вне деталей («Редактирование - Пассажиры есть» заявки, «Отлик» отклик): то же меню поездки
/// [TripActions.openMenu]; после действия зовёт [onChanged] — экран перечитывает поездку.
class TripMenuButton extends StatelessWidget {
  const TripMenuButton({super.key, required this.trip, required this.onChanged});

  final TripDetails trip;
  final VoidCallback onChanged;

  /// Меню есть, пока поездка действует (приём открыт или закрыт).
  static bool shownFor(TripDetails trip) =>
      trip.effectiveStatus == TripStatus.active || trip.effectiveStatus == TripStatus.intakeClosed;

  @override
  Widget build(BuildContext context) {
    final actions = TripActions(
      repository: DriverTripsRepository(AppSession.of(context).api),
      trip: trip,
      onChanged: onChanged,
    );
    return Builder(
      builder: (buttonContext) => AppIconButton(
        background: AppColors.bgSurfaceAlt,
        onPressed: () => actions.openMenu(buttonContext),
        child: const AppIcon('system_menu_dots', size: AppSize.icon24),
      ),
    );
  }
}

/// Тело листа «Количество мест»: «−», число, «+» и «Сохранить» (неактивна, пока число не изменено).
/// Ниже занятых мест «−» неактивен и бледный («Редактирование - Нельзя выбрать кол-во мест меньше чем УЖЕ занято»); ответ сервера `seats_below_taken` — запасной: под
/// счётчиком текст ошибки.
class SeatsSheetBody extends StatefulWidget {
  const SeatsSheetBody({super.key, required this.repository, required this.trip});

  final DriverTripsRepository repository;
  final TripDetails trip;

  @override
  State<SeatsSheetBody> createState() => _SeatsSheetBodyState();
}

class _SeatsSheetBodyState extends State<SeatsSheetBody> {
  late int _value = widget.trip.seatsTotal;
  bool _busy = false;
  bool _below = false;

  /// Нижняя граница счётчика — число занятых мест, но не меньше одного.
  late final int _min = (widget.trip.seatsTotal - widget.trip.seatsFree).clamp(1, widget.trip.car.seats);

  void _step(int d) {
    setState(() {
      _value = (_value + d).clamp(_min, widget.trip.car.seats);
      _below = false;
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.repository.setSeats(widget.trip.id, _value);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _below = apiErrorCode(e) == 'seats_below_taken';
      });
      if (!_below) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tripActionErrorText(AppLocalizations.of(context), e))));
      }
    }
  }

  Widget _stepButton(String icon, VoidCallback? onTap, {bool enabled = true}) => Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSize.radius12),
          side: const BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSize.radius12),
          onTap: onTap,
          child: SizedBox(width: AppSize.height40, height: AppSize.height40, child: Center(
            child: AppIcon(icon, size: AppSize.icon24, color: enabled ? AppColors.textPrimary : AppColors.textSecondary),
          ),
        ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final changed = _value != widget.trip.seatsTotal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16, vertical: AppSize.pad12),
          decoration: BoxDecoration(color: AppColors.bgSurface, borderRadius: BorderRadius.circular(AppSize.radius12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.driverTripsSeatsStepper, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
                  Row(
                    children: [
                      _stepButton(
                        'essentional_minus_circle',
                        _busy || _value <= _min ? null : () => _step(-1),
                        enabled: _value > _min,
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          '$_value',
                          textAlign: TextAlign.center,
                          style: AppType.body2.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                      _stepButton('essentional_add_circle', _busy ? null : () => _step(1)),
                    ],
                  ),
                ],
              ),
              if (_below)
                Padding(
                  padding: const EdgeInsets.only(top: AppSize.pad4),
                  child: Text(
                    l10n.driverTripsSeatsBelowTaken,
                    style: AppType.bodyCaption1.copyWith(color: AppColors.statusError),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSize.gap16),
        AppButton(
          label: l10n.driverTripsSeatsSave,
          kind: changed ? AppButtonKind.primary : AppButtonKind.neutral,
          loading: _busy,
          onPressed: changed ? _save : null,
        ),
        const SizedBox(height: AppSize.gap8),
      ],
    );
  }
}
