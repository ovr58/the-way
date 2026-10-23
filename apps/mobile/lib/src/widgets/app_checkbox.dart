import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';

/// Флажок из компонента `Check Box` 18×18: пустой — зелёная обводка 2, отмеченный — зелёная
/// заливка и белая галка.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Container(
          width: AppSize.icon18,
          height: AppSize.icon18,
          decoration: BoxDecoration(
            color: value ? AppColors.accentPrimary : null,
            border: value ? null : Border.all(color: AppColors.accentPrimary, width: AppSize.stroke2),
            borderRadius: BorderRadius.circular(AppSize.radius4),
          ),
          child: value ? const CustomPaint(painter: _CheckPainter()) : null,
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textOnAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSize.stroke2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.25, h * 0.52)
      ..lineTo(w * 0.43, h * 0.7)
      ..lineTo(w * 0.75, h * 0.32);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => false;
}
