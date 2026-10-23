import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/app_loading.dart';
import '../../../widgets/app_radio.dart';
import '../../cars/widgets/cars_ui.dart';
import '../trip_new_images.dart';
import '../wizard_controller.dart';
import 'extras_step.dart';
import 'wizard_scaffold.dart';

/// Шаг 4 из 6 — автомобиль («Новый заказ - Выбор авто - нет авто» – «Новый заказ - Выбор авто - выбрано авто»): список `GET /cars`, «Добавить авто» → `cars/add`
/// (по возврату список перечитывается), авто с местами меньше `seatsTotal` — неактивно.
class CarStep extends StatefulWidget {
  const CarStep({super.key, required this.controller});

  final WizardController controller;

  @override
  State<CarStep> createState() => _CarStepState();
}

class _CarStepState extends State<CarStep> {
  List<Car>? _cars;
  bool _failed = false;

  WizardController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? select}) async {
    setState(() {
      _failed = false;
      if (select == null) _cars = null;
    });
    try {
      final cars = (await _c.repository.cars()).where((c) => c.status == CarStatus.verified).toList();
      if (!mounted) return;
      setState(() => _cars = cars);
      if (select != null) {
        final picked = cars.where((c) => c.id == select);
        if (picked.isNotEmpty && _fits(picked.first)) _c.setCar(picked.first);
      }
      // Выбранное раньше авто могло пропасть из списка.
      if (_c.carId != null && !cars.any((c) => c.id == _c.carId)) {
        _c.carId = null;
        _c.carSeats = null;
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  bool _fits(Car car) => car.seats >= _c.seatsTotal;

  Future<void> _addCar() async {
    final added = await Navigator.of(context).pushNamed<Object?>(AppRoutes.carsAdd);
    if (!mounted) return;
    await _load(select: added is String ? added : null);
  }

  void _next() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ExtrasStep(controller: _c)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cars = _cars;
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        if (_failed) {
          return WizardScaffold(
            step: 4,
            body: [SizedBox(height: 360, child: AppErrorView(onRetry: () => _load()))],
            bottom: AppButton(label: l10n.tripNewNext, onPressed: null),
          );
        }
        if (cars == null) {
          return WizardScaffold(
            step: 4,
            body: const [SizedBox(height: 360, child: AppLoading())],
            bottom: AppButton(label: l10n.tripNewNext, onPressed: null),
          );
        }
        return WizardScaffold(
          step: 4,
          body: [
            if ((_c.priceFull ?? 0) > 0)
              WizardCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.tripNewPriceTotal,
                        style: AppType.bodyFootnote.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                    Text(
                      l10n.commonPrice(_c.priceFull!),
                      style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            _CarsSection(
              title: l10n.tripNewCar,
              addLabel: l10n.tripNewAddCar,
              onAdd: _addCar,
              empty: cars.isEmpty,
              emptyTitle: l10n.tripNewNoCarsTitle,
              emptyBody: l10n.tripNewNoCarsBody,
              children: [
                for (final car in cars)
                  _CarCard(
                    car: car,
                    selected: _c.carId == car.id,
                    enabled: _fits(car),
                    seatsLabel: l10n.tripNewCarSeats(car.seats),
                    tooSmallLabel: l10n.tripNewCarTooSmall,
                    onTap: () => _c.setCar(car),
                  ),
              ],
            ),
          ],
          bottom: AppButton(
            label: l10n.tripNewNext,
            onPressed: _c.carId != null && (_c.carSeats ?? 0) >= _c.seatsTotal ? _next : null,
          ),
        );
      },
    );
  }
}

class _CarsSection extends StatelessWidget {
  const _CarsSection({
    required this.title,
    required this.addLabel,
    required this.onAdd,
    required this.empty,
    required this.emptyTitle,
    required this.emptyBody,
    required this.children,
  });

  final String title;
  final String addLabel;
  final VoidCallback onAdd;
  final bool empty;
  final String emptyTitle;
  final String emptyBody;
  final List<Widget> children;

