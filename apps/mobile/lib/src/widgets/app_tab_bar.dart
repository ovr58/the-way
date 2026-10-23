import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';
import 'app_icon.dart';

/// Экран с нижней панелью («Базовые экраны - Поездки есть»): панель [AppTabBar] и приподнятая над ней зелёная «+» —
/// плавающая кнопка Scaffold, чтобы выступающая над панелью часть принимала нажатия
/// (дочерний виджет не получает касаний за границами родителя). Что делает «+» в режиме водителя
/// и пассажира — решает оболочка.
class AppTabScaffold extends StatelessWidget {
  const AppTabScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.onTap,
    required this.onCreate,
  });

  final Widget body;

  /// Выбранная вкладка: 0 «Поездки», 1 «Мои заказы», 2 «Чаты», 3 «Профиль».
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: body,
        bottomNavigationBar: AppTabBar(currentIndex: currentIndex, onTap: onTap),
        floatingActionButton: _CreateButton(onTap: onCreate),
        floatingActionButtonLocation: const _RaisedCenterLocation(),
        floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      );
}

/// Центр экрана по горизонтали, верх кнопки на 8 выше верха панели (кадр «Базовые экраны - Поездки есть»: кнопка 48 в панели 48
/// начинается с отступа 8 от низа и выступает над верхом).
class _RaisedCenterLocation extends FloatingActionButtonLocation {
  const _RaisedCenterLocation();

  // Подъём над верхом панели в кадре — 8.
  static const _raise = 8.0;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) => Offset(
        (geometry.scaffoldSize.width - geometry.floatingActionButtonSize.width) / 2,
        geometry.contentBottom - _raise,
      );
}

/// Нижняя панель из компонента `Tab Bar`: «Поездки · Мои заказы · [место под «+»] · Чаты · Профиль»
/// на всех экранах. Саму «+» рисует [AppTabScaffold].
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.currentIndex, required this.onTap});

  /// Выбранная вкладка: 0 «Поездки», 1 «Мои заказы», 2 «Чаты», 3 «Профиль».
  final int currentIndex;
  final ValueChanged<int> onTap;

  // Подпись вкладки в кадре — 10 (Gilroy 500); такой ступени в токенах типографики нет.
  static const _titleSize = 10.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: AppColors.bgScreen,
      // Линия поверх содержимого, а не в расчёте высоты: в кадре обводка внутри блока.
      foregroundDecoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1)),
      ),
      child: SafeArea(
        top: false,
        // Высота «Tabs» в кадре — 48, плюс системный отступ снизу (индикатор жеста).
        child: SizedBox(
          height: AppSize.height48,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Tab(icon: 'system_car', label: l10n.shellTabTrips, selected: currentIndex == 0, onTap: () => onTap(0)),
              _Tab(icon: 'system_box', label: l10n.shellTabOrders, selected: currentIndex == 1, onTap: () => onTap(1)),
              const SizedBox(width: AppSize.height48),
              _Tab(icon: 'messages_dialog_2', label: l10n.shellTabChats, selected: currentIndex == 2, onTap: () => onTap(2)),
              _Tab(icon: 'users_user_circle', label: l10n.shellTabProfile, selected: currentIndex == 3, onTap: () => onTap(3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.icon, required this.label, required this.selected, required this.onTap});

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        // Зона нажатия — вся высота панели 48; значок с подписью (34) прижаты вниз с отступом 8.
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSize.pad8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppIcon(icon, color: color),
              const SizedBox(height: AppSize.gap2),
              Text(label, maxLines: 1, style: AppType.button3.copyWith(fontSize: AppTabBar._titleSize, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('tab_create'),
      color: AppColors.accentPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.radius12),
        side: const BorderSide(color: AppColors.bgScreen, width: AppSize.stroke3),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSize.radius12),
        onTap: onTap,
        child: const SizedBox(
          width: AppSize.height48,
          height: AppSize.height48,
          child: Center(child: AppIcon('essentional_add', size: AppSize.icon16, color: AppColors.textOnAccent)),
        ),
      ),
    );
  }
}
