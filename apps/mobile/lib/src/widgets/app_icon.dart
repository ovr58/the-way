import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';

/// Иконка из `assets/icons/<name>.svg`, перекрашивается в [color].
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size = AppSize.icon20, this.color = AppColors.textPrimary});

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/icons/$name.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}
