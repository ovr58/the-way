import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_icon.dart';

/// Иллюстрация успеха (`illustration` кадров «Заказ - Оплата прошла», «Новый заказ - Заказ создан»): круг 64 с галочкой и искры вокруг него.
/// Искры рисуются поверх, за границей круга, и места в раскладке не занимают. [failure] — вариант «Бронь отменена»:
/// тот же рисунок в красном (`status.error`) с крестом в круге.
class SuccessBadge extends StatelessWidget {
  const SuccessBadge({super.key, this.failure = false});

  final bool failure;

  // Круг иллюстрации в кадре — 64, галочка в нём — 40.
  static const _circle = 64.0;
  static const _check = 40.0;
  // Заливка круга в кадре — `#7EEB42 @ 0.2` (токен `accent.success-tint` — 0.12): значение кадра, принятое решение.
  static const _fill = Color(0x337EEB42);

  @override
  Widget build(BuildContext context) => SizedBox(
        key: const Key('success_badge'),
        width: _circle,
        height: _circle,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(color: failure ? AppColors.statusErrorTint : _fill, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: AppIcon(
                failure ? 'essentional_close_circle' : 'essentional_check_circle',
                size: _check,
                color: failure ? AppColors.statusError : AppColors.accentPrimary,
              ),
            ),
            Positioned.fill(
              child: CustomPaint(key: const Key('success_sparks'), painter: _SparksPainter(failure: failure)),
            ),
          ],
        ),
      );
}

/// Искра кадра: размер звёздочки и смещение её центра от центра круга (по снимку кадра).
class _Spark {
  const _Spark(this.size, this.dx, this.dy, {this.faint = false});

  final double size;
  final double dx;
  final double dy;
  final bool faint;
}

class _SparksPainter extends CustomPainter {
  const _SparksPainter({required this.failure});

  final bool failure;

  // Девять путей `Vector` кадра: звёзды 10 и 6, точки 3 и две бледные 2 (`#7EEB42` @ 0.12).
  static const _sparks = [
    _Spark(10, 34.1, -24.1),
    _Spark(6, -30.5, -29.5),
    _Spark(6, -21, 32.9),
    _Spark(3, -14.25, -37.1),
    _Spark(3, 24.4, -33.6),
    _Spark(3, -36.1, 22.75),
    _Spark(3, 32.5, 30),
    _Spark(2, -38.1, -14.1, faint: true),
    _Spark(2, 40.1, -9.6, faint: true),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (final s in _sparks) {
      final r = s.size / 2;
      final c = center + Offset(s.dx, s.dy);
      final k = r * 0.18; // вогнутость лучей четырёхконечной звезды
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
        ..close();
      final color = failure
          ? (s.faint ? AppColors.statusErrorTint : AppColors.statusError)
          : (s.faint ? AppColors.accentSuccessTint : AppColors.accentSuccess);
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparksPainter oldDelegate) => oldDelegate.failure != failure;
}
