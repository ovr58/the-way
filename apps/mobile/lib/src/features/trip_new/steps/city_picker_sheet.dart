import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_input.dart';
import '../../../widgets/app_list_item.dart';
import '../../../widgets/app_loading.dart';
import '../data/trip_new_repository.dart';

/// Выбор города из справочника: нижний лист с поиском `GET /cities?q`. Возвращает город
/// или `null`, если лист закрыли.
Future<City?> showCityPicker(BuildContext context, TripNewRepository repository) =>
    AppBottomSheet.show<City>(
      context,
      title: AppLocalizations.of(context).tripNewCityPickerTitle,
      child: CityPickerSheet(repository: repository),
    );

class CityPickerSheet extends StatefulWidget {
  const CityPickerSheet({super.key, required this.repository});

  final TripNewRepository repository;

  @override
  State<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<CityPickerSheet> {
  // Пауза перед запросом поиска, мс.
  static const _debounce = Duration(milliseconds: 300);
  // Высота списка в листе; в шкале такой ступени нет.
  static const _listHeight = 360.0;

  Timer? _timer;
  List<City>? _cities;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load(String q) async {
    final seq = ++_seq;
    List<City> found;
    try {
      found = await widget.repository.cities(q);
    } catch (_) {
      found = const [];
    }
    if (!mounted || seq != _seq) return;
    setState(() => _cities = found);
  }

  void _onChanged(String q) {
    _timer?.cancel();
    _timer = Timer(_debounce, () => _load(q.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cities = _cities;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppInput(label: l10n.tripNewCitySearch, onChanged: _onChanged),
          const SizedBox(height: AppSize.gap8),
          SizedBox(
            height: _listHeight,
            child: cities == null
                ? const AppLoading()
                : cities.isEmpty
                    ? Center(
                        child: Text(
                          l10n.tripNewCityEmpty,
                          style: AppType.body2.copyWith(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: cities.length,
                        itemBuilder: (context, i) => AppListItem(
                          title: cities[i].name,
                          subtitle: cities[i].region,
                          onTap: () => Navigator.of(context).pop(cities[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