  // Кнопка «Добавить авто» в кадре — 107×32 (шрифт 12/500).
  static const _addHeight = 32.0;
  // Картинка пустого состояния — 90×80.
  static const _emptyImageWidth = 90.0;
  static const _emptyImageHeight = 80.0;

  @override
  Widget build(BuildContext context) {
    final addButton = SizedBox(
      height: _addHeight,
      child: Material(
        color: empty ? AppColors.accentPrimary : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSize.radius8),
          side: empty
              ? BorderSide.none
              : const BorderSide(color: AppColors.accentPrimary, width: AppSize.stroke1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSize.radius8),
          onTap: onAdd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSize.pad12),
            child: Center(
              child: Text(
                addLabel,
                style: AppType.button3.copyWith(color: empty ? AppColors.textOnAccent : AppColors.accentPrimary),
              ),
            ),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
          child: Row(
            children: [
              Expanded(child: Text(title, style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary))),
              if (!empty) addButton,
            ],
          ),
        ),
        const SizedBox(height: AppSize.gap12),
        WizardCard(
          child: empty
              ? Column(
                  children: [
                    Image.asset(TripNewImages.noCars, width: _emptyImageWidth, height: _emptyImageHeight, fit: BoxFit.cover),
                    const SizedBox(height: AppSize.gap12),
                    Text(emptyTitle, textAlign: TextAlign.center, style: AppType.titlesHeadline.copyWith(color: AppColors.textPrimary)),
                    const SizedBox(height: AppSize.gap4),
                    Text(emptyBody, textAlign: TextAlign.center, style: AppType.body2.copyWith(color: AppColors.textTertiary)),
                    const SizedBox(height: AppSize.gap16),
                    addButton,
                  ],
                )
              : Column(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSize.gap8),
                      children[i],
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// Карточка авто: фото 42, «Марка Модель» с галочкой «Проверен», «номер • N места», радио («Новый заказ - Выбор авто - есть авто», «Новый заказ - Выбор авто - выбрано авто»).
class _CarCard extends StatelessWidget {
  const _CarCard({
    required this.car,
    required this.selected,
    required this.enabled,
    required this.seatsLabel,
    required this.tooSmallLabel,
    required this.onTap,
  });

  final Car car;
  final bool selected;
  final bool enabled;
  final String seatsLabel;
  final String tooSmallLabel;
  final VoidCallback onTap;

  // Фото авто в кадре — 42×42.
  static const _photo = 42.0;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSize.radius12),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(AppSize.pad12),
          decoration: BoxDecoration(
            // Выбранная — зелёный 12% («Новый заказ - Выбор авто - выбрано авто»), тот же цвет, что у выбранного «Тип» формы ТС.
            color: selected ? AppColors.accentPrimaryTint : null,
            borderRadius: BorderRadius.circular(AppSize.radius12),
            border: Border.all(
              color: selected ? AppColors.accentPrimary : AppColors.borderDefault,
              width: AppSize.stroke1,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSize.radius8),
                // Нет фото — серая плашка, как на остальных экранах, а не чужая стоковая машина (тема car-photos).
                child: AppImage(car.photoUrl, width: _photo, height: _photo),
              ),
              const SizedBox(width: AppSize.gap12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // В шаге показываются только проверенные авто — галочка «Проверен» у каждого (тема car-check-badge).
                    CarTitleLine('${car.brand} ${car.model}', verified: car.status == CarStatus.verified),
                    const SizedBox(height: AppSize.gap4),
                    if (enabled)
                      CarPlateSeatsLine(plate: car.plate, seats: seatsLabel)
                    else
                      Text(tooSmallLabel, style: AppType.body2.copyWith(color: AppColors.statusError)),
                  ],
                ),
              ),
              AppRadio(selected: selected, onTap: enabled ? onTap : null),
            ],
          ),
        ),
      ),
    );
  }
}
