import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/session.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_radio.dart';
import '../data/trip_new_repository.dart';
import '../trip_new_args.dart';
import '../trip_new_images.dart';
import '../wizard_controller.dart';
import 'route_step.dart';
import 'wizard_scaffold.dart';

/// Шаг 1 из 6 (у заказа пассажира — из 3) — тип заказа («Новый заказ - Тип заказа»): «Автомобиль» → `ride`, «Посылка» →
/// `parcel`. Это и вход маршрута `trip_new`: здесь рождается черновик мастера.
class TypeStep extends StatefulWidget {
  const TypeStep({super.key, this.templateId, this.args, this.controller});

  /// Шаблон маршрута, с которого начинается мастер (`trip_new`, аргумент `templateId`).
  final String? templateId;

  /// Мастер заказа пассажира или отклик водителя новой поездкой (`trip_new`, аргумент [TripNewArgs]).
  final TripNewArgs? args;

  /// Готовый черновик (тесты); иначе создаётся из сессии.
  final WizardController? controller;

  @override
  State<TypeStep> createState() => _TypeStepState();
}

class _TypeStepState extends State<TypeStep> {
  WizardController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final given = widget.controller;
    if (given != null) {
      _controller = given;
      return;
    }
    final session = AppSession.of(context);
    final repository = TripNewRepository(session.api);
    final homeCityId = session.me?.city?.id;
    final order = widget.args?.order;
    final c = order != null
        ? WizardController.fromOrder(repository, order, homeCityId: homeCityId)
        : WizardController(repository, homeCityId: homeCityId, passengerOrder: widget.args?.isPassengerOrder ?? false);
    _controller = c;
    final templateId = widget.templateId;
    if (templateId != null) _applyTemplate(c, templateId);
  }

  Future<void> _applyTemplate(WizardController c, String id) async {
    try {
      final all = await c.repository.templates();
      final found = all.where((t) => t.id == id);
      if (found.isNotEmpty) c.applyTemplate(found.first);
    } catch (_) {
      // Шаблон не подставился — маршрут вводится вручную.
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller?.dispose();
    super.dispose();
  }

  void _next() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RouteStep(controller: _controller!)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = _controller!;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => WizardScaffold(
        step: 1,
        order: c.passengerOrder,
        body: [
          // Карточки лежат на фоне экрана по отдельности, без общей белой подложки (кадр «Новый заказ - Тип заказа»).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.tripNewTypeTitle, style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: AppSize.gap12),
                _TypeCard(
                  // Водителю — «Пассажиры»: автобусом тоже везут пассажиров; пассажиру — «Автомобиль» кадра «Новый заказ - Тип заказа».
                  title: c.passengerOrder ? l10n.tripNewTypeRide : l10n.tripNewTypeRideDriver,
                  // Водителю — «Везу пассажиров», пассажиру — текст кадра «Новый заказ - Тип заказа» (принятое решение 2026-10-22).
                  hint: c.passengerOrder ? l10n.tripNewTypeRideHint : l10n.tripNewTypeRideDriverHint,
                  image: TripNewImages.typeRide,
                  imageSize: const Size(148, 99),
                  imageOut: 34,
                  imageTop: 10,
                  selected: c.kind == TripKind.ride,
                  onTap: () => c.setKind(TripKind.ride),
                ),
                const SizedBox(height: AppSize.gap12),
                _TypeCard(
                  title: l10n.tripNewTypeParcel,
                  hint: c.passengerOrder ? l10n.tripNewTypeParcelHint : l10n.tripNewTypeParcelDriverHint,
                  image: TripNewImages.typeParcel,
                  imageSize: const Size(167, 112),
                  imageOut: 45,
                  imageTop: 0,
                  selected: c.kind == TripKind.parcel,
                  onTap: () => c.setKind(TripKind.parcel),
                ),
              ],
            ),
          ),
        ],
        bottom: AppButton(label: l10n.tripNewNext, onPressed: _next),
      ),
    );
  }
}

/// Карточка типа заказа (`role` кадра «Новый заказ - Тип заказа»): радио, подпись, картинка справа внизу.
class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.title,
    required this.hint,
    required this.image,
    required this.imageSize,
    required this.imageOut,
    required this.imageTop,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String hint;
  final String image;

  /// Размер картинки, как в кадре.
  final Size imageSize;

  /// На сколько правый край картинки выходит за правый край карточки (карточка обрезает выступ).
  final double imageOut;

  /// Отступ картинки от верха карточки.
  final double imageTop;
  final bool selected;
  final VoidCallback onTap;

  // Картинки кадра: «Автомобиль» 148×99, «Посылка» 167×112 (cover), обе выходят за правый край карточки и
  // обрезаются ею. Положение снято с PNG кадра по краям непрозрачной части картинок: правый край
  // «Автомобиля» на 34 за карточкой, верх — 10 от верха карточки; «Посылки» — на 45 за карточкой, верх — 0
  // (низ на 4 ниже карточки). Ступеней в шкале нет — числа кадра. Колонка текста в кадре — 180,
  // но Gilroy на устройстве чуть шире, чем в Penpot, и «Найти водителя для себя» (≈176–180) на 180 переносится
  // на вторую строку; 190 держит ту же раскладку, что в кадре: первая подпись в строку, вторая («Отправить груз
  // или посылку» ≈ 200) — в две. 108 — наименьшая высота карточки: подпись в две строки (с высотой строки
  // текста, а не рамки кадра) растит её.
  static const _cardHeight = 108.0;
  static const _textWidth = 190.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: _cardHeight),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppSize.radius12),
            border: selected ? Border.all(color: AppColors.accentPrimary, width: AppSize.stroke1) : null,
          ),
          child: Stack(
            children: [
              Positioned(
                right: -imageOut,
                top: imageTop,
                width: imageSize.width,
                height: imageSize.height,
                child: Image.asset(image, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSize.pad20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppRadio(selected: selected, onTap: onTap),
                    const SizedBox(width: AppSize.gap12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: _textWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: AppType.titlesHeadline.copyWith(color: AppColors.textPrimary)),
                              const SizedBox(height: AppSize.gap8),
                              Text(hint, style: AppType.body2.copyWith(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
