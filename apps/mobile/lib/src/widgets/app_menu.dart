import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';
import 'app_icon.dart';

/// Пункт меню «⋯»: значок 18, подпись 17; неактивный — серый и не нажимается.
class AppMenuItem<T> {
  const AppMenuItem(this.value, this.icon, this.label, {this.enabled = true});

  final T value;
  final String icon;
  final String label;
  final bool enabled;
}

// Ширина меню (`Tool tip` «Редактирование - Пассажиры есть») — 307, строка — 46; в шкале размеров этих ступеней нет.
const _menuWidth = 307.0;
const _rowHeight = 46.0;

/// Меню «⋯» по кадру «Редактирование - Пассажиры есть»: выпадает **под** кнопкой [anchorContext] (кнопка и заголовок остаются видны),
/// правым краем по полю 16; ширина 307, строки 46 с разделителями `border.default`, текст целиком.
/// Нажатие вне меню — в том числе на ту же «⋯» — меню закрывает (это делает подложка меню).
Future<T?> showAppMenu<T>(BuildContext anchorContext, List<AppMenuItem<T>> items) {
  final anchor = anchorContext.findRenderObject()! as RenderBox;
  final overlay = Navigator.of(anchorContext).overlay!.context.findRenderObject()! as RenderBox;
  final bottomLeft = anchor.localToGlobal(anchor.size.bottomLeft(Offset.zero), ancestor: overlay);
  return showMenu<T>(
    context: anchorContext,
    position: RelativeRect.fromLTRB(bottomLeft.dx, bottomLeft.dy, AppSize.pad16, overlay.size.height - bottomLeft.dy),
    constraints: const BoxConstraints.tightFor(width: _menuWidth),
    menuPadding: EdgeInsets.zero,
    color: AppColors.bgSurface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSize.radius12),
      side: const BorderSide(color: AppColors.bgScreen, width: AppSize.stroke1),
    ),
    items: [
      for (var i = 0; i < items.length; i++)
        PopupMenuItem<T>(
          value: items[i].value,
          enabled: items[i].enabled,
          height: _rowHeight,
          padding: EdgeInsets.zero,
          child: _Row(item: items[i], divider: i < items.length - 1),
        ),
    ],
  );
}

class _Row<T> extends StatelessWidget {
  const _Row({required this.item, required this.divider});

  final AppMenuItem<T> item;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final color = item.enabled ? AppColors.textPrimary : AppColors.textTertiary;
    return Container(
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSize.pad12),
      decoration: divider
          ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1)))
          : null,
      child: Row(
        children: [
          AppIcon(item.icon, size: AppSize.icon18, color: color),
          const SizedBox(width: AppSize.gap8),
          Expanded(child: Text(item.label, style: AppType.body1.copyWith(color: color))),
        ],
      ),
    );
  }
}
