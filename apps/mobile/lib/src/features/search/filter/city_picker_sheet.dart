import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/session.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_input.dart';
import '../../../widgets/app_list_item.dart';
import '../../../widgets/app_loading.dart';
import '../data/search_repository.dart';

/// Шторка выбора города («Откуда / Куда», фильтр «Фильтр»): поиск `GET /cities?q`, строки
/// «город, регион». Возвращает выбранный [City] или `null`.
Future<City?> showFilterCityPicker(BuildContext context, {required String title}) {
  final repo = SearchRepository(AppSession.of(context).api);
  return AppBottomSheet.show<City>(
    context,
    title: title,
    child: _CityPicker(repository: repo),
  );
}

class _CityPicker extends StatefulWidget {
  const _CityPicker({required this.repository});

  final SearchRepository repository;

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  static const _debounce = Duration(milliseconds: 300);

  Timer? _timer;
  int _seq = 0;
  List<City>? _cities;
  bool _failed = false;

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

  void _changed(String q) {
    _timer?.cancel();
    _timer = Timer(_debounce, () => _load(q.trim()));
  }

  /// Последний запрос побеждает: ответ устаревшего запроса отбрасывается.
  Future<void> _load(String q) async {
    final seq = ++_seq;
    try {
      final cities = await widget.repository.cities(q);
      if (!mounted || seq != _seq) return;
      setState(() {
        _cities = cities;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final height = (media.size.height - media.viewInsets.bottom) * 0.6;
    final cities = _cities;
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            AppInput(
              label: l10n.searchCityPlaceholder,
              autofocus: true,
              onChanged: _changed,
            ),
            Expanded(
              child: cities == null
                  ? (_failed ? const SizedBox.shrink() : const AppLoading())
                  : cities.isEmpty
                      ? Center(
                          child: Text(
                            l10n.searchCityNothing,
                            style: AppType.body2.copyWith(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: cities.length,
                          itemBuilder: (context, i) {
                            final c = cities[i];
                            return AppListItem(
                              title: l10n.searchCityLine(c.name, c.region),
                              onTap: () => Navigator.of(context).pop(c),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
