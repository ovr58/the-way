import 'dart:math' as math;

import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_checkbox.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/app_input.dart';
import '../../../widgets/app_switch.dart';
import '../../../widgets/parcel_size_image.dart';
import '../wizard_controller.dart';
import 'booking_mode_step.dart';
import 'publish_dialog.dart';
import 'wizard_scaffold.dart';

/// Шаг 5 из 6 — услуги и посылка («Новый заказ - Выбор доп услуг», «Новый заказ - Выбор веса посылки»): у каждой включённой услуги — поле цены
/// (по умолчанию 150); «Посылка» открывает лист размеров с ценой каждого и числом мест для
/// посылок. У поездки-посылки (`kind = parcel`) услуг для пассажиров нет — только посылка.
class ExtrasStep extends StatelessWidget {
  const ExtrasStep({super.key, required this.controller});

  final WizardController controller;

  static const _services = [
    (ExtraKind.childSeat, 'system_baby'),
    (ExtraKind.luggage, 'system_bag_smile'),
    (ExtraKind.pets, 'system_paw'),
  ];

  String _serviceName(AppLocalizations l10n, ExtraKind kind) => switch (kind) {
        ExtraKind.childSeat => l10n.tripNewExtraChildSeat,
        ExtraKind.luggage => l10n.tripNewExtraLuggage,
        _ => l10n.tripNewExtraPets,
      };

  Future<void> _openParcel(BuildContext context) async {
    final result = await AppBottomSheet.show<_ParcelResult>(
      context,
      // Шторка водителя — его словами; «Укажите размер вашей посылки» остаётся у отправителя.
      title: AppLocalizations.of(context).tripNewParcelDriverTitle,
      child: _ParcelSheet(
        sizes: {for (final k in parcelKinds) if (controller.extraOn(k)) k: controller.extras[k]!},
        parcelOnly: controller.parcelOnly,
        seats: controller.parcelSeatsTotal,
        showParcelOnly: controller.kind == TripKind.ride,
      ),
    );
    if (result == null) return;
    for (final k in parcelKinds) {
      final price = result.sizes[k];
      if (price == null) {
        controller.setExtra(k, false);
      } else {
        controller.setExtra(k, true);
        controller.setExtraPrice(k, price);
      }
    }
    controller.setParcelSeats(result.seats);
    controller.setParcelOnly(result.parcelOnly);
  }

  void _next(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => BookingModeStep(controller: controller)),
    );
  }

  /// Заказ пассажира: шторка размера по «Новый заказ - Выбор веса посылки» — один размер, без цен и «Без проезда пассажира».
  Future<void> _openOrderParcel(BuildContext context) async {
    final size = await AppBottomSheet.show<ParcelSize>(
      context,
      title: AppLocalizations.of(context).bookingParcel,
      child: _OrderParcelSheet(selected: controller.orderParcel),
    );
    if (size != null) controller.setOrderParcel(size);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final order = controller.passengerOrder;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final parcelPrices = [for (final k in parcelKinds) if (controller.extraOn(k)) controller.extras[k]!];
        final upTo = parcelPrices.isEmpty ? defaultExtraPrice(ExtraKind.parcelL) : parcelPrices.reduce(math.max);
        return WizardScaffold(
          step: order ? 3 : 5,
          order: order,
          body: [
            WizardSection(
              title: l10n.tripNewExtrasTitle,
              child: Column(
                children: [
                  if (controller.kind == TripKind.ride)
                    for (final (kind, icon) in _services) ...[
                      _ExtraRow(
                        icon: icon,
                        title: _serviceName(l10n, kind),
                        hint: kind == ExtraKind.pets ? l10n.tripNewExtraPetsHint : null,
                        trailing: AppSwitch(value: controller.extraOn(kind), onChanged: (v) => controller.setExtra(kind, v)),
                        onTap: () => controller.setExtra(kind, !controller.extraOn(kind)),
                      ),
                      if (!order && controller.extraOn(kind))
                        _PriceInput(
                          key: ValueKey('extra-${kind.json}'),
                          label: l10n.tripNewPriceHint,
                          initial: controller.extras[kind]!,
                          onChanged: (v) => controller.setExtraPrice(kind, v),
                        ),
                    ],
                  _ExtraRow(
                    icon: 'system_box',
                    title: l10n.tripNewExtraParcel,
                    hint: l10n.tripNewExtraParcelHint,
                    last: !(order && controller.orderParcel != ParcelSize.none),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // У заказа цены нет: на месте цены — выбранный размер (S, M, L), пока не выбран — ничего.
                        if (!order)
                          Text(
                            // Один размер — его цена («Новый заказ - Выбор доп услуг»); несколько или ни одного — «до» наибольшей («Новый заказ - Выбор доп услуг»).
                            parcelPrices.length == 1 ? l10n.tripNewExtraPrice(upTo) : l10n.tripNewExtraUpTo(upTo),
                            style: AppType.body2.copyWith(color: AppColors.accentPrimary),
                          )
                        else if (controller.orderParcel != ParcelSize.none)
                          Text(
                            controller.orderParcel.json ?? '',
                            style: AppType.body2.copyWith(color: AppColors.accentPrimary),
                          ),
                        const SizedBox(width: AppSize.gap8),
                        const AppIcon('arrows_alt_arrow_right', size: AppSize.icon18),
                      ],
                    ),
                    onTap: () => order ? _openOrderParcel(context) : _openParcel(context),
                  ),
                  if (order && controller.orderParcel != ParcelSize.none) _OrderParcelComment(controller: controller),
                ],
              ),
            ),
          ],
          bottom: order
              ? AppButton(
                  label: l10n.orderPublish,
                  onPressed: controller.orderReady ? () => publishOrder(context, controller) : null,
                )
              : AppButton(
                  label: l10n.tripNewNext,
                  onPressed: controller.extrasComplete ? () => _next(context) : null,
                ),
        );
      },
    );
  }
}

