import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_header.dart';
import '../widgets/cars_ui.dart';
import 'photo_sheet.dart';

/// Экран «СТС» («Добавление нового ТС»): подпись и «Сделать фото». Снимок — системная камера или галерея через лист
/// «Добавление нового ТС», видоискателя нет. Закрывается, вернув снимок.
class StsScreen extends StatelessWidget {
  const StsScreen({super.key, required this.picker});

  final PhotoPicker picker;

  Future<void> _take(BuildContext context) async {
    final navigator = Navigator.of(context);
    final XFile? photo = await choosePhoto(context, picker);
    if (photo != null) navigator.pop(photo);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(title: l10n.carsStsTitle, onBack: () => Navigator.of(context).maybePop()),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.carsSts,
                        textAlign: TextAlign.center,
                        style: AppType.titlesHeadline.copyWith(color: AppColors.textPrimary)),
                    const SizedBox(height: AppSize.gap4),
                    Text(l10n.carsStsHint,
                        textAlign: TextAlign.center,
                        style: AppType.body2.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
          CarsBottomBar(child: AppButton(label: l10n.carsStsTake, onPressed: () => _take(context))),
        ],
      ),
    );
  }
}
