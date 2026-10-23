import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_images.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_size.dart';
import '../../theme/app_type.dart';

/// «Аккаунт заблокирован» «Ваш аккаунт заблокирован»: зелёная шапка с логотипом и названием, под ней картинка
/// `image 25`, внизу тёмная карточка с текстом.
class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});

  // Размеры кадра, которых нет в шкале: шапка 177 с отступом сверху 60, логотип 50,
  // картинка 359×584.
  static const _headerHeight = 177.0;
  static const _headerTop = 60.0;
  static const _logo = 50.0;
  static const _imageWidth = 359.0;
  static const _imageHeight = 584.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Stack(
        children: [
          Positioned(
            top: _headerHeight,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                AppImages.accountBlocked,
                width: _imageWidth,
                height: _imageHeight,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: _headerHeight,
              padding: const EdgeInsets.only(top: _headerTop),
              color: AppColors.accentPrimary,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(AppImages.logo, width: _logo, height: _logo, fit: BoxFit.cover),
                  const SizedBox(width: AppSize.gap10),
                  Text(l10n.appTitle, style: AppType.title2.copyWith(color: AppColors.textOnAccent)),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(AppSize.pad16, AppSize.pad16 * 2, AppSize.pad16, AppSize.pad16),
              decoration: const BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppSize.radius24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.systemBlockedTitle, style: AppType.title2.copyWith(color: AppColors.textOnAccent)),
                    const SizedBox(height: AppSize.gap8),
                    Text(l10n.systemBlockedBody, style: AppType.body2.copyWith(color: AppColors.bgControl)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
