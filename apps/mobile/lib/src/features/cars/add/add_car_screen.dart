import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/session.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/app_input.dart';
import '../../auth/data/api_error.dart';
import '../data/car_catalog.dart';
import '../data/cars_repository.dart';
import '../widgets/cars_ui.dart';
import 'photo_sheet.dart';
import 'other_model_sheet.dart';
import 'pick_sheet.dart';
import 'sts_screen.dart';

export 'photo_sheet.dart' show PhotoPicker;

/// «Добавление нового ТС» («Добавление нового ТС»). Поля `POST /cars` — марка и модель из каталога, госномер
/// (добавлен, `docs/DESIGN_CHANGES.md`), вместимость, тип «Легковой» («Автобус» неактивен), фото
/// авто (по желанию); фото СТС обязательно (FR-04). Поля появляются по шагам: марка → госномер, «Тип» и
/// вместимость; «Тип» — над вместимостью, граница мест — по нему (реестр отступлений). Закрывается,
/// вернув `carId` созданного авто.
///
/// С [car] — режим правки (кадры «Транспортные средства»): та же форма с полями авто, «Сохранить» шлёт `PATCH /cars/{id}`;
/// СТС уже есть — новый снимок по желанию. Закрывается, вернув обновлённый [Car].
class AddCarScreen extends StatefulWidget {
  const AddCarScreen({super.key, this.picker = pickSystemPhoto, this.car});

  /// Системная камера или галерея; в тестах подменяется.
  final PhotoPicker picker;

  /// Авто для правки; `null` — добавление.
  final Car? car;

  @override
  State<AddCarScreen> createState() => _AddCarScreenState();
}

class _AddCarScreenState extends State<AddCarScreen> {
  final _brandText = TextEditingController();
  final _modelText = TextEditingController();
  final _plate = TextEditingController();
  final _seats = TextEditingController();

  Future<CarCatalog>? _catalog;
  CarBrand? _brand;
  CarModel? _model;
  VehicleKind? _kind;
  XFile? _photo;
  XFile? _sts;
  bool _busy = false;

  // Ответ сервера на отправку: номер уже в списке водителя (`car_plate_taken`), мест вне границ
  // (`car_seats_out_of_range`). Текст под полем держится, пока поле не изменено.
  bool _plateTaken = false;
  bool _seatsRejected = false;

  // Авто создано, а загрузка СТС сорвалась: поля заблокированы, повтор грузит только СТС.
  String? _createdCarId;

  // Правка: фото авто на сервере (пока не выбран новый снимок) и есть ли уже СТС.
  String? _photoUrl;
  bool _hasSts = false;

  bool get _editing => widget.car != null;

  @override
  void initState() {
    super.initState();
    final car = widget.car;
    if (car == null) return;
    // Марка и модель — по имени; из каталога марка подтягивается при выборе модели.
    _brand = CarBrand(id: '', name: car.brand, cyrillicName: car.brand, popular: false, models: const []);
    _model = CarModel(id: '', name: car.model, cyrillicName: car.model);
    _brandText.text = car.brand;
    _modelText.text = car.model;
    _plate.text = car.plate;
    _seats.text = '${car.seats}';
    _kind = car.kind;
    _photoUrl = car.photoUrl;
    _hasSts = car.documents.any((d) => d.kind == CarDocumentKind.sts);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _catalog ??= CarCatalog.load(DefaultAssetBundle.of(context));
  }

  @override
  void dispose() {
    _brandText.dispose();
    _modelText.dispose();
    _plate.dispose();
    _seats.dispose();
    super.dispose();
  }

  int? get _seatCount => int.tryParse(_seats.text);

  // У «Легкового» мест от 1 до 8 — принятое решение; у «Автобуса» — от 9
  // до 60 (2026-10-22). До выбора типа границы нет — не ругаться; «Добавить» ждёт тип.
  static const _carSeatsMax = 8;
  static const _busSeatsMin = 9;
  static const _busSeatsMax = 60;

  bool get _bus => _kind == VehicleKind.bus;

  bool get _seatsOutOfRange {
    final n = _seatCount;
    if (n == null || _kind == null) return false;
    return _bus ? n < _busSeatsMin || n > _busSeatsMax : n < 1 || n > _carSeatsMax;
  }

  bool get _canSubmit =>
      _brand != null &&
      _model != null &&
      _plate.text.trim().isNotEmpty &&
      (_seatCount ?? 0) >= 1 &&
      !_seatsOutOfRange &&
      _kind != null &&
      (_sts != null || _hasSts);

