import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/session.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_empty.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_loading.dart';
import '../../../widgets/trip_card_view.dart';
import '../data/profile_repository.dart';

/// Жалобы (кадра нет): жалобы, полученные пользователем, в порядке сервера; только чтение.
class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  Future<List<Complaint>>? _load;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load ??= ProfileRepository(AppSession.of(context).api).complaints();
  }

  void _reload() {
    final future = ProfileRepository(AppSession.of(context).api).complaints();
    setState(() {
      _load = future;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(title: l10n.profileComplaints, onBack: () => Navigator.of(context).maybePop()),
          Expanded(
            child: FutureBuilder<List<Complaint>>(
              future: _load,
              builder: (context, snapshot) {
                if (snapshot.hasError) return AppErrorView(onRetry: _reload);
                final complaints = snapshot.data;
                if (complaints == null) return const AppLoading();
                if (complaints.isEmpty) {
                  return AppEmpty(title: l10n.profileComplaintsEmptyTitle, subtitle: l10n.profileComplaintsEmptyBody);
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSize.pad16),
                  itemCount: complaints.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSize.gap10),
                  itemBuilder: (_, i) => _ComplaintRow(complaint: complaints[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Карточка жалобы: вид пункта меню «Профиль - Базовый экран» без значка и стрелки — причина, ниже дата и состояние.
class _ComplaintRow extends StatelessWidget {
  const _ComplaintRow({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = DateFormat('d MMMM y', 'ru').format(moscowTime(complaint.createdAt));
    final status = switch (complaint.status) {
      ComplaintStatus.open => l10n.profileComplaintOpen,
      ComplaintStatus.closed => l10n.profileComplaintClosed,
      _ => null,
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.bgSurface, borderRadius: BorderRadius.circular(AppSize.radius12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16, vertical: AppSize.pad12),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(complaint.reason, style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSize.gap4),
              Text(status == null ? date : '$date · $status', style: AppType.body2.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
