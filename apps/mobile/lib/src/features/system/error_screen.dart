import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/app_error_view.dart';

/// «Ошибка» «Не удалось выполнить действие»: «Обновить» закрывает экран и повторяет запрос.
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key, required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgScreen,
        body: SafeArea(
          child: AppErrorView(
            onRetry: () {
              Navigator.of(context).maybePop();
              onRetry();
            },
          ),
        ),
      );
}
