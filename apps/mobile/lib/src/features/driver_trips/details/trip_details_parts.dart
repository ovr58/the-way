import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';

/// Заголовок блока экрана (15/600).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary));
}

/// Белый блок со скруглением 12 и полями 16.
class WhiteCard extends StatelessWidget {
  const WhiteCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSize.pad16),
        decoration: BoxDecoration(color: AppColors.bgSurface, borderRadius: BorderRadius.circular(AppSize.radius12)),
        child: child,
      );
}


