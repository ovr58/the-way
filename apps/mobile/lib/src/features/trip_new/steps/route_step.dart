import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/app_input.dart';
import '../../../widgets/app_list_item.dart';
import '../../../widgets/route_fields.dart';
import '../wizard_controller.dart';
import 'city_picker_sheet.dart';
import 'datetime_step.dart';
import 'extras_step.dart';
import 'price_step.dart';
import 'wizard_scaffold.dart';

/// Шаг 2 из 6 — маршрут, дата и время, прибытие, места («Новый заказ - Маршрут» – «Новый заказ - кол-во пассажиров», «Новый заказ - Заполнение даты» – «Новый заказ - Маршрут выбор 2 точки»): один экран.
class RouteStep extends StatefulWidget {
  const RouteStep({super.key, required this.controller});

  final WizardController controller;

  @override
  State<RouteStep> createState() => _RouteStepState();
}

class _RouteStepState extends State<RouteStep> {
  /// Поле адреса в фокусе: «Далее» прячется, чтобы не закрывать подсказки над клавиатурой.
  final _addressFocused = ValueNotifier<bool>(false);

  WizardController get controller => widget.controller;

  @override
  void dispose() {
    _addressFocused.dispose();
    super.dispose();
  }

  /// Поездка — к цене (шаг 3 из 6), заказ пассажира — к услугам (шаг 3 из 3): цены и авто у заказа нет.
  void _next(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => controller.passengerOrder ? ExtrasStep(controller: controller) : PriceStep(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([controller, _addressFocused]),
      builder: (context, _) => WizardScaffold(
        step: 2,
        order: controller.passengerOrder,
        hideBottom: _addressFocused.value,
        dismissKeyboardOnDrag: false,
        body: [
          RouteBlock(
            controller: controller,
            addressFocused: _addressFocused,
            // В кадрах заказа «Новый заказ - Маршрут», «Новый заказ - кол-во пассажиров» «Моих сохранённых маршрутов» нет; шаблоны — маршруты водителя.
            showTemplates: !controller.passengerOrder,
            below: [
              DepartureBlock(controller: controller),
              ArrivalBlock(controller: controller),
              if (controller.kind == TripKind.ride) SeatsBlock(controller: controller),
            ],
          ),
        ],
        bottom: AppButton(
          label: l10n.tripNewNext,
          onPressed: controller.routeStepComplete ? () => _next(context) : null,
        ),
      ),
    );
  }
}

class _StopField {
  _StopField(String text) : text = TextEditingController(text: text);

  final TextEditingController text;
  final FocusNode node = FocusNode();

  void dispose() {
    text.dispose();
    node.dispose();
  }
}

/// Блок «Маршрут» экрана «Новый заказ - Маршрут»: поля «Откуда / Точки посадки / Куда» с подсказками адреса, кнопка
/// «Добавить остановку». Подсказки — прямо под полем ввода. Блоки [below] стоят под ним; «Мои
/// сохранённые маршруты» — в самом низу, пока подсказки не показаны.
class RouteBlock extends StatefulWidget {
  const RouteBlock({
    super.key,
    required this.controller,
    this.below = const [],
    this.showTemplates = true,
    this.addressFocused,
  });

  final WizardController controller;

  /// Сообщает экрану, что поле адреса в фокусе (идёт ввод и показ подсказок).
  final ValueNotifier<bool>? addressFocused;
  final List<Widget> below;
  final bool showTemplates;

  @override
  State<RouteBlock> createState() => _RouteBlockState();
}

class _RouteBlockState extends State<RouteBlock> {
  // Подсказки: пауза после ввода и наименьшая длина запроса.
  static const _debounce = Duration(milliseconds: 400);
  static const _minQuery = 3;

  final List<_StopField> _fields = [];
  final _panelKey = GlobalKey();
  Timer? _timer;
  int _seq = 0;
  int? _active;

  /// Текст активного поля правили после того, как оно получило фокус: панель подсказок — только тогда.
  /// Курсор в уже заполненном поле (выбранный адрес, сохранённый маршрут) панель не открывает.
  bool _edited = false;

  /// Где началось нажатие вне полей: касание без сдвига снимает фокус, прокрутка — нет (п. 5).
  Offset? _tapDownOutside;
  List<GeoSuggestion> _suggestions = const [];
  List<RouteTemplate> _templates = const [];

