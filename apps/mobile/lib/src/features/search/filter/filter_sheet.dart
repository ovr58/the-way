import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/app_input.dart';
import '../../../widgets/app_switch.dart';
import '../data/search_filter.dart';
import '../segmented_tabs.dart';
import 'city_picker_sheet.dart';

/// Аргументы маршрута `search/filter`: текущий фильтр и доступность «Поблизости».
class SearchFilterArgs {
  const SearchFilterArgs({required this.filter, required this.nearAvailable});

  final SearchFilter filter;
  final bool nearAvailable;
}

/// Показывает шторку фильтра («Фильтр») под именем маршрута `search/filter`; результат — новый
/// фильтр или `null`, если шторку закрыли.
Future<SearchFilter?> showFilterSheet(
  BuildContext context, {
  required SearchFilter filter,
  required bool nearAvailable,
}) =>
    showModalBottomSheet<SearchFilter>(
      context: context,
      routeSettings: RouteSettings(
        name: AppRoutes.searchFilter,
        arguments: SearchFilterArgs(filter: filter, nearAvailable: nearAvailable),
      ),
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.overlayScrim,
      builder: (_) => FilterSheet(initial: filter, nearAvailable: nearAvailable),
    );

/// Страница маршрута `search/filter`, открытого через `pushNamed`: та же шторка над затемнением.
class FilterPage extends StatelessWidget {
  const FilterPage({super.key, required this.args});

  final SearchFilterArgs args;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.overlayScrim,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: FilterSheet(initial: args.filter, nearAvailable: args.nearAvailable),
        ),
      );
}

/// Шторка «Фильтры»: «Маршрут» (Откуда / Куда), «Поблизости (30 км)», «Поездки / Посылки»,
/// «Очистить» и «Применить». Два последних — добавки к кадрам (`docs/DESIGN_CHANGES.md`, № 6).
class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.initial, required this.nearAvailable});

  final SearchFilter initial;

  /// Есть ли координаты клиента; без них «Поблизости» неактивен (отказ в геолокации).
  final bool nearAvailable;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late SearchFilter _draft = widget.initial;
  final _from = TextEditingController();
  final _to = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _sync() {
    _from.text = _draft.from?.name ?? '';
    _to.text = _draft.to?.name ?? '';
  }

  void _set(SearchFilter filter) {
    setState(() => _draft = filter);
    _sync();
  }

  Future<void> _pickCity({required bool from}) async {
    final l10n = AppLocalizations.of(context);
    final city = await showFilterCityPicker(
      context,
      title: from ? l10n.searchFilterFrom : l10n.searchFilterTo,
    );
    if (city == null || !mounted) return;
    _set(from ? _draft.copyWith(from: city) : _draft.copyWith(to: city));
  }

  Widget _clearIcon(VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: const AppIcon('essentional_close', size: AppSize.icon20),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = _draft.isActive;
    return AppBottomSheet(
      title: l10n.searchFilterTitle,
      trailing: InkWell(
        key: const Key('filter_clear'),
        onTap: () => _set(SearchFilter.empty),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSize.pad8),
          child: Text(
            l10n.searchFilterClear,
            style: AppType.bodyFootnote.copyWith(
              color: active ? AppColors.textDanger : AppColors.textDisabled,
            ),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.searchFilterRoute,
            style: AppType.titlesFootnote.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSize.gap8),
          AppInput(
            key: const Key('filter_from'),
            label: l10n.searchFilterFrom,
            controller: _from,
            onTap: () => _pickCity(from: true),
            suffix: _draft.from == null ? null : _clearIcon(() => _set(_draft.copyWith(clearFrom: true))),
          ),
          const SizedBox(height: AppSize.gap8),
          AppInput(
            key: const Key('filter_to'),
            label: l10n.searchFilterTo,
            controller: _to,
            onTap: () => _pickCity(from: false),
            suffix: _draft.to == null ? null : _clearIcon(() => _set(_draft.copyWith(clearTo: true))),
          ),
          const SizedBox(height: AppSize.gap16),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.searchFilterNear,
                  style: AppType.body2.copyWith(color: AppColors.textPrimary),
                ),
              ),
              AppSwitch(
                key: const Key('filter_near'),
                value: widget.nearAvailable && _draft.near,
                onChanged: widget.nearAvailable ? (v) => _set(_draft.copyWith(near: v)) : null,
              ),
            ],
          ),
          if (!widget.nearAvailable)
            Padding(
              padding: const EdgeInsets.only(top: AppSize.pad4),
              child: Text(
                l10n.searchFilterNearUnavailable,
                style: AppType.bodyCaption1.copyWith(color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: AppSize.gap16),
          SegmentedTabs(
            labels: [l10n.searchFilterKindTrips, l10n.searchFilterKindParcels],
            index: _draft.kind == null ? null : (_draft.kind == TripKind.parcel ? 1 : 0),
            onChanged: (i) {
              final picked = i == 1 ? TripKind.parcel : TripKind.ride;
              _set(_draft.kind == picked ? _draft.copyWith(clearKind: true) : _draft.copyWith(kind: picked));
            },
          ),
          const SizedBox(height: AppSize.gap16),
          AppButton(
            key: const Key('filter_apply'),
            label: l10n.searchFilterApply,
            kind: active ? AppButtonKind.primary : AppButtonKind.neutral,
            onPressed: () => Navigator.of(context).pop(_draft),
          ),
        ],
      ),
    );
  }
}