  /// Ошибка отправки: известный код — текст под своим полем, иначе общий текст.
  void _failed(Object error, AppLocalizations l10n) {
    if (!mounted) return;
    final code = apiErrorCode(error);
    setState(() {
      _busy = false;
      _plateTaken = code == 'car_plate_taken';
      _seatsRejected = code == 'car_seats_out_of_range';
    });
    if (!_plateTaken && !_seatsRejected) showCarsError(context, l10n.carsErrorGeneric);
  }

  Future<void> _pickBrand() async {
    final l10n = AppLocalizations.of(context);
    final catalog = await _catalog!;
    if (!mounted) return;
    final brand = await pickFromList<CarBrand>(
      context,
      title: l10n.carsPickBrand,
      searchHint: l10n.carsSearchBrand,
      search: catalog.searchBrands,
      label: (b) => b.name,
      icon: 'system_car',
      groupByLetter: true,
    );
    if (brand == null || brand == _brand) return;
    if (brand.name == _brand?.name) {
      _brand = brand; // правка: та же марка из каталога — модель остаётся
      return;
    }
    setState(() {
      _brand = brand;
      _model = null;
      _brandText.text = brand.name;
      _modelText.clear();
    });
  }

  Future<void> _pickModel() async {
    var brand = _brand;
    if (brand == null) return;
    if (brand.models.isEmpty) {
      // Правка: марка авто пришла именем — модели берутся из каталога.
      final name = brand.name;
      final catalog = await _catalog!;
      if (!mounted) return;
      brand = _brand = catalog.brands.where((b) => b.name == name).firstOrNull ?? brand;
    }
    final l10n = AppLocalizations.of(context);
    final model = await pickFromList<CarModel>(
      context,
      title: l10n.carsPickModel(brand.name),
      searchHint: l10n.carsSearchModel,
      search: brand.searchModels,
      label: (m) => m.name,
      otherLabel: l10n.carsOtherModel,
      other: (query) async {
        final name = await showOtherModelSheet(context, initial: query);
        return name == null ? null : CarModel(id: '', name: name, cyrillicName: name);
      },
    );
    if (model == null) return;
    setState(() {
      _model = model;
      _modelText.text = model.name;
    });
  }

