import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_size.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_input.dart';

/// Длина названия «Другой модели» — как у сервера (`CarInput.model`, `@MaxLength(40)`).
const otherModelMaxLength = 40;

/// «Другая модель»: лист со свободным вводом названия, 1–40 символов. [initial] — запрос,
/// набранный в поиске. Возвращает название без крайних пробелов или `null`, если лист закрыли.
Future<String?> showOtherModelSheet(BuildContext context, {String initial = ''}) => AppBottomSheet.show<String>(
      context,
      title: AppLocalizations.of(context).carsOtherModel,
      child: _OtherModelBody(initial: initial),
    );

class _OtherModelBody extends StatefulWidget {
  const _OtherModelBody({required this.initial});

  final String initial;

  @override
  State<_OtherModelBody> createState() => _OtherModelBodyState();
}

class _OtherModelBodyState extends State<_OtherModelBody> {
  late final _controller = TextEditingController(
    text: widget.initial.length > otherModelMaxLength ? widget.initial.substring(0, otherModelMaxLength) : widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = _controller.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInput(
            key: const Key('cars-other-model'),
            label: l10n.carsOtherModelName,
            controller: _controller,
            maxLength: otherModelMaxLength,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSize.gap16),
          AppButton(
            label: l10n.carsOtherModelDone,
            onPressed: name.isEmpty ? null : () => Navigator.of(context).pop(name),
          ),
        ],
      ),
    );
  }
}
