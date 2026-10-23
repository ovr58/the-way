import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_button.dart';
import '../../search/filter/popup_card.dart';

/// Окно отмены брони («Пришёл ответ», «Детали поездки - Лимит отмен», «Детали поездки - Отмена брони», «Детали поездки - Лимит отмен» и «Отменить заявку?»): карточка «Pop-Up» 343, наверху
/// кнопка «назад» (заливка), под ней действие. Закрывается результатом: `true` — действие подтверждено.
class CancelPopup extends StatelessWidget {
  const CancelPopup({
    super.key,
    required this.title,
    required this.body,
    this.note,
    this.extras = const [],
    this.image = false,
    required this.keepLabel,
    required this.confirmLabel,
    this.confirmKind = AppButtonKind.danger,
  });

  final String title;
  final String body;
  final String? note;
  final List<Widget> extras;

  /// «Пришёл ответ» и «Отменить заявку?» — с картинкой окон-уведомлений, остальные — без.
  final bool image;
  final String keepLabel;
  final String confirmLabel;
  final AppButtonKind confirmKind;

  @override
  Widget build(BuildContext context) => PopupCard(
        title: title,
        body: body,
        note: note,
        extras: extras,
        image: image,
        actions: [
          AppButton(
            key: const Key('cancel_keep'),
            label: keepLabel,
            size: AppButtonSize.medium,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButton(
            key: const Key('cancel_confirm'),
            label: confirmLabel,
            kind: confirmKind,
            size: AppButtonSize.medium,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      );
}

/// Показывает [popup] поверх экрана с затемнением; `false`, если окно закрыто без подтверждения.
Future<bool> showCancelPopup(BuildContext context, Widget popup) async =>
    await showDialog<bool>(
      context: context,
      barrierColor: AppColors.overlayScrim,
      builder: (_) => Center(child: popup),
    ) ??
    false;

/// Блок строк на `bg.surface` окон отмены: «Возврат на карту» и «Срок зачисления» (если есть возврат)
/// и «Отмен за 30 дней N / 2».
class CancelInfoBlock extends StatelessWidget {
  const CancelInfoBlock({super.key, required this.count, this.refundAmount});

  final int count;
  final int? refundAmount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = [
      if (refundAmount != null) ...[
        (l10n.cancelRefundLabel, l10n.cancelRefundAmount(refundAmount!)),
        (l10n.cancelRefundTermLabel, l10n.cancelRefundTerm),
      ],
      (l10n.cancelCountLabel, l10n.cancelCountValue(count)),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSize.pad16),
      decoration: BoxDecoration(color: AppColors.bgSurface, borderRadius: BorderRadius.circular(AppSize.radius12)),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSize.gap8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(rows[i].$1, style: AppType.bodyFootnote.copyWith(color: AppColors.textPrimary)),
                Text(rows[i].$2, style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
