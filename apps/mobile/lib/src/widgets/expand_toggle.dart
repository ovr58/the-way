import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';
import 'app_icon.dart';

/// Длительность и кривая раскрытия: остановки маршрута, цены участков «Смотреть стоимость» —
/// одно движение 350 мс easeInOut. Только встроенные неявные анимации Flutter; не зависит от системной
/// настройки «уменьшить движение».
const expandDuration = Duration(milliseconds: 350);
const expandCurve = Curves.easeInOut;

/// Кнопка раскрытия: таблетка «подпись ⌄» с зелёным контуром ↔ круг со стрелкой вверх. Одно значение t
/// (0 — таблетка, 1 — круг) ведёт сразу всё: ширину подписи, её прозрачность, поля, скругление и поворот стрелки
/// на пол-оборота. [height] — высота таблетки и диаметр круга (у каждого места своя, как в кадре).
/// Ключ [chipKey] стоит на нажимаемой области таблетки, [closeKey] — круга.
class ExpandToggle extends StatelessWidget {
  const ExpandToggle({
    super.key,
    required this.label,
    required this.expanded,
    required this.onTap,
    this.height = AppSize.height24,
    this.chipKey,
    this.closeKey,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;
  final double height;
  final Key? chipKey;
  final Key? closeKey;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: expanded ? 1 : 0),
        duration: expandDuration,
        curve: expandCurve,
        builder: (context, t, _) {
          final radius = BorderRadius.circular(lerpDouble(AppSize.radius8, height / 2, t)!);
          return Material(
            color: Colors.transparent,
            child: InkWell(
              key: expanded ? closeKey : chipKey,
              borderRadius: radius,
              onTap: onTap,
              child: Container(
                height: height,
                constraints: BoxConstraints(minWidth: height),
                padding: EdgeInsets.symmetric(horizontal: lerpDouble(AppSize.pad8, 0, t)!),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: AppColors.accentPrimary, width: AppSize.stroke1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (t < 1)
                      ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: 1 - t,
                          child: Opacity(
                            opacity: 1 - t,
                            child: Padding(
                              padding: const EdgeInsets.only(right: AppSize.gap4),
                              child: Text(label,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: AppType.button4.copyWith(color: AppColors.accentPrimary)),
                            ),
                          ),
                        ),
                      ),
                    Transform.rotate(
                      angle: math.pi * t,
                      child: const AppIcon('arrows_alt_arrow_down', size: AppSize.icon12, color: AppColors.accentPrimary),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

/// Список под кнопкой раскрытия: высота и прозрачность ведёт то же движение, что у [ExpandToggle].
/// Свёрнутый и доехавший до нуля список в дереве не держится.
class ExpandReveal extends StatelessWidget {
  const ExpandReveal({super.key, required this.expanded, required this.child});

  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: expanded ? 1 : 0),
        duration: expandDuration,
        curve: expandCurve,
        builder: (context, t, _) {
          if (!expanded && t == 0) return const SizedBox.shrink();
          return ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: t,
              child: Opacity(opacity: t, child: child),
            ),
          );
        },
      );
}
