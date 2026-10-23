import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/app_input.dart';
import '../../../widgets/trip_card_view.dart' show arrivalDayShift, moscowTime;
import '../moscow_time.dart';
import '../wizard_controller.dart';
import 'wizard_scaffold.dart';

/// Поле-выбор (`Input` с нажатием): значение лежит в контроллере, поле только читает. Без [icon] —
/// поле только для чтения без значка (остановки обратной поездки «Обратное направление», «Обратное направление - Дата и время выставлены»).
class PickerField extends StatefulWidget {
  const PickerField({super.key, required this.label, required this.value, this.icon, required this.onTap});

  final String label;
  final String? value;
  final String? icon;
  final VoidCallback onTap;

  @override
  State<PickerField> createState() => _PickerFieldState();
}

class _PickerFieldState extends State<PickerField> {
  late final TextEditingController _text = TextEditingController(text: widget.value ?? '');

  @override
  void didUpdateWidget(PickerField old) {
    super.didUpdateWidget(old);
    final value = widget.value ?? '';
    if (_text.text != value) _text.text = value;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppInput(
        label: widget.label,
        controller: _text,
        onTap: widget.onTap,
        suffix: widget.icon == null ? null : AppIcon(widget.icon!, size: AppSize.icon18, color: AppColors.textSecondary),
      );
}

/// «Дата и время выезда» («Новый заказ - Маршрут», «Новый заказ - Заполнение даты», «Новый заказ - Выбор времени»): дата — не дальше 3 дней вперёд, время — с шагом 30 минут.
class DepartureBlock extends StatelessWidget {
  const DepartureBlock({super.key, required this.controller});

