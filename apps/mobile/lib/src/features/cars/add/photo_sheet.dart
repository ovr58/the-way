import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../profile_setup/photo_picker.dart' show isCameraDenied;
import '../widgets/cars_ui.dart' show showCarsError;
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_icon.dart';

/// Снимок из системной камеры или галереи. Подменяется в тестах.
typedef PhotoPicker = Future<XFile?> Function(ImageSource source);

/// Системный выбор снимка: сжатие, чтобы файл влезал в предел 10 МБ загрузки.
Future<XFile?> pickSystemPhoto(ImageSource source) =>
    ImagePicker().pickImage(source: source, maxWidth: 2048, imageQuality: 85);

/// Лист «Загрузка фотографии» («Добавление нового ТС»): «Камера» или «Галерея» (как в профиле). `null` — лист закрыт без
/// выбора или камера запрещена (тогда — текст об этом).
Future<XFile?> choosePhoto(BuildContext context, PhotoPicker picker) async {
  final l10n = AppLocalizations.of(context);
  final source = await AppBottomSheet.show<ImageSource>(
    context,
    title: l10n.carsPhotoSheetTitle,
    child: Row(
      children: [
        Expanded(child: _Tile(icon: 'media_camera', label: l10n.carsPhotoCamera, source: ImageSource.camera)),
        const SizedBox(width: AppSize.gap8),
        Expanded(child: _Tile(icon: 'media_gallery_wide', label: l10n.carsPhotoGallery, source: ImageSource.gallery)),
      ],
    ),
  );
  if (source == null) return null;
  try {
    return await picker(source);
  } catch (error) {
    if (!isCameraDenied(error)) rethrow;
    if (context.mounted) showCarsError(context, l10n.photoCameraDenied);
    return null;
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.source});

  final String icon;
  final String label;
  final ImageSource source;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppSize.radius12),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSize.radius12),
          onTap: () => Navigator.of(context).pop(source),
          child: Padding(
            padding: const EdgeInsets.all(AppSize.pad12),
            child: Column(
              children: [
                Container(
                  width: _iconBox,
                  height: _iconBox,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary,
                    borderRadius: BorderRadius.circular(AppSize.radius8),
                  ),
                  child: AppIcon(icon, size: AppSize.icon24, color: AppColors.textOnAccent),
                ),
                const SizedBox(height: AppSize.gap4),
                Text(label, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
        ),
      );

  // Квадрат значка в кадре — 48; такой ступени в шкале нет.
  static const _iconBox = 48.0;
}
