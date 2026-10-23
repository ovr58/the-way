import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_icon.dart';

/// Лист выбора из списка с поиском («Добавление нового ТС»): заголовок, строка поиска, строки-варианты.
/// Возвращает выбранный вариант; `null` — лист закрыт без выбора. [groupByLetter] — варианты по
/// алфавиту под буквой первой буквы названия (марки, «Добавление нового ТС»). [otherLabel] и [other] — строка под списком
/// для варианта не из списка (модель): [other] получает набранный запрос и возвращает вариант.
Future<T?> pickFromList<T>(
  BuildContext context, {
  required String title,
  required String searchHint,
  required List<T> Function(String query) search,
  required String Function(T item) label,
  String? icon,
  bool groupByLetter = false,
  String? otherLabel,
  Future<T?> Function(String query)? other,
}) => AppBottomSheet.show<T>(
  context,
  title: title,
  child: _PickBody<T>(
    searchHint: searchHint,
    search: search,
    label: label,
    icon: icon,
    groupByLetter: groupByLetter,
    otherLabel: otherLabel,
    other: other,
  ),
);

class _PickBody<T> extends StatefulWidget {
  const _PickBody({
    required this.searchHint,
    required this.search,
    required this.label,
    this.icon,
    required this.groupByLetter,
    this.otherLabel,
    this.other,
  });

  final String searchHint;
  final List<T> Function(String query) search;
  final String Function(T item) label;
  final String? icon;
  final bool groupByLetter;
  final String? otherLabel;
  final Future<T?> Function(String query)? other;

  @override
  State<_PickBody<T>> createState() => _PickBodyState<T>();
}

class _PickBodyState<T> extends State<_PickBody<T>> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _other() async {
    final item = await widget.other!(_controller.text.trim());
    if (item != null && mounted) Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    var items = widget.search(_controller.text);
    if (widget.groupByLetter) {
      items = [...items]..sort((a, b) => widget.label(a).toLowerCase().compareTo(widget.label(b).toLowerCase()));
    }
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * _heightFactor,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSize.pad8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderDefault, width: AppSize.stroke1),
                borderRadius: BorderRadius.circular(AppSize.radius8),
              ),
              child: Row(
                children: [
                  const AppIcon('system_magnifer', size: AppSize.icon20, color: AppColors.textSecondary),
                  const SizedBox(width: AppSize.gap8),
                  Expanded(
                    child: TextField(
                      key: const Key('cars-search'),
                      controller: _controller,
                      onChanged: (_) => setState(() {}),
                      style: AppType.body2.copyWith(color: AppColors.textPrimary),
                      cursorColor: AppColors.accentPrimary,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: widget.searchHint,
                        hintStyle: AppType.body2.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    InkWell(
                      onTap: () => setState(_controller.clear),
                      child: const AppIcon(
                        'essentional_close_circle',
                        size: AppSize.icon18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSize.gap16),
            Expanded(
              child: items.isEmpty
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Text(l10n.carsNothingFound, style: AppType.body2.copyWith(color: AppColors.textSecondary)),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final letter = _letter(items, i);
                        final row = InkWell(
                          onTap: () => Navigator.of(context).pop(items[i]),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: AppSize.height48),
                            alignment: Alignment.centerLeft,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppColors.borderDefault, width: AppSize.stroke1),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (widget.icon != null) ...[
                                  AppIcon(widget.icon!, size: AppSize.icon20),
                                  const SizedBox(width: AppSize.gap8),
                                ],
                                Expanded(
                                  child: Text(
                                    widget.label(items[i]),
                                    style: AppType.body2.copyWith(color: AppColors.borderStrong),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        if (letter == null) return row;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: AppSize.pad16, bottom: AppSize.pad8),
                              child: Text(
                                letter,
                                key: Key('cars-letter-$letter'),
                                style: AppType.body1.copyWith(color: AppColors.borderStrong),
                              ),
                            ),
                            row,
                          ],
                        );
                      },
                    ),
            ),
            if (widget.other != null && widget.otherLabel != null)
              InkWell(
                onTap: _other,
                child: Container(
                  constraints: const BoxConstraints(minHeight: AppSize.height48),
                  alignment: Alignment.centerLeft,
                  child: Text(widget.otherLabel!, style: AppType.body2.copyWith(color: AppColors.accentPrimary)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Буква-заголовок группы над строкой [i]: только у первой строки с этой буквой.
  String? _letter(List<T> items, int i) {
    if (!widget.groupByLetter) return null;
    String first(T item) => widget.label(item).substring(0, 1).toUpperCase();
    return i == 0 || first(items[i - 1]) != first(items[i]) ? first(items[i]) : null;
  }

  // Лист в кадре занимает 655 из 812.
  static const _heightFactor = 0.6;
}
