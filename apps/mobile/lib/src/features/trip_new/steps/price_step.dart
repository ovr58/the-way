import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_input.dart';
import '../../../widgets/route_fields.dart';
import '../wizard_controller.dart';
import 'car_step.dart';
import 'wizard_scaffold.dart';

/// Шаг 3 из 6 — цены («Новый заказ - Выбор цены», образец без комиссии «Экран для отключенной монетизации»): «Весь маршрут», «Между
/// остановками» — цена каждого участка соседних точек и «Стоимость посадки». Ошибки правил
/// цен — под полем (`WizardController.fullPriceIssue` и соседи); числа — с пробелами-разрядами.
///
/// [isEdit] — режим правки поездки («Новый заказ - Выбор цены»): заголовок «Изменение стоимости», кнопка
/// «Сохранить» закрывает экран с результатом `true`, шага «Далее» нет; поездку сохраняет вызывающий.
class PriceStep extends StatefulWidget {
  const PriceStep({super.key, required this.controller, this.isEdit = false});

  final WizardController controller;
  final bool isEdit;

  @override
  State<PriceStep> createState() => _PriceStepState();
}

class _PriceStepState extends State<PriceStep> {
  final Map<String, TextEditingController> _texts = {};

  WizardController get _c => widget.controller;

  TextEditingController _text(String key, int? initial) =>
      _texts.putIfAbsent(key, () => TextEditingController(text: initial == null ? '' : groupDigits(initial)));

  @override
  void dispose() {
    for (final t in _texts.values) {
      t.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (widget.isEdit) {
      Navigator.of(context).pop(true);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CarStep(controller: _c)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final last = _c.stops.length - 1;
    String addr(int i) => _c.stops[i].displayAddress;
    // В тексте ошибки — города точек, не полные адреса.
    String city(int i) => _c.stops[i].city;
    String? issue(PriceIssue? i) => switch (i) {
          null => null,
          PriceTooHigh() => l10n.tripNewPriceTooHigh,
          PriceBelowBoarding(:final boarding) => l10n.tripNewPriceBelowBoarding(groupDigits(boarding)),
          FullBelowLeg(:final from, :final to, :final price) =>
            l10n.tripNewPriceFullBelowLeg(city(from), city(to), groupDigits(price)),
          FullAboveSum(:final sum) => l10n.tripNewPriceFullAboveSum(groupDigits(sum)),
          BoardingEmpty() => l10n.tripNewPriceBoardingEmpty,
        };
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => WizardScaffold(
        title: widget.isEdit ? l10n.tripNewPriceEditTitle : null,
        step: widget.isEdit ? null : 3,
        body: [
          // Карточка на месте с начала, «0 ₽» до ввода: не появляется с первой цифрой и не сдвигает экран.
          WizardCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.tripNewPriceTrip,
                      style: AppType.body2.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                  Text(
                    l10n.commonPrice(_c.priceFull ?? 0),
                    style: AppType.titlesHeadline.copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          WizardSection(
            title: l10n.tripNewPriceTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PriceGroup(
                  title: l10n.tripNewPriceWhole,
                  // Значки начала и конца, как у участков.
                  points: const [RoutePoint.start, RoutePoint.end],
                  from: addr(0),
                  to: addr(last),
                  field: _PriceField(
                    key: const ValueKey('price-full'),
                    controller: _text('full', _c.priceFull),
                    label: l10n.tripNewPriceHint,
                    errorText: issue(_c.fullPriceIssue),
                    onChanged: _c.setPriceFull,
                  ),
                ),
                if (_c.pricePairs.isNotEmpty) ...[
                  const SizedBox(height: AppSize.gap16),
                  Text(
                    l10n.tripNewPriceBetween,
                    style: AppType.titlesFootnote.copyWith(color: AppColors.textPrimary),
                  ),
                  for (final pair in _c.pricePairs) ...[
                    const SizedBox(height: AppSize.gap12),
                    _PriceGroup(
                      // Значки как на шаге точек: старт — квадрат, остановка — круг, финиш — пустой квадрат.
                      points: [
                        pair.$1 == 0 ? RoutePoint.start : RoutePoint.stop,
                        pair.$2 == last ? RoutePoint.end : RoutePoint.stop,
                      ],
                      from: addr(pair.$1),
                      to: addr(pair.$2),
                      field: _PriceField(
                        key: ValueKey('price-${pair.$1}-${pair.$2}'),
                        controller: _text('${pair.$1}-${pair.$2}', _c.pairPrice(pair.$1, pair.$2)),
                        label: l10n.tripNewPriceHint,
                        errorText: issue(_c.legPriceIssue(pair.$1)),
                        onChanged: (v) => _c.setPairPrice(pair.$1, pair.$2, v),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: AppSize.gap16),
                _PriceGroup(
                  title: l10n.tripNewPriceBoarding,
                  field: _PriceField(
                    key: const ValueKey('price-boarding'),
                    controller: _text('boarding', _c.priceBoardingMin),
                    label: l10n.tripNewPriceHint,
                    errorText: issue(_c.boardingPriceIssue),
                    onChanged: _c.setPriceBoardingMin,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: AppButton(
          label: widget.isEdit ? l10n.tripNewSave : l10n.tripNewNext,
          onPressed: _c.priceComplete ? _next : null,
        ),
      ),
    );
  }
}

/// Блок цены: заголовок, адреса отрезка (13, прозрачность 0.5) и поле.
class _PriceGroup extends StatelessWidget {
  const _PriceGroup({this.title, this.from, this.to, this.points, required this.field});

  final String? title;
  final String? from;
  final String? to;

  /// Значки маршрута слева от пары адресов (пары «Между остановками»).
  final List<RoutePoint>? points;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    final hint = AppType.bodyFootnote.copyWith(color: AppColors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Text(title!, style: AppType.titlesFootnote.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: AppSize.gap8),
        ],
        if (points != null && from != null && to != null)
          RouteFields(
            points: points,
            fields: [
              for (final a in [from!, to!])
                Padding(
                  padding: const EdgeInsets.only(left: AppSize.gap8),
                  child: Text(a, style: hint, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
          )
        else ...[
          if (from != null) Text(from!, style: hint, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (to != null) Text(to!, style: hint, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        if (from != null || to != null) const SizedBox(height: AppSize.gap8),
        field,
      ],
    );
  }
}

/// «10 000» — разряды неразрывным пробелом, как `commonPrice` (`decimalPattern` русской локали).
String groupDigits(int n) => NumberFormat.decimalPattern('ru').format(n);

/// Ввод цены: только цифры, не больше 7 (сверх 100 000 видна ошибка, а не обрезка), с пробелами-разрядами.
class _GroupedDigitsFormatter extends TextInputFormatter {
  const _GroupedDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 7) digits = digits.substring(0, 7);
    final text = digits.isEmpty ? '' : groupDigits(int.parse(digits));
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Поле целой цены в рублях (суффикс «₽»); пустое поле — `null`; ошибка правила — под полем.
class _PriceField extends StatelessWidget {
  const _PriceField({super.key, required this.controller, required this.label, required this.onChanged, this.errorText});

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => AppInput(
        label: label,
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: const [_GroupedDigitsFormatter()],
        errorText: errorText,
        onChanged: (text) => onChanged(int.tryParse(text.replaceAll(RegExp(r'\D'), ''))),
        suffix: Text('₽', style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary)),
      );
}