class _ExtraRow extends StatelessWidget {
  const _ExtraRow({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.onTap,
    this.hint,
    this.last = false,
  });

  final String icon;
  final String title;
  final String? hint;
  final Widget trailing;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSize.height48),
        padding: const EdgeInsets.symmetric(vertical: AppSize.pad8),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1)),
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
                  if (hint != null) Text(hint!, style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// Поле цены в рублях: целое число, пустое — 0.
class _PriceInput extends StatefulWidget {
  const _PriceInput({super.key, required this.label, required this.initial, required this.onChanged});

  final String label;
  final int initial;
  final ValueChanged<int> onChanged;

  @override
  State<_PriceInput> createState() => _PriceInputState();
}

class _PriceInputState extends State<_PriceInput> {
  late final TextEditingController _text = TextEditingController(text: '${widget.initial}');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSize.pad8),
        child: AppInput(
          label: widget.label,
          controller: _text,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (t) => widget.onChanged(int.tryParse(t) ?? 0),
          suffix: Text('₽', style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary)),
        ),
      );
}

class _ParcelResult {
  const _ParcelResult(this.sizes, this.parcelOnly, this.seats);

  final Map<ExtraKind, int> sizes;
  final bool parcelOnly;
  final int seats;
}

/// Лист размеров посылки («Новый заказ - Выбор веса посылки»): флажок и цена у каждого размера, «Без проезда пассажира»,
/// «Мест для посылок». Изменения применяются по «Добавить», «Отмена» их отбрасывает.
class _ParcelSheet extends StatefulWidget {
  const _ParcelSheet({
    required this.sizes,
    required this.parcelOnly,
    required this.seats,
    required this.showParcelOnly,
  });

  final Map<ExtraKind, int> sizes;
  final bool parcelOnly;
  final int seats;
  final bool showParcelOnly;

  @override
  State<_ParcelSheet> createState() => _ParcelSheetState();
}

class _ParcelSheetState extends State<_ParcelSheet> {
  static const _parcelSizes = {
    ExtraKind.parcelS: ParcelSize.s,
    ExtraKind.parcelM: ParcelSize.m,
    ExtraKind.parcelL: ParcelSize.l,
  };

  late final Map<ExtraKind, int> _sizes = {...widget.sizes};
  late bool _parcelOnly = widget.parcelOnly;
  late int _seats = widget.seats;
  late final TextEditingController _seatsText = TextEditingController(text: '${widget.seats}');

  @override
  void dispose() {
    _seatsText.dispose();
    super.dispose();
  }

