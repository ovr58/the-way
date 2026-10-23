import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';

/// Строка списка («поиск адреса»): значок слева, заголовок и пояснение, значок справа. Шрифты Roboto и
/// Open Sans из кита списка в приложении заменены на Gilroy (в приложении один шрифт).
class AppListItem extends StatelessWidget {
  const AppListItem({super.key, required this.title, this.subtitle, this.subtitleColor, this.leading, this.trailing, this.onTap});

  final String title;
  final String? subtitle;

  /// Цвет пояснения; по умолчанию — как у заголовка (кит списка «поиск адреса»).
  final Color? subtitleColor;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.height56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16, vertical: AppSize.pad4),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: AppSize.gap16)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppType.titlesSubheadline.copyWith(color: AppColors.listKitTextPrimary)),
                    if (subtitle != null)
                      Text(subtitle!, style: AppType.body2.copyWith(color: subtitleColor ?? AppColors.listKitTextPrimary)),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: AppSize.gap16), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
