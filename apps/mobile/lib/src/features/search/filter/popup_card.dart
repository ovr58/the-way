import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';

/// Картинка окон-уведомлений (`image 19`, «Доступ к локации», «Пришёл ответ» – «Пришёл отказ»).
const popupIllustration = 'assets/images/popup_illustration.webp';

/// Окно «Pop-Up» кадров «Доступ к локации», «Пришёл ответ», «Пришёл отказ»: иллюстрация 90×80, заголовок, текст и кнопки в колонку.
/// Окна отмены («Пришёл ответ», «Детали поездки - Лимит отмен», «Детали поездки - Отмена брони», «Детали поездки - Лимит отмен») добавляют строку-предупреждение [note] под текстом и блоки
/// [extras] над кнопками; «Детали поездки - Лимит отмен», «Детали поездки - Отмена брони», «Детали поездки - Лимит отмен» рисуются без иллюстрации ([image] = false).
class PopupCard extends StatelessWidget {
  const PopupCard({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
    this.image = true,
    this.note,
    this.extras = const [],
  });

  final String title;
  final String body;
  final List<Widget> actions;
  final bool image;
  final String? note;
  final List<Widget> extras;

  // Размер картинки кадра — 90×80; такой ступени в шкале нет.
  static const _imageWidth = 90.0;
  static const _imageHeight = 80.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
      child: Material(
        color: AppColors.bgScreen,
        borderRadius: BorderRadius.circular(AppSize.radius12),
        child: Padding(
          padding: const EdgeInsets.all(AppSize.pad16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (image) ...[
                Image.asset(popupIllustration, width: _imageWidth, height: _imageHeight, fit: BoxFit.cover),
                const SizedBox(height: AppSize.gap16),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppType.title3.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSize.gap8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: AppType.body2.copyWith(color: AppColors.textSecondary),
              ),
              if (note != null) ...[
                const SizedBox(height: AppSize.gap8),
                Text(
                  note!,
                  textAlign: TextAlign.center,
                  style: AppType.body2.copyWith(color: AppColors.textSecondary),
                ),
              ],
              for (final extra in extras) ...[
                const SizedBox(height: AppSize.gap16),
                extra,
              ],
              const SizedBox(height: AppSize.gap16),
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSize.gap4),
                actions[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