  void _toggle(ExtraKind kind, bool on) => setState(() {
        if (on) {
          _sizes.putIfAbsent(kind, () => defaultExtraPrice(kind));
        } else {
          _sizes.remove(kind);
        }
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final names = {
      ExtraKind.parcelS: (l10n.tripNewParcelS, l10n.tripNewParcelSHint),
      ExtraKind.parcelM: (l10n.tripNewParcelM, l10n.tripNewParcelMHint),
      ExtraKind.parcelL: (l10n.tripNewParcelL, l10n.tripNewParcelLHint),
    };
    final chosen = _sizes.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16, vertical: AppSize.pad12),
              decoration: BoxDecoration(color: AppColors.bgSurface, borderRadius: BorderRadius.circular(AppSize.radius12)),
              child: Column(
                children: [
                  for (final kind in parcelKinds) ...[
                    InkWell(
                      onTap: () => _toggle(kind, !_sizes.containsKey(kind)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSize.pad8),
                        child: Row(
                          children: [
                            // Одна машина своего размера, как в шторке пассажира «Бронирование - С доп услугами» (кадры «Новый заказ - Выбор веса посылки»: рамка 42, отступ 8).
                            ParcelSizeImage(size: _parcelSizes[kind]!),
                            const SizedBox(width: AppSize.gap8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(names[kind]!.$1, style: AppType.body2.copyWith(color: AppColors.borderStrong)),
                                  Text(names[kind]!.$2, style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            AppCheckbox(value: _sizes.containsKey(kind), onChanged: (v) => _toggle(kind, v)),
                          ],
                        ),
                      ),
                    ),
                    if (_sizes.containsKey(kind))
                      _PriceInput(
                        key: ValueKey('parcel-${kind.json}'),
                        label: l10n.tripNewPriceHint,
                        initial: _sizes[kind]!,
                        onChanged: (v) => _sizes[kind] = v,
                      ),
                  ],
                  if (widget.showParcelOnly)
                    _ExtraRow(
                      icon: 'system_box',
                      title: l10n.tripNewParcelOnly,
                      hint: l10n.tripNewParcelOnlyDriverHint,
                      last: true,
                      trailing: AppSwitch(value: _parcelOnly, onChanged: (v) => setState(() => _parcelOnly = v)),
                      onTap: () => setState(() => _parcelOnly = !_parcelOnly),
                    ),
                ],
              ),
            ),
            if (chosen) ...[
              const SizedBox(height: AppSize.gap12),
              AppInput(
                label: l10n.tripNewParcelSeats,
                controller: _seatsText,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (t) => setState(() => _seats = int.tryParse(t) ?? 0),
              ),
            ],
            const SizedBox(height: AppSize.gap16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: l10n.commonCancel,
                    kind: AppButtonKind.outline,
                    size: AppButtonSize.medium,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppSize.gap8),
                Expanded(
                  child: AppButton(
                    label: l10n.tripNewParcelAdd,
                    size: AppButtonSize.medium,
                    // Снять все размеры можно только если они были выбраны раньше.
                    onPressed: (chosen && _seats >= 1) || (!chosen && widget.sizes.isNotEmpty)
                        ? ()=> Navigator.of(context).pop(_ParcelResult({..._sizes}, _parcelOnly, _seats))
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Комментарий к посылке заказа — как в брони «Бронирование»: поле «Комментарий», под ним «Вид посылки» и счётчик
/// из 250.
class _OrderParcelComment extends StatefulWidget {
  const _OrderParcelComment({required this.controller});

  final WizardController controller;

  @override
  State<_OrderParcelComment> createState() => _OrderParcelCommentState();
}

class _OrderParcelCommentState extends State<_OrderParcelComment> {
  // Длина комментария посылки — как у брони (`parcelComment` ≤ 250).
  static const _maxLength = 250;

  late final TextEditingController _text = TextEditingController(text: widget.controller.parcelComment);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hint = AppType.bodyCaption1.copyWith(color: AppColors.textTertiary);
    return Padding(
      padding: const EdgeInsets.only(top: AppSize.pad8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInput(
            key: const Key('order_parcel_comment'),
            label: l10n.bookingComment,
            controller: _text,
            maxLength: _maxLength,
            onChanged: widget.controller.setParcelComment,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSize.pad2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.bookingCommentHint, style: hint),
                Text('${_text.text.runes.length}/$_maxLength', style: hint),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Шторка размера посылки заказа («Новый заказ - Выбор веса посылки»; строки — как в шторке брони «Бронирование - С доп услугами»): «Укажите размер вашей
/// посылки», три размера, выбран один; цен нет — их назначает водитель откликом. «Добавить» возвращает
/// размер, «Отмена» — `null`.
class _OrderParcelSheet extends StatefulWidget {
  const _OrderParcelSheet({required this.selected});

  final ParcelSize selected;

  @override
  State<_OrderParcelSheet> createState() => _OrderParcelSheetState();
}

class _OrderParcelSheetState extends State<_OrderParcelSheet> {
  late ParcelSize _selected = widget.selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sizes = [
      (ParcelSize.s, l10n.tripNewParcelS, l10n.tripNewParcelSHint),
      (ParcelSize.m, l10n.tripNewParcelM, l10n.tripNewParcelMHint),
      (ParcelSize.l, l10n.tripNewParcelL, l10n.tripNewParcelLHint),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.tripNewParcelSheetTitle, style: AppType.body2.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSize.gap12),
        for (final (size, title, hint) in sizes) ...[
          _row(size, title, hint),
          const SizedBox(height: AppSize.gap12),
        ],
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: l10n.commonCancel,
                kind: AppButtonKind.outline,
                size: AppButtonSize.medium,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSize.gap8),
            Expanded(
              child: AppButton(
                label: l10n.tripNewParcelAdd,
                size: AppButtonSize.medium,
                onPressed: _selected == ParcelSize.none ? null : () => Navigator.of(context).pop(_selected),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(ParcelSize size, String title, String hint) {
    final on = size == _selected;
    return InkWell(
      key: Key('order_size_${size.json}'),
      borderRadius: BorderRadius.circular(AppSize.radius12),
      onTap: () => setState(() => _selected = size),
      child: Container(
        padding: const EdgeInsets.all(AppSize.pad12),
        decoration: BoxDecoration(
          color: on ? AppColors.accentPrimaryTint : null,
          borderRadius: BorderRadius.circular(AppSize.radius12),
          border: Border.all(color: on ? AppColors.accentPrimary : AppColors.borderDefault, width: AppSize.stroke1),
        ),
        child: Row(
          children: [
            ParcelSizeImage(size: size),
            const SizedBox(width: AppSize.gap8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.body2.copyWith(color: AppColors.textStrong)),
                  Text(hint, style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: AppSize.gap8),
            AppCheckbox(value: on, onChanged: (_) => setState(() => _selected = size)),
          ],
        ),
      ),
    );
  }
}
