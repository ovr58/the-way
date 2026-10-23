import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_routes.dart';
import '../../app/search_key.dart';
import '../../app/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_size.dart';
import '../../theme/app_type.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_loading.dart';
import '../auth/widgets/cta_bar.dart';
import 'data/city_repository.dart';
import 'widgets/leading_icon_header.dart';

// Промежуток 24 макета («Выбор города»), в шкале `AppSize` его нет.
const double _gap24 = 24;

/// Выбор города («Выбор города»): поиск, список по буквам, «Моего города нет в списке».
/// «Далее» кладёт город в сессию (`pendingCityId`) и открывает вход.
class CityScreen extends StatefulWidget {
  const CityScreen({super.key});

  @override
  State<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends State<CityScreen> {
  final _search = TextEditingController();
  Future<List<City>>? _cities;
  City? _selected;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cities ??= CityRepository(AppSession.of(context).api).all();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    final future = CityRepository(AppSession.of(context).api).all();
    setState(() {
      _cities = future;
    });
  }

  void _onChanged(String text) {
    setState(() {
      if (_selected != null && text != _selected!.name) _selected = null;
    });
  }

  void _pick(City city) {
    FocusScope.of(context).unfocus();
    _search.text = city.name;
    setState(() => _selected = city);
  }

  void _next() {
    AppSession.of(context).pendingCityId = _selected!.id;
    Navigator.of(context).pushNamed(AppRoutes.auth);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          LeadingIconHeader(title: l10n.cityTitle),
          Expanded(
            child: FutureBuilder<List<City>>(
              future: _cities,
              builder: (context, snapshot) {
                if (snapshot.hasError) return AppErrorView(onRetry: _reload);
                if (!snapshot.hasData) return const AppLoading();
                return _Body(
                  cities: snapshot.data!,
                  controller: _search,
                  selected: _selected,
                  onChanged: _onChanged,
                  onPick: _pick,
                );
              },
            ),
          ),
          ListenableBuilder(listenable: _search, builder: (context, _) => _bottom(l10n)),
        ],
      ),
    );
  }

  /// Нижняя панель: город выбран — «Далее» («Выбор города»); текст набран, город не выбран —
  /// «Моего города нет в списке» и неактивное «Продолжить» («Выбор города»); иначе панели нет («Выбор города»).
  Widget _bottom(AppLocalizations l10n) {
    if (_selected != null) {
      return CtaBar(children: [CtaButton(label: l10n.cityNext, onPressed: _next)]);
    }
    if (_search.text.isEmpty) return const SizedBox.shrink();
    return CtaBar(
      children: [
        AppButton(
          label: l10n.cityNotInList,
          kind: AppButtonKind.outline,
          size: AppButtonSize.medium,
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.stub),
        ),
        AppButton(label: l10n.cityContinue, kind: AppButtonKind.neutral, size: AppButtonSize.medium, onPressed: null),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.cities,
    required this.controller,
    required this.selected,
    required this.onChanged,
    required this.onPick,
  });

  final List<City> cities;
  final TextEditingController controller;
  final City? selected;
  final ValueChanged<String> onChanged;
  final ValueChanged<City> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSize.pad16, AppSize.pad16, AppSize.pad16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.cityHint, style: AppType.body2.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: _gap24),
          _SearchField(controller: controller, hint: l10n.citySearch, onChanged: onChanged),
          const SizedBox(height: _gap24),
          if (selected == null)
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => _CityList(cities: _filter(controller.text), onPick: onPick),
              ),
            ),
        ],
      ),
    );
  }

  /// Вхождение по ключу поиска (кириллица и латиница); сначала начинающиеся с запроса.
  List<City> _filter(String query) =>
      prefixFirst(query, cities.where((city) => matchesSearch(query, city.name)), (City c) => c.name);
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Focus(
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return Container(
            height: AppSize.height48,
            padding: const EdgeInsets.symmetric(horizontal: AppSize.pad8),
            decoration: BoxDecoration(
              border: Border.all(color: focused ? AppColors.accentPrimary : AppColors.borderDefault, width: AppSize.stroke1),
            ),
            child: Row(
              children: [
                const AppIcon('system_magnifer', size: AppSize.icon20, color: AppColors.textSecondary),
                const SizedBox(width: AppSize.gap8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    style: AppType.body2.copyWith(color: AppColors.textPrimary),
                    cursorColor: AppColors.accentPrimary,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: hint,
                      hintStyle: AppType.body2.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => controller.text.isEmpty
                      ? const SizedBox.shrink()
                      : InkWell(
                          onTap: () {
                            controller.clear();
                            onChanged('');
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(AppSize.pad8),
                            child: AppIcon('essentional_close_circle', size: AppSize.icon18, color: AppColors.textTertiary),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Список городов, сгруппированный по первой букве.
class _CityList extends StatelessWidget {
  const _CityList({required this.cities, required this.onPick});

  final List<City> cities;
  final ValueChanged<City> onPick;

  @override
  Widget build(BuildContext context) {
    if (cities.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Align(
        alignment: Alignment.topLeft,
        child: Text(l10n.searchCityNothing, style: AppType.body2.copyWith(color: AppColors.textSecondary)),
      );
    }
    final rows = <Object>[];
    String? letter;
    for (final city in cities) {
      final first = city.name.isEmpty ? '' : city.name[0].toUpperCase();
      if (first != letter) {
        letter = first;
        rows.add(first);
      }
      rows.add(city);
    }
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.bgSurface, borderRadius: BorderRadius.circular(AppSize.radius12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSize.radius12),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16, vertical: AppSize.pad8),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            if (row is String) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(top: AppSize.pad8, bottom: AppSize.pad4),
                  padding: const EdgeInsets.symmetric(horizontal: AppSize.pad12, vertical: AppSize.pad4),
                  decoration: BoxDecoration(color: AppColors.bgControl, borderRadius: BorderRadius.circular(AppSize.radius12)),
                  child: Text(row, style: AppType.titlesFootnote.copyWith(color: AppColors.textPrimary)),
                ),
              );
            }
            final city = row as City;
            return InkWell(
              key: ValueKey('city_${city.id}'),
              onTap: () => onPick(city),
              child: Container(
                constraints: const BoxConstraints(minHeight: AppSize.height48),
                alignment: Alignment.centerLeft,
                child: Text(city.name, style: AppType.body1.copyWith(color: AppColors.textPrimary)),
              ),
            );
          },
        ),
      ),
    );
  }
}
