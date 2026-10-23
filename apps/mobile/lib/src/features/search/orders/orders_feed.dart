import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/updates_watcher.dart';
import '../../../theme/app_size.dart';
import '../../../widgets/app_empty.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/app_loading.dart';
import '../search_images.dart';
import 'order_card_view.dart';

/// Лента «Заказы пассажиров» в режиме водителя: карточки в порядке сервера (выезд ↑); пусто —
/// раскладка «Базовые экраны - Поездок нет» с текстами заказов. Запрос и фильтр держит экран ленты.
class OrdersFeed extends StatelessWidget {
  const OrdersFeed({super.key, required this.orders, required this.onReload, required this.onTap});

  final Future<List<OrderCard>>? orders;

  /// Перечитать ленту (повтор после ошибки, жест «потянуть»); возвращает новый запрос.
  final Future<List<OrderCard>>? Function() onReload;
  final ValueChanged<OrderCard> onTap;

  // Промежуток между карточками — как в ленте поездок «Базовые экраны - Поездки есть» (14; такой ступени в шкале нет).
  static const _cardGap = 14.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<OrderCard>>(
      future: orders,
      builder: (context, snapshot) {
        if (snapshot.hasError) return AppErrorView(onRetry: onReload);
        final list = snapshot.data;
        if (list == null) return const AppLoading();
        if (list.isEmpty) {
          return AppEmpty(
            title: l10n.driverOrdersEmptyTitle,
            subtitle: l10n.driverOrdersEmptySubtitle,
            imageAsset: searchEmptyImage,
          );
        }
        return RefreshIndicator(
          // Ручное обновление — та же проверка событий, что таймер оболочки, и сброс таймера.
          // Сначала проверка событий: её конец — тик, он перечитывает ленту; жест присоединяется к тому же
          // запросу ленты (без дубля).
          onRefresh: () async {
            await refreshUpdates();
            await onReload();
          },
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: AppSize.pad16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: _cardGap),
            itemBuilder: (context, i) => OrderCardView(
              key: Key('order_card_${list[i].id}'),
              order: list[i],
              onTap: () => onTap(list[i]),
            ),
          ),
        );
      },
    );
  }
}
