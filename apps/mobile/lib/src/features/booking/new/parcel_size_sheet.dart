import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_checkbox.dart';
import '../../../widgets/parcel_size_image.dart';

/// Размер посылки, который возит водитель, и его цена (`extrasPriced(parcel_<size>)`).
class ParcelOption {
  const ParcelOption(this.size, this.price);

  final ParcelSize size;
  final int price;
}

/// Шторка «Бронирование - С доп услугами» «Посылка / Укажите размер вашей посылки». Возвращает выбранный размер
/// («Добавить») или `null` («Отмена»).
Future<ParcelSize?> showParcelSizeSheet(
  BuildContext context, {
  required List<ParcelOption> options,
  required ParcelSize selected,
}) {
  final l10n = AppLocalizations.of(context);
  return AppBottomSheet.show<ParcelSize>(
    context,
    title: l10n.bookingParcel,
    child: _SizeSheet(options: options, selected: selected),
  );
}

class _SizeSheet extends StatefulWidget {
  const _SizeSheet({required this.options, required this.selected});

  final List<ParcelOption> options;
  final ParcelSize selected;

  @override
  State<_SizeSheet> createState() => _SizeSheetState();
}

class _SizeSheetState extends State<_SizeSheet> {
  late ParcelSize _selected = widget.selected;

  (String, String) _texts(AppLocalizations l10n, ParcelSize size) => switch (size) {
        ParcelSize.s => (l10n.bookingSizeS, l10n.bookingSizeSHint),
        ParcelSize.m => (l10n.bookingSizeM, l10n.bookingSizeMHint),
        _ => (l10n.bookingSizeL, l10n.bookingSizeLHint),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.bookingParcelSizePrompt,
          style: AppType.body2.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSize.gap12),
        for (final option in widget.options) ...[
          _row(l10n, option),
          const SizedBox(height: AppSize.gap12),
        ],
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: l10n.commonCancel,
                size: AppButtonSize.medium,
                kind: AppButtonKind.outline,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSize.gap8),
            Expanded(
              child: AppButton(
                label: l10n.bookingAdd,
                size: AppButtonSize.medium,
                onPressed: _selected == ParcelSize.none ? null : () => Navigator.of(context).pop(_selected),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(AppLocalizations l10n, ParcelOption option) {
    final on = option.size == _selected;
    final (title, hint) = _texts(l10n, option.size);
    return InkWell(
      key: Key('size_${option.size.json}'),
      borderRadius: BorderRadius.circular(AppSize.radius12),
      onTap: () => setState(() => _selected = option.size),
      child: Container(
        padding: const EdgeInsets.all(AppSize.pad12),
        decoration: BoxDecoration(
          color: on ? AppColors.accentPrimaryTint : null,
          borderRadius: BorderRadius.circular(AppSize.radius12),
          border: Border.all(
            color: on ? AppColors.accentPrimary : AppColors.borderDefault,
            width: AppSize.stroke1,
          ),
        ),
        child: Row(
          children: [
            ParcelSizeImage(size: option.size),
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
            Text(
              l10n.bookingExtraPrice(option.price),
              style: AppType.body2.copyWith(color: AppColors.accentPrimary),
            ),
            const SizedBox(width: AppSize.gap8),
            AppCheckbox(value: on, onChanged: (_) => setState(() => _selected = option.size)),
          ],
        ),
      ),
    );
  }
}
