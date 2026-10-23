import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_routes.dart';
import '../../../app/session.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/app_loading.dart';
import '../../../widgets/avatar.dart';
import '../../../widgets/info_tile.dart';
import '../../../widgets/profile_parts.dart';
import '../../driver_bookings/widgets/blocks.dart';
import '../../auth/data/phone_format.dart';
import '../data/search_repository.dart';

const _stars = 5;

/// Профиль водителя по образцу профиля пассажира «Профиль - Профиль пассажира»: шапка, белый блок — фото, имя, телефон (если
/// сервер его отдал, как у «Профиль - Профиль пассажира»), плашка «Рейтинг поездок» (рейтинг и число поездок; без отзывов — «5, нет
/// отзывов»); ниже — «Отзывы»: автор, оценка звёздами, текст, дата, в порядке сервера (новые сверху).
/// «Написать в чат» — как у «Профиль - Профиль пассажира»: при известном телефоне, ведёт на заглушку чата.
class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  Future<(UserBrief, List<Review>)>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<(UserBrief, List<Review>)> _load() {
    final repo = SearchRepository(AppSession.of(context).api);
    return (repo.user(widget.userId), repo.reviews(widget.userId)).wait;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          ProfileHeader(title: l10n.driverProfileTitle, onBack: () => Navigator.of(context).maybePop()),
          Expanded(
            child: FutureBuilder<(UserBrief, List<Review>)>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return AppErrorView(onRetry: () => setState(() => _future = _load()));
                final data = snapshot.data;
                if (data == null) return const AppLoading();
                final (user, reviews) = data;
                final phone = user.phone;
                final list = ListView(
                  padding: const EdgeInsets.symmetric(vertical: AppSize.pad20),
                  children: [
                    CardBlock(
                      child: Column(
                        children: [
                          Row(children: [
                            Avatar(url: user.photoUrl),
                            const SizedBox(width: AppSize.gap12),
                            Expanded(
                              child: Text(user.name ?? '',
                                  style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
                            ),
                          ]),
                          if (phone != null) ...[
                            const SizedBox(height: AppSize.gap12),
                            InfoTile(label: l10n.driverBookingsPhone, value: formatPhone(phone)),
                          ],
                          const SizedBox(height: AppSize.gap12),
                          ProfileRatingBox(user: user),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSize.gap20),
                    SectionTitle(l10n.driverProfileReviews),
                    const SizedBox(height: AppSize.gap12),
                    if (reviews.isEmpty)
                      CardBlock(
                        child: Text(l10n.driverProfileNoReviews,
                            style: AppType.body2.copyWith(color: AppColors.textSecondary)),
                      ),
                    for (final (i, review) in reviews.indexed) ...[
                      if (i > 0) const SizedBox(height: AppSize.gap12),
                      _ReviewCard(review: review),
                    ],
                  ],
                );
                if (phone == null) return list;
                return Column(
                  children: [
                    Expanded(child: list),
                    BottomBar(
                      child: AppButton(
                        label: l10n.driverBookingsWriteChat,
                        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.stub, arguments: l10n.systemStubChat),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Отзыв: автор и дата в строке, под ними оценка звёздами (из пяти), ниже — текст, если есть.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final body = review.body;
    return CardBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(review.authorName ?? l10n.driverProfileAuthorUnknown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
              ),
              const SizedBox(width: AppSize.gap8),
              Text(DateFormat('d MMMM y', 'ru').format(review.createdAt.toLocal()),
                  style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: AppSize.gap4),
          Row(
            key: Key('review_${review.id}_stars_${review.rating}'),
            children: [
              for (var i = 0; i < _stars; i++)
                AppIcon('system_star',
                    size: AppSize.icon14, color: i < review.rating ? AppColors.accentWarning : AppColors.borderDefault),
            ],
          ),
          if (body != null && body.isNotEmpty) ...[
            const SizedBox(height: AppSize.gap8),
            Text(body, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
          ],
        ],
      ),
    );
  }
}
