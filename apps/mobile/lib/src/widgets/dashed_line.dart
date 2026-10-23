import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';

/// Вертикальная пунктирная линия маршрута (`line` «Новый заказ - Маршрут»): толщина 2, штрих 12, разрыв 12, цвет
/// `text.secondary`. Занимает всю высоту, которую дал родитель.
class DashedLine extends StatelessWidget {
  const DashedLine({super.key});

  // Штрих и разрыв кадра — 12; в шкале размеров этих ступеней нет.
  static const _dash = 12.0;
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: AppSize.stroke2,
        child: CustomPaint(painter: _DashedPainter(), child: SizedBox.expand()),
      );
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.textSecondary;
    for (var y = 0.0; y < size.height; y += DashedLine._dash + DashedLine._gap) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, math.min(DashedLine._dash, size.height - y)), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedPainter oldDelegate) => false;
}
