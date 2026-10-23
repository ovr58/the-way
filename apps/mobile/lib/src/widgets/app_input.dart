import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';
import '../theme/app_type.dart';

/// Поле ввода из компонента `Input` («Вход - Ввод номера (номер введён)», «Вход - Базовый экран», «Создание профиля - Данные заполнены», «Добавление нового ТС»): рамка 1, поля 8/12, высота от 52, строка
/// ошибки под рамкой. Пока значения нет и поле не в фокусе — подпись внутри как подсказка (15, серая);
/// с значением или в фокусе — подпись 12 над значением, а в фокусе ещё и рамка `border.strong`.
/// Рамка — как в спецификации (без скругления).
class AppInput extends StatefulWidget {
  const AppInput({
    super.key,
    required this.label,
    this.controller,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.suffix,
    this.errorText,
    this.hintText,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
  });

  /// Подпись: пока значения нет — подсказка внутри поля, с значением — маленькая над ним.
  final String label;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// Для полей-выборов (дата, город): поле только читает, нажатие открывает выбор.
  final VoidCallback? onTap;
  final bool readOnly;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? maxLength;
  final Widget? suffix;
  final String? errorText;

  /// Пример значения: виден в пустом поле в фокусе, под подписью.
  final String? hintText;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Для полей имени — `TextCapitalization.words`; остальные поля не меняются.
  final TextCapitalization textCapitalization;

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  late TextEditingController _controller;
  late FocusNode _focus;
  bool _ownsController = false;
  bool _ownsFocus = false;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _ownsFocus = widget.focusNode == null;
    _focus = widget.focusNode ?? FocusNode();
    _controller.addListener(_changed);
    _focus.addListener(_changed);
  }

  void _detach() {
    _controller.removeListener(_changed);
    _focus.removeListener(_changed);
    if (_ownsController) _controller.dispose();
    if (_ownsFocus) _focus.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(AppInput old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller || old.focusNode != widget.focusNode) {
      _detach();
      _attach();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    // Поля-выборы (дата, город) только читают: фокус им не нужен ни для подписи, ни для рамки.
    final editable = !widget.readOnly && widget.onTap == null && widget.enabled;
    final focused = editable && _focus.hasFocus;
    final floating = focused || _controller.text.isNotEmpty;
    final borderColor = hasError
        ? AppColors.statusError
        : focused
            ? AppColors.borderStrong
            : AppColors.borderDefault;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSize.pad12, vertical: AppSize.pad8),
          // Рамка поверх содержимого, а не в расчёте размера: в кадре обводка внутри блока 52.
          foregroundDecoration: BoxDecoration(border: Border.all(color: borderColor, width: AppSize.stroke1)),
          child: Row(
            children: [
              Expanded(
                // Подпись рисуем сами, а не `InputDecoration.labelText`: у Material плавающая подпись
                // на 25% мельче кадровой (12) и сидит в поле минимальной высоты 48 — налезает на значение.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (floating)
                      Text(
                        widget.label,
                        style: AppType.bodyCaption1.copyWith(color: focused ? AppColors.textPrimary : AppColors.textSecondary),
                      )
                    else
                      const SizedBox.shrink(),
                    TextField(
                      controller: _controller,
                      focusNode: _focus,
                      onChanged: widget.onChanged,
                      onTap: widget.onTap,
                      readOnly: widget.readOnly || widget.onTap != null,
                      enabled: widget.enabled,
                      autofocus: widget.autofocus,
                      keyboardType: widget.keyboardType,
                      textCapitalization: widget.textCapitalization,
                      inputFormatters: widget.inputFormatters,
                      maxLines: widget.maxLines,
                      maxLength: widget.maxLength,
                      style: AppType.body2.copyWith(color: AppColors.textPrimary),
                      cursorColor: AppColors.accentPrimary,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        counterText: '',
                        hintText: floating ? widget.hintText : widget.label,
                        hintStyle: AppType.body2.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.suffix != null) ...[const SizedBox(width: AppSize.gap4), widget.suffix!],
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSize.pad2),
            child: Text(widget.errorText!, style: AppType.bodyCaption1.copyWith(color: AppColors.statusError)),
          ),
      ],
    );
  }
}
