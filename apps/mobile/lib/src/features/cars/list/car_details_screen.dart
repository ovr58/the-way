import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/session.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/status_chip.dart';
import '../add/add_car_screen.dart';
import '../add/photo_sheet.dart';
import '../data/cars_repository.dart';
import '../widgets/cars_ui.dart';

/// Карточка авто («Транспортные средства»): фото, название, госномер, статус, тип и места, документы, «Редактировать» и «Удалить ТС».
/// «Редактировать» — форма добавления ТС в режиме правки; «Заменить» у СТС — новый снимок (кадры «Транспортные средства»).
/// Закрывается с `true`, если авто удалено или изменено.
class CarDetailsScreen extends StatefulWidget {
  const CarDetailsScreen({super.key, required this.car, this.picker = pickSystemPhoto});

  final Car car;

  /// Системная камера или галерея; в тестах подменяется.
  final PhotoPicker picker;

  @override
  State<CarDetailsScreen> createState() => _CarDetailsScreenState();
}

class _CarDetailsScreenState extends State<CarDetailsScreen> {
  // Высота фото авто в кадре — 150; такой ступени в шкале нет.
  static const _photoHeight = 150.0;

  late Car _car = widget.car;
  bool _deleting = false;
  bool _replacing = false;

  // Авто изменено на этом экране — список при возврате перечитывается.
  bool _changed = false;

  Future<void> _edit() async {
    final car = await Navigator.of(context).push<Car>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'cars/edit'),
        builder: (_) => AddCarScreen(car: _car, picker: widget.picker),
      ),
    );
    if (car != null && mounted) {
      setState(() {
        _car = car;
        _changed = true;
      });
    }
  }

  Future<void> _replaceSts() async {
    final repo = CarsRepository(AppSession.of(context).api);
    final l10n = AppLocalizations.of(context);
    final photo = await choosePhoto(context, widget.picker);
    if (photo == null || !mounted) return;
    setState(() => _replacing = true);
    try {
      final car = await repo.addSts(_car.id, await repo.upload(File(photo.path)));
      if (!mounted) return;
      setState(() {
        _car = car;
        _changed = true;
        _replacing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _replacing = false);
      showCarsError(context, l10n.carsErrorGeneric);
    }
  }

  Future<void> _delete() async {
    final repo = CarsRepository(AppSession.of(context).api);
    final l10n = AppLocalizations.of(context);
    setState(() => _deleting = true);
    try {
      await repo.delete(_car.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      showCarsError(context, l10n.carsErrorGeneric);
    }
  }

  void _confirmDelete() {
    final l10n = AppLocalizations.of(context);
    AppDialog.show(
      context,
      title: l10n.carsDeleteTitle,
      actions: [
        AppDialogAction(l10n.carsDeleteConfirm, primary: true, onPressed: _delete),
        AppDialogAction(l10n.commonCancel),
      ],
    );
  }

  String _statusLabel(AppLocalizations l10n, CarStatus status) => switch (status) {
        CarStatus.verified => l10n.carsStatusVerified,
        CarStatus.rejected => l10n.carsStatusRejected,
        _ => l10n.carsStatusPending,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final car = _car;
    final photo = car.photoUrl;
    final kind = car.kind == VehicleKind.bus ? l10n.carsKindBus : l10n.carsKindCar;
    return PopScope<Object?>(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        backgroundColor: AppColors.bgScreen,
        body: Column(
          children: [
            AppHeader(title: '${car.brand} ${car.model}', onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: AppSize.pad20, bottom: AppSize.pad20),
                children: [
                  CarsCard(
                    padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16, vertical: AppSize.pad12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (photo != null && photo.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppSize.radius8),
                            child: AppImage(photo, width: double.infinity, height: _photoHeight),
                          ),
                          const SizedBox(height: AppSize.gap12),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: AppSize.gap12,
                                runSpacing: AppSize.gap4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text('${car.brand} ${car.model}',
                                      style: AppType.titlesSubheadline.copyWith(color: AppColors.textPrimary)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSize.pad12, vertical: AppSize.pad4),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.textPrimary, width: AppSize.stroke1),
                                      borderRadius: BorderRadius.circular(AppSize.radius4),
                                    ),
                                    child: Text(car.plate, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSize.gap8),
                            StatusChip(_statusLabel(l10n, car.status)),
                          ],
                        ),
                        const SizedBox(height: AppSize.gap8),
                        Text(l10n.carsKindSeats(kind, l10n.carsSeats(car.seats)),
                            style: AppType.body2.copyWith(color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  // Блок «Документы — СТС» показывается всегда, как в кадре (принятое решение 2026-10-22):
                  // СТС обязателен при добавлении авто; «Заменить ›» — новый снимок (кадры «Транспортные средства»).
                  const SizedBox(height: AppSize.gap20),
                  CarsSectionTitle(l10n.carsDocuments),
                  const SizedBox(height: AppSize.gap12),
                  CarsCard(
                    padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16, vertical: AppSize.pad12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(l10n.carsSts, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
                        ),
                        const SizedBox(width: AppSize.gap12),
                        IgnorePointer(
                          ignoring: _replacing,
                          child: Opacity(
                            opacity: _replacing ? 0.5 : 1,
                            child: SmallOutlineButton(
                              label: l10n.carsReplace,
                              trailingIcon: 'arrows_alt_arrow_right',
                              onPressed: _replaceSts,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            CarsBottomBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(label: l10n.carsEdit, size: AppButtonSize.medium, onPressed: _deleting ? null : _edit),
                  const SizedBox(height: AppSize.gap8),
                  DestructiveButton(label: l10n.carsDelete, loading: _deleting, onPressed: _confirmDelete),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
