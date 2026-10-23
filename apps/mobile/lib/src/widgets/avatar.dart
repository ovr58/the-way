import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import 'app_icon.dart';
import 'app_image.dart';

/// Круглое фото пользователя (38 по умолчанию, как `photo` в карточке поездки).
///
/// С [silhouette] и без фото в круге — силуэт человека вполовину размера на `bg.control`, как у пустого
/// аватара на экране регистрации. Включён только там, где кадр рисует аватар крупно («Мой
/// профиль», «Личные данные»); карточки и детали остаются серой плашкой [AppImage].
class Avatar extends StatelessWidget {
  const Avatar({super.key, this.url, this.size = AppSize.height38, this.silhouette = false});

  final String? url;
  final double size;
  final bool silhouette;

  @override
  Widget build(BuildContext context) {
    final noPhoto = url == null || url!.isEmpty;
    return ClipOval(
      child: silhouette && noPhoto
          ? SizedBox(
              width: size,
              height: size,
              child: ColoredBox(
                color: AppColors.bgControl,
                child: Center(child: AppIcon('users_user_rounded', size: size / 2, color: AppColors.textSecondary)),
              ),
            )
          : AppImage(url, width: size, height: size),
    );
  }
}