  final WizardController controller;

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDateSheet(
      context,
      current: controller.date,
      today: moscowToday(controller.now()),
      todayHasSlots: hasDepartSlotsOn(moscowToday(controller.now()), controller.now()),
    );
    if (picked != null) controller.setDate(picked);
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimeSheet(
      context,
      title: AppLocalizations.of(context).tripNewPickTime,
      current: controller.departTime,
      stepMinutes: timeStepMinutes,
      earliest: controller.date == null ? null : earliestDepartOn(controller.date!, controller.now()),
      latest: controller.date == null ? null : latestDepartOn(controller.date!, controller.now()),
    );
    if (picked != null) controller.setDepartTime(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return WizardSection(
      title: l10n.tripNewDeparture,
      child: Row(
        children: [
          Expanded(
            child: PickerField(
              label: l10n.tripNewDate,
              value: controller.date == null ? null : ruDate(controller.date!),
              icon: 'time_calendar',
              onTap: () => _pickDate(context),
            ),
          ),
          const SizedBox(width: AppSize.gap8),
          Expanded(
            child: PickerField(
              label: l10n.tripNewTime,
              value: controller.departTime == null ? null : ruTime(controller.departTime!),
              icon: 'time_clock_square',
              onTap: () => _pickTime(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Примерное время прибытия» («Новый заказ - Маршрут»): только время; дата прибытия считается.
class ArrivalBlock extends StatelessWidget {
  const ArrivalBlock({super.key, required this.controller});

  final WizardController controller;

  // Шаг минут при выборе времени прибытия: оно примерное.
  static const _step = 5;

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimeSheet(
      context,
      title: AppLocalizations.of(context).tripNewPickTime,
      current: controller.arriveTime,
      stepMinutes: _step,
    );
    if (picked != null) controller.setArriveTime(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final departs = controller.departsAt;
    final arrives = controller.arrivesAt;
    // Прибытие не позже выезда по часам — следующий день: подпись под полем с датой.
    final nextDay = departs != null && arrives != null && arrivalDayShift(departs, arrives) > 0;
    return WizardSection(
      title: l10n.tripNewArrival,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickerField(
            label: l10n.tripNewTime,
            value: controller.arriveTime == null ? null : ruTime(controller.arriveTime!),
            icon: 'time_clock_square',
            onTap: () => _pick(context),
          ),
          if (nextDay) ...[
            const SizedBox(height: AppSize.gap8),
            Text(
              l10n.tripNewArrivalNextDay(DateFormat('d MMMM', 'ru').format(moscowTime(arrives))),
              style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// «Пассажиры» («Новый заказ - Маршрут», «Новый заказ - кол-во пассажиров»): «Количество мест:» с кнопками − и +.
class SeatsBlock extends StatelessWidget {
  const SeatsBlock({super.key, required this.controller});

  final WizardController controller;

  // Ширина счётчика кадра (92); границы мест — у черновика (заказ — до 8, отклик — не меньше мест заказа).
  static const _countWidth = 92.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seats = controller.seatsTotal;
    return WizardSection(
      title: l10n.tripNewPassengers,
      child: Row(
        children: [
          Expanded(
            child: Text(l10n.tripNewSeatsCount, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
          ),
          _StepButton(
            key: const Key('seats_minus'),
            icon: 'essentional_minus_circle',
            // Активный «−» чёрный, как «+» («Новый заказ - кол-во пассажиров» – «Редактирование - Изменения есть»); на нижней границе — бледный («Новый заказ - Маршрут»).
            color: seats > controller.minSeats ? AppColors.textPrimary : AppColors.textSecondary,
            onTap: seats > controller.minSeats ? () => controller.setSeats(seats - 1) : null,
          ),
          SizedBox(
            width: _countWidth,
            child: Text(
              '$seats',
              textAlign: TextAlign.center,
              style: AppType.body2.copyWith(color: AppColors.textPrimary),
            ),
          ),
          _StepButton(
            key: const Key('seats_plus'),
            icon: 'essentional_add_circle',
            color: AppColors.textPrimary,
            onTap: seats < controller.maxSeats ? () => controller.setSeats(seats + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({super.key, required this.icon, required this.color, required this.onTap});

  final String icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSize.radius12),
          side: const BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSize.radius12),
          onTap: onTap,
          child: SizedBox(
            width: AppSize.height40,
            height: AppSize.height40,
            child: Center(child: AppIcon(icon, size: AppSize.icon24, color: color)),
          ),
        ),
      );
}

/// Лист «Выбрать дату» («Новый заказ - Заполнение даты»): сегодня и три следующих дня по Москве. Сегодня слотов времени не
/// осталось ([todayHasSlots] — `false`) — сегодняшний день серый, первый день — завтра.
Future<DateTime?> showDateSheet(
  BuildContext context, {
  DateTime? current,
  String? title,
  DateTime? today,
  bool todayHasSlots = true,
}) {
  final l10n = AppLocalizations.of(context);
  final base = today ?? moscowToday();
  final first = todayHasSlots ? base : DateTime(base.year, base.month, base.day + 1);
  final last = DateTime(base.year, base.month, base.day + maxDaysAhead);
  return AppBottomSheet.show<DateTime>(
    context,
    title: title ?? l10n.tripNewPickDate,
    child: _DateSheet(first: first, last: last, initial: current),
  );
}

class _DateSheet extends StatefulWidget {
  const _DateSheet({required this.first, required this.last, this.initial});

  final DateTime first;
  final DateTime last;
  final DateTime? initial;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _picked = (widget.initial != null &&
          !widget.initial!.isBefore(widget.first) &&
          !widget.initial!.isAfter(widget.last))
      ? widget.initial!
      : widget.first;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppSize.radius12),
          ),
          child: CalendarDatePicker(
            initialDate: _picked,
            firstDate: widget.first,
            lastDate: widget.last,
            onDateChanged: (d) => _picked = d,
          ),
        ),
        const SizedBox(height: AppSize.gap16),
        AppButton(label: l10n.tripNewPickDate, onPressed: () => Navigator.of(context).pop(_picked)),
      ],
    );
  }
}

/// Лист «Выбрать время» («Новый заказ - Выбор времени»): колёса часов и минут; минуты — кратно [stepMinutes]. [earliest] и [latest] —
/// границы окна публикации (сегодня — не раньше «сейчас», крайний день — не позже «сейчас» + 72 ч): значения
/// вне границ серые, колесо возвращается к ближайшему допустимому.
Future<TimeOfDay?> showTimeSheet(
  BuildContext context, {
  required String title,
  TimeOfDay? current,
  required int stepMinutes,
  TimeOfDay? earliest,
  TimeOfDay? latest,
}) =>
    AppBottomSheet.show<TimeOfDay>(
      context,
      title: title,
      child: _TimeSheet(initial: current, stepMinutes: stepMinutes, earliest: earliest, latest: latest),
    );

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.initial, required this.stepMinutes, this.earliest, this.latest});

  final TimeOfDay? initial;
  final int stepMinutes;
  final TimeOfDay? earliest;
  final TimeOfDay? latest;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  // Время по умолчанию в колесе и размеры колеса.
  static const _defaultHour = 8;
  static const _wheelHeight = 180.0;
  static const _itemExtent = 40.0;
  static const _snapBack = Duration(milliseconds: 200);

  late int _hour;
  late int _minuteIndex;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  List<int> get _minutes => [for (var m = 0; m < 60; m += widget.stepMinutes) m];

  // Границы окна в минутах от полуночи.
  int get _lo => widget.earliest == null ? 0 : widget.earliest!.hour * 60 + widget.earliest!.minute;
  int get _hi => widget.latest == null ? 24 * 60 - 1 : widget.latest!.hour * 60 + widget.latest!.minute;

  bool _allowed(int hour, int minute) => hour * 60 + minute >= _lo && hour * 60 + minute <= _hi;

  /// Значение колёс, прижатое к границам окна: (час, индекс минут).
  (int, int) _clamped(int hour, int minuteIndex) {
    final value = (hour * 60 + _minutes[minuteIndex]).clamp(_lo, _hi);
    final i = _minutes.lastIndexWhere((m) => m <= value % 60);
    return (value ~/ 60, i < 0 ? 0 : i);
  }

  @override
  void initState() {
    super.initState();
    final (h, i) = _clamped(
      widget.initial?.hour ?? _defaultHour,
      ((widget.initial?.minute ?? 0) ~/ widget.stepMinutes).clamp(0, _minutes.length - 1),
    );
    _hour = h;
    _minuteIndex = i;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minuteIndex);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  /// Колесо остановилось вне окна — возвращаем к ближайшему допустимому значению.
  bool _snapToLimit(ScrollNotification n) {
    if (n is! ScrollEndNotification) return false;
    final (h, i) = _clamped(_hour, _minuteIndex);
    if (h != _hour) _hourController.animateToItem(h, duration: _snapBack, curve: Curves.easeOut);
    if (i != _minuteIndex) _minuteController.animateToItem(i, duration: _snapBack, curve: Curves.easeOut);
    setState(() {
      _hour = h;
      _minuteIndex = i;
    });
    return false;
  }

  Widget _wheel(
    FixedExtentScrollController controller,
    int count,
    String Function(int) text,
    bool Function(int) allowed,
    ValueChanged<int> onChanged,
  ) {
    return Expanded(
      child: CupertinoPicker(
        itemExtent: _itemExtent,
        scrollController: controller,
        onSelectedItemChanged: (i) => setState(() => onChanged(i)),
        children: [
          for (var i = 0; i < count; i++)
            Center(
              child: Text(
                text(i),
                style: AppType.title3.copyWith(color: allowed(i) ? AppColors.textPrimary : AppColors.textDisabled),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final minutes = _minutes;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: _wheelHeight,
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppSize.radius12),
          ),
          child: NotificationListener<ScrollNotification>(
            onNotification: _snapToLimit,
            child: Row(
              children: [
                _wheel(
                  _hourController,
                  24,
                  (i) => '$i',
                  (i) => minutes.any((m) => _allowed(i, m)),
                  (i) => _hour = i,
                ),
                _wheel(
                  _minuteController,
                  minutes.length,
                  (i) => minutes[i].toString().padLeft(2, '0'),
                  (i) => _allowed(_hour, minutes[i]),
                  (i) => _minuteIndex = i,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSize.gap16),
        AppButton(
          label: l10n.tripNewPickTime,
          onPressed: () {
            final (h, i) = _clamped(_hour, _minuteIndex);
            Navigator.of(context).pop(TimeOfDay(hour: h, minute: minutes[i]));
          },
        ),
      ],
    );
  }
}