  Future<void> _addPhoto() async {
    final photo = await choosePhoto(context, widget.picker);
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  Future<void> _addSts() async {
    final photo = await Navigator.of(context).push<XFile>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'cars/sts'),
        builder: (_) => StsScreen(picker: widget.picker),
      ),
    );
    if (photo != null && mounted) setState(() => _sts = photo);
  }

  Future<void> _submit() async {
    final repo = CarsRepository(AppSession.of(context).api);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final editing = widget.car;
    if (editing != null) {
      try {
        final photoId = _photo == null ? null : await repo.upload(File(_photo!.path));
        var car = await repo.update(
          editing.id,
          CarPatch(
            brand: _brand!.name,
            model: _model!.name,
            kind: _kind!,
            seats: _seatCount!,
            plate: _plate.text.trim(),
            photoFileId: photoId,
          ),
        );
        final sts = _sts;
        if (sts != null) car = await repo.addSts(editing.id, await repo.upload(File(sts.path)));
        if (mounted) Navigator.of(context).pop(car);
      } catch (e) {
        _failed(e, l10n);
      }
      return;
    }
    try {
      var carId = _createdCarId;
      if (carId == null) {
        final photoId = _photo == null ? null : await repo.upload(File(_photo!.path));
        final car = await repo.create(CarInput(
          brand: _brand!.name,
          model: _model!.name,
          kind: _kind!,
          seats: _seatCount!,
          plate: _plate.text.trim(),
          photoFileId: photoId,
        ));
        carId = _createdCarId = car.id;
      }
      final sts = _sts;
      if (sts != null) {
        final fileId = await repo.upload(File(sts.path));
        await repo.addSts(carId, fileId);
        _sts = null;
      }
      if (mounted) Navigator.of(context).pop(carId);
    } catch (e) {
      _failed(e, l10n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const gap = SizedBox(height: AppSize.gap20);
    const smallGap = SizedBox(height: AppSize.gap12);
    const chevron = AppIcon('arrows_alt_arrow_right', size: AppSize.icon18, color: AppColors.borderStrong);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(
            title: _editing ? l10n.carsEditTitle : l10n.carsAddTitle,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: AppSize.pad20, bottom: AppSize.pad20),
              children: [
                IgnorePointer(
                  ignoring: _createdCarId != null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CarsSectionTitle(l10n.carsInfoTitle),
                      smallGap,
                      CarsCard(
                        child: Column(
                          children: [
                            AppInput(label: l10n.carsBrand, controller: _brandText, onTap: _pickBrand, suffix: chevron),
                            smallGap,
                            AppInput(label: l10n.carsModel, controller: _modelText, onTap: _pickModel, suffix: chevron),
                            if (_brand != null) ...[
                              smallGap,
                              AppInput(
                                label: l10n.carsPlate,
                                hintText: l10n.carsPlateHint,
                                controller: _plate,
                                errorText: _plateTaken ? l10n.carsPlateTaken : null,
                                onChanged: (_) => setState(() => _plateTaken = false),
                              ),
                            ],
                            smallGap,
                            if (_photo == null && _photoUrl != null)
                              // Правка: фото авто с сервера; нажатие — новый снимок вместо него.
                              InkWell(
                                key: const Key('cars-photo-preview'),
                                onTap: _addPhoto,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(AppSize.radius8),
                                  child: AppImage(_photoUrl, width: double.infinity, height: _PhotoPreview._height),
                                ),
                              )
                            else if (_photo == null)
                              SizedBox(
                                width: double.infinity,
                                child: SmallOutlineButton(
                                  label: l10n.carsAddPhoto,
                                  icon: 'essentional_add',
                                  onPressed: _addPhoto,
                                ),
                              )
                            else
                              _PhotoPreview(photo: _photo!, onRemove: () => setState(() => _photo = null)),
                          ],
                        ),
                      ),
                      if (_brand != null) ...[
                        gap,
                        CarsSectionTitle(l10n.carsTypeTitle),
                        smallGap,
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _KindCard(
                                  icon: 'system_car',
                                  label: l10n.carsKindCar,
                                  selected: _kind == VehicleKind.car,
                                  onTap: () => setState(() => _kind = VehicleKind.car),
                                ),
                              ),
                              const SizedBox(width: AppSize.gap12),
                              Expanded(
                                child: _KindCard(
                                  icon: 'system_bus',
                                  label: l10n.carsKindBus,
                                  selected: _bus,
                                  onTap: () => setState(() => _kind = VehicleKind.bus),
                                ),
                              ),
                            ],
                          ),
                        ),
                        gap,
                        CarsCard(
                          child: AppInput(
                            label: l10n.carsCapacity,
                            controller: _seats,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            maxLength: 2,
                            errorText: _seatsOutOfRange || _seatsRejected
                                ? (_bus ? l10n.carsSeatsRangeBus : l10n.carsSeatsRange)
                                : null,
                            onChanged: (_) => setState(() => _seatsRejected = false),
                            suffix: Text(l10n.carsCapacityUnit,
                                style: AppType.bodyFootnote.copyWith(color: AppColors.textSecondary)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                gap,
                CarsSectionTitle(l10n.carsConfirmDocuments),
                smallGap,
                CarsCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(l10n.carsSts, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
                      ),
                      const SizedBox(width: AppSize.gap12),
                      if (_sts == null && !_hasSts)
                        SmallOutlineButton(
                          key: const Key('cars-add-sts'),
                          label: l10n.carsAddDocument,
                          onPressed: _addSts,
                        )
                      else
                        InkWell(
                          key: const Key('cars-add-sts'),
                          onTap: _addSts,
                          child: const Padding(
                            padding: EdgeInsets.all(AppSize.pad8),
                            child: AppIcon('essentional_check_circle', size: AppSize.icon20, color: AppColors.accentPrimary),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          CarsBottomBar(
            child: AppButton(
              label: _editing ? l10n.carsSave : l10n.carsSubmit,
              kind: _canSubmit ? AppButtonKind.primary : AppButtonKind.neutral,
              loading: _busy,
              onPressed: _canSubmit ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.photo, required this.onRemove});

  final XFile photo;
  final VoidCallback onRemove;

  // Высота снимка в кадре — 175; такой ступени в шкале нет.
  static const _height = 175.0;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppSize.radius8),
        child: SizedBox(
          height: _height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(photo.path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.bgScreen),
              ),
              Positioned(
                top: AppSize.pad8,
                right: AppSize.pad8,
                child: InkWell(
                  onTap: onRemove,
                  child: Container(
                    width: AppSize.height24,
                    height: AppSize.height24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppSize.radius8),
                    ),
                    child: const AppIcon('essentional_close', size: AppSize.icon14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// Кнопка типа ТС («Добавление нового ТС»): значок 24 и подпись, 166×72. Картинка машины в кадре лежит вне
/// кнопки и не видна — её нет (тема car-type-buttons). Без [onTap] — неактивна.
class _KindCard extends StatelessWidget {
  const _KindCard({required this.icon, required this.label, this.selected = false, this.onTap});

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Material(
          color: selected ? AppColors.accentPrimaryTint : AppColors.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSize.radius12),
            side: selected
                ? const BorderSide(color: AppColors.accentPrimary, width: AppSize.stroke1)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSize.radius12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSize.pad12),
              child: Column(
                children: [
                  AppIcon(icon, size: AppSize.icon24),
                  const SizedBox(height: AppSize.gap4),
                  Text(label, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
                ],
              ),
            ),
          ),
        ),
      );
}
