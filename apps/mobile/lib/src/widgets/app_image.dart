import 'package:flutter/widgets.dart';

import '../app/api_config.dart';
import '../app/session.dart';
import '../theme/app_colors.dart';

/// Картинка с API: относительный [url] (`/files/{id}`) + адрес API, запрос с токеном сессии.
/// Нет адреса или картинка не загрузилась — плашка цвета `border.default`; о неудаче — один раз на адрес в
/// [onLoadError] (в приложении — журнал клиента `POST /client-logs`): плашка молча прятала причину
/// (миниатюра авто пустая, а фото в деталях есть).
class AppImage extends StatelessWidget {
  const AppImage(this.url, {super.key, this.width, this.height, this.fit = BoxFit.cover});

  /// Куда сообщить о неудаче загрузки; ставит `main.dart`.
  static void Function(String message)? onLoadError;

  static final Set<String> _reported = {};

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = SizedBox(width: width, height: height, child: const ColoredBox(color: AppColors.borderDefault));
    final path = url;
    if (path == null || path.isEmpty) return placeholder;
    final token = AppSession.maybeOf(context)?.token;
    return Image.network(
      '$apiUrl$path',
      width: width,
      height: height,
      fit: fit,
      headers: token == null ? null : {'Authorization': 'Bearer $token'},
      errorBuilder: (_, error, _) {
        if (_reported.add(path)) onLoadError?.call('AppImage $path (${width ?? '-'}×${height ?? '-'}, токен ${token != null}): $error');
        return placeholder;
      },
    );
  }
}
