import 'package:api_client/api_client.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';
import 'app_icon.dart';

/// Вид строки рейтинга: [regular] — блок водителя и строки пассажиров («Детали поездки - Места есть»), [profile] — шапка профиля
/// («Профиль - Базовый экран», «Профиль ВОДИТЕЛЯ»): там промежутки 4 вместо 8, кружок 3 вместо 6, текст основного цвета; [stat] — плашка
/// «Рейтинг поездок» профиля пассажира («Профиль - Профиль пассажира», «Профиль - Профиль пассажира до оплаты»): как [profile], но текст 15/600.
enum RatingLineVariant { regular, profile, stat }

/// Рейтинг: жёлтая звезда, число с запятой и, если задано, «• 127 поездок» («Детали поездки - Места есть», «Профиль - Базовый экран»); без отзывов —
/// «★ 5, нет отзывов» (требование «5 ★, нет отзывов» из `docs/task.md` в виде кадра), а если у человека
/// есть завершённые поездки — «★ 5, нет отзывов • N поездок»; без поездок числа нет.
class RatingLine extends StatelessWidget {
  const RatingLine({
    super.key,
    required this.rating,
    this.tripsCount,
    this.tripsWithReviews = true,
    this.variant = RatingLineVariant.regular,
  });

  final Rating rating;
  final RatingLineVariant variant;

  /// Число поездок; `null` — не показывать.
  final int? tripsCount;

  /// Показывать число поездок и при наличии отзывов. `false` — ряды, где кадр его не рисует (карточка
  /// ленты, строка пассажира): там число поездок появляется только вместо отсутствующих отзывов.
  final bool tripsWithReviews;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = variant != RatingLineVariant.regular;
    final style = (variant == RatingLineVariant.stat ? AppType.titlesSubheadline : AppType.body2)
        .copyWith(color: profile ? AppColors.textPrimary : AppColors.textMuted);
    final gap = profile ? AppSize.gap4 : AppSize.gap8;
    // Кружок-разделитель в кадрах: 6 цвета text.secondary («Детали поездки - Места есть») и 3 цвета text.primary («Профиль - Базовый экран») — ступеней
    // 3 и 6 в шкале размеров нет.
    final dot = profile ? 3.0 : 6.0;
    final noReviews = rating.count == 0;
    final trips = noReviews ? ((tripsCount ?? 0) > 0 ? tripsCount : null) : (tripsWithReviews ? tripsCount : null);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppIcon('system_star', size: AppSize.icon14, color: AppColors.accentWarning),
        SizedBox(width: gap),
        Text(noReviews ? l10n.ratingNoReviews : NumberFormat('0.0', 'ru').format(rating.value), style: style),
        if (trips != null) ...[
          SizedBox(width: gap),
          SizedBox(
            key: const Key('rating_dot'),
            width: dot,
            height: dot,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: profile ? AppColors.textPrimary : AppColors.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: gap),
          Flexible(child: Text(l10n.ratingTrips(trips), maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        ],
      ],
    );
  }
}