  WizardController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onController);
    _sync();
    if (widget.showTemplates) _loadTemplates();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.removeListener(_onController);
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      final found = await _c.repository.templates();
      if (mounted) setState(() => _templates = found);
    } catch (_) {
      // Шаблоны необязательны: без них блок просто не показывается.
    }
  }

  void _onController() {
    if (!mounted) return;
    setState(_sync);
  }

  /// Поля ввода следуют за черновиком: число и текст.
  void _sync() {
    while (_fields.length < _c.stops.length) {
      final field = _StopField(_c.stops[_fields.length].displayAddress);
      field.node.addListener(() => _onFocus(field));
      _fields.add(field);
    }
    while (_fields.length > _c.stops.length) {
      _fields.removeLast().dispose();
    }
    for (var i = 0; i < _fields.length; i++) {
      final shown = _c.stops[i].displayAddress;
      if (_fields[i].text.text != shown) _fields[i].text.text = shown;
    }
  }

  void _onFocus(_StopField field) {
    if (!mounted) return;
    setState(() {
      final index = _fields.indexOf(field);
      if (field.node.hasFocus) {
        if (_active != index) {
          _suggestions = const [];
          _edited = false;
        }
        _active = index;
      } else if (_active == index) {
        _active = null;
        _edited = false;
      }
      widget.addressFocused?.value = _active != null;
    });
  }

  void _onChanged(int index, String text) {
    _c.setStopText(index, text);
    _edited = true;
    _timer?.cancel();
    if (text.trim().length < _minQuery) {
      setState(() => _suggestions = const []);
      return;
    }
    _timer = Timer(_debounce, () => _suggest(text.trim()));
  }

  Future<void> _suggest(String q) async {
    final seq = ++_seq;
    List<GeoSuggestion> found;
    try {
      found = await _c.repository.suggest(q, cityId: _c.homeCityId);
    } catch (_) {
      found = const [];
    }
    if (!mounted || seq != _seq) return;
    // Сервис карт отдаёт две фичи с одной подписью: одинаковые подписи склеиваются, первая остаётся.
    final seen = <String>{};
    setState(() => _suggestions = [for (final s in found) if (seen.add(s.label)) s]);
    // Подсказки под активным полем: показать их сколько влезет над клавиатурой, но поле ввода
    // не уводить за верх окна.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final panel = _panelKey.currentContext;
      if (panel == null || !panel.mounted) return;
      await Scrollable.ensureVisible(panel, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      final i = _active;
      final field = i == null || i >= _fields.length ? null : _fields[i].node.context;
      if (field == null || !field.mounted) return;
      await Scrollable.ensureVisible(field, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
    });
  }

  void _finishEdit(int index) {
    _fields[index].node.unfocus();
    setState(() => _suggestions = const []);
  }

  /// Фокус снят со всех полей маршрута, клавиатура закрыта, подсказки убраны (п. 4). Тот же путь снимает
  /// фокус после выбора сохранённого маршрута (п. 1): строка шаблона стоит вне `TapRegion` полей.
  void _blur() {
    _timer?.cancel();
    for (final f in _fields) {
      f.node.unfocus();
    }
    if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
  }

  Future<void> _pickCity(int index) async {
    final typed = _fields[index].text.text;
    final city = await showCityPicker(context, _c.repository);
    if (city == null || !mounted) return;
    _c.setStopFromCity(index, city, typed);
    _finishEdit(index);
  }

  void _clearOrRemove(int index) {
    if (index > 0 && index < _c.stops.length - 1) {
      _c.removeStop(index);
    } else {
      _c.setStopText(index, '');
      _fields[index].text.clear();
    }
  }

  String _label(AppLocalizations l10n, int index) {
    final last = _c.stops.length - 1;
    final empty = _c.stops[index].displayAddress.isEmpty;
    if (index == last) return empty ? l10n.tripNewTo : l10n.tripNewDestinationPoint;
    if (index > 0) return l10n.tripNewStopPoint; // промежуточная — «Остановка»
    return empty ? l10n.tripNewFrom : l10n.tripNewBoardingPoint;
  }

  bool get _panelActive {
    final i = _active;
    return i != null && _edited && i < _fields.length && _fields[i].text.text.trim().length >= _minQuery;
  }

  Widget _panel(AppLocalizations l10n) => _SuggestionPanel(
        key: _panelKey,
        suggestions: _suggestions,
        pickCityLabel: l10n.tripNewPickCity,
        onSuggestion: (s) {
          final index = _active ?? 0;
          _c.setStopFromSuggestion(index, s);
          _finishEdit(index);
        },
        onPickCity: () => _pickCity(_active ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final last = _c.stops.length - 1;
    final children = <Widget>[
      WizardSection(
        title: l10n.tripNewRouteTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Нажатие вне полей и подсказок снимает фокус (п. 4); сдвиг пальца — прокрутка, фокус остаётся.
            TapRegion(
              onTapOutside: (e) => _tapDownOutside = e.position,
              onTapUpOutside: (e) {
                final down = _tapDownOutside;
                _tapDownOutside = null;
                if (down != null && (e.position - down).distance <= kTouchSlop) _blur();
              },
              child: RouteFields(
                // Подсказки — прямо под полем, в котором идёт ввод.
                belowIndex: _active,
                below: _panelActive ? _panel(l10n) : null,
                fields: [
                  for (var i = 0; i <= last; i++)
                    AppInput(
                      key: ObjectKey(_fields[i]),
                      label: _label(l10n, i),
                      controller: _fields[i].text,
                      focusNode: _fields[i].node,
                      onChanged: (text) => _onChanged(i, text),
                      suffix: _fields[i].text.text.isEmpty && (i == 0 || i == last)
                          ? null
                          : GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _clearOrRemove(i),
                              child: const Padding(
                                padding: EdgeInsets.all(AppSize.pad8),
                                child: AppIcon('essentional_close', size: AppSize.icon18),
                              ),
                            ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSize.gap12),
            Align(
              alignment: Alignment.centerLeft,
              child: _AddStopButton(label: l10n.tripNewAddStop, onTap: _c.addStop),
            ),
          ],
        ),
      ),
      ...widget.below,
      if (widget.showTemplates && !_panelActive && _templates.isNotEmpty)
        WizardSection(
          title: l10n.tripNewSavedRoutes,
          child: Column(
            children: [
              for (final t in _templates)
                _TemplateRow(template: t, onTap: () => _c.applyTemplate(t)),
            ],
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSize.gap20),
          children[i],
        ],
      ],
    );
  }
}

