import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';
import 'app_button.dart';
import 'app_icon.dart';
import 'rating_line.dart';

/// Шапка профиля («Профиль - Профиль пассажира», «Профиль - Профиль пассажира до оплаты», «Профиль пассажира до принятия заявки», «Профиль пассажира после принятия заявки»; профиль водителя — по «Профиль - Профиль пассажира»): как `AppHeader`, но стрелка «назад» зелёная
/// (`accent.primary`), а меню «⋯» справа не показывается (принятое решение: действие не описано).
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.bgScreen,
          border: Border(bottom: BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1)),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: AppSize.height60,
            child: Row(
              children: [
                SizedBox(
                  width: AppSize.height56,
                  child: Center(
                    child: AppIconButton(
                      onPressed: onBack,
                      child: const AppIcon('arrows_alt_arrow_left', size: AppSize.icon24, color: AppColors.accentPrimary),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppType.title3.copyWith(color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: AppSize.height56),
              ],
            ),
          ),
        ),
      );
}

/// Плашка «Рейтинг поездок» профиля («Профиль - Профиль пассажира»): звезда, значение через запятую, число поездок.
class ProfileRatingBox extends StatelessWidget {
  const ProfileRatingBox({super.key, required this.user});

  final UserBrief user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSize.pad8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderDefault, width: AppSize.stroke1),
        borderRadius: BorderRadius.circular(AppSize.radius8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.driverBookingsTripsRating,
              style: AppType.bodyFootnote.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: AppSize.gap4),
          // «★ 4,8 · 120 поездок» — общая строка рейтинга с разделителем по кадру («Профиль - Профиль пассажира», «Профиль - Профиль пассажира до оплаты»).
          RatingLine(rating: user.rating, tripsCount: user.tripsCount, variant: RatingLineVariant.stat),
        ],
      ),
    );
  }
}
