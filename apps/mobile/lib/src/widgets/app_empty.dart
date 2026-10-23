import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';

/// Пустое состояние списка: заголовок 17/700 и пояснение 15 с прозрачностью 0.5 (стили текстового
/// блока «Отсутствии интернета»). Над заголовком — необязательная картинка 90×80 ([imageAsset], слой `image 20`), под
/// текстом через 12 — необязательное действие [action] (кнопка «+ …» «Мои заказы - Нет заказов», «Базовые экраны - Поездок нет», «Транспортные средства»): вся группа по центру.
class AppEmpty extends StatelessWidget {
  const AppEmpty({super.key, required this.title, this.subtitle, this.imageAsset, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  /// Путь ассета картинки над заголовком.
  final String? imageAsset;

  // Размер картинки кадра — 90×80; такой ступени в шкале нет.
  static const _imageWidth = 90.0;
  static const _imageHeight = 80.0;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageAsset != null) ...[
                Image.asset(imageAsset!, width: _imageWidth, height: _imageHeight, fit: BoxFit.cover),
                const SizedBox(height: AppSize.gap12),
              ],
              Text(title, textAlign: TextAlign.center, style: AppType.titlesHeadline.copyWith(color: AppColors.textPrimary)),
              if (subtitle != null) ...[
                const SizedBox(height: AppSize.gap4),
                Text(subtitle!, textAlign: TextAlign.center, style: AppType.body2.copyWith(color: AppColors.textSecondary)),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSize.gap12),
                action!,
              ],
            ],
          ),
        ),
      );
}
