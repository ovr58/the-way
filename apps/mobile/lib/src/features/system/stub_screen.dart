import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_empty.dart';
import '../../widgets/app_header.dart';

/// Экран-заглушка («Раздел в разработке», «Чат появится позже»). Со стрелкой «назад»,
/// если его открыли поверх другого экрана.
class StubScreen extends StatelessWidget {
  const StubScreen({super.key, this.title});

  /// Текст по центру; без него — «Раздел в разработке».
  final String? title;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(title: '', bordered: false, onBack: navigator.canPop() ? navigator.maybePop : null),
          Expanded(child: AppEmpty(title: title ?? AppLocalizations.of(context).systemStubTitle)),
        ],
      ),
    );
  }
}