/// Кнопка «Добавить остановку» (158×32, контур зелёный, радиус 8).
class _AddStopButton extends StatelessWidget {
  const _AddStopButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.radius8),
        side: const BorderSide(color: AppColors.accentPrimary, width: AppSize.stroke1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSize.radius8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSize.pad12, vertical: AppSize.pad8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon('essentional_add', size: AppSize.icon14, color: AppColors.accentPrimary),
              const SizedBox(width: AppSize.gap4),
              Text(label, style: AppType.button3.copyWith(color: AppColors.accentPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Подсказки адреса под полем ввода: адрес, второй строкой серым — область; под ними всегда
/// «Выбрать город из списка».
class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({
    super.key,
    required this.suggestions,
    required this.pickCityLabel,
    required this.onSuggestion,
    required this.onPickCity,
  });

  final List<GeoSuggestion> suggestions;
  final String pickCityLabel;
  final ValueChanged<GeoSuggestion> onSuggestion;
  final VoidCallback onPickCity;

  @override
  Widget build(BuildContext context) {
    return WizardCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final s in suggestions)
            AppListItem(
              title: s.label,
              // Вторая строка серым — область; у города, где она уже в названии, — без повтора.
              subtitle: s.place.region.isEmpty || s.label.contains(s.place.region) ? null : s.place.region,
              subtitleColor: AppColors.textSecondary,
              leading: const AppIcon('map_map_point', size: AppSize.icon20, color: AppColors.textSecondary),
              onTap: () => onSuggestion(s),
            ),
          AppListItem(
            title: pickCityLabel,
            leading: const AppIcon('system_magnifer', size: AppSize.icon20, color: AppColors.accentPrimary),
            onTap: onPickCity,
          ),
        ],
      ),
    );
  }
}

/// Сохранённый маршрут: «Минск → Брест» («Новый заказ - Маршрут выбор 1 точки» – «Новый заказ - Маршрут выбор 2 точки»).
class _TemplateRow extends StatelessWidget {
  const _TemplateRow({required this.template, required this.onTap});

  final RouteTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stops = template.stops;
    final title = '${stops.first.cityName} → ${stops.last.cityName}';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSize.pad8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSize.radius12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSize.pad12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSize.radius12),
            border: Border.all(color: AppColors.borderDefault, width: AppSize.stroke1),
          ),
          child: Row(
            children: [
              Container(
                width: AppSize.height32,
                height: AppSize.height32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.bgControl, shape: BoxShape.circle),
                child: const AppIcon('map_map_point', size: AppSize.icon20, color: AppColors.textSecondary),
              ),
              const SizedBox(width: AppSize.gap12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
