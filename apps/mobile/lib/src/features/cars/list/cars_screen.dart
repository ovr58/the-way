import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_routes.dart';
import '../../../app/session.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_empty.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/app_loading.dart';
import '../data/cars_repository.dart';
import '../widgets/cars_ui.dart';
import 'car_details_screen.dart';

/// «Транспортные средства»: пустой список («Транспортные средства») или список авто водителя («Транспортные средства»). Нажатие на авто
/// открывает карточку («Транспортные средства»), «Добавить ТС» — форму `cars/add`.
class CarsScreen extends StatefulWidget {
  const CarsScreen({super.key});

  @override
  State<CarsScreen> createState() => _CarsScreenState();
}

class _CarsScreenState extends State<CarsScreen> {
  // Картинка пустого состояния — слой `image 20`, «Транспортные средства».
  static const _emptyImage = 'assets/images/cars_empty.webp';

  CarsRepository? _repo;
  Future<List<Car>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo ??= CarsRepository(AppSession.of(context).api);
    _future ??= _repo!.list();
  }

  void _reload() => setState(() {
        _future = _repo!.list();
      });

  Future<void> _add() async {
    await Navigator.of(context).pushNamed(AppRoutes.carsAdd);
    if (mounted) _reload();
  }

  Future<void> _open(Car car) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'cars/details'),
        builder: (_) => CarDetailsScreen(car: car),
      ),
    );
    if (mounted && changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(title: l10n.carsTitle, onBack: () => Navigator.of(context).maybePop()),
          Expanded(
            child: FutureBuilder<List<Car>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return AppErrorView(onRetry: _reload);
                final cars = snapshot.data;
                if (cars == null) return const AppLoading();
                if (cars.isEmpty) {
                  return AppEmpty(
                    title: l10n.carsEmptyTitle,
                    subtitle: l10n.carsEmptyBody,
                    imageAsset: _emptyImage,
                    action: AppAddButton(label: l10n.carsAdd, onPressed: _add),
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(top: AppSize.pad20, bottom: AppSize.pad20),
                        itemCount: cars.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSize.gap12),
                        itemBuilder: (_, i) => _CarRow(car: cars[i], onTap: () => _open(cars[i])),
                      ),
                    ),
                    CarsBottomBar(child: AppButton(label: l10n.carsAdd, onPressed: _add)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CarRow extends StatelessWidget {
  const _CarRow({required this.car, required this.onTap});

  final Car car;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(AppSize.radius12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSize.radius12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSize.pad16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSize.radius8),
                child: AppImage(car.photoUrl, width: _photo, height: _photo),
              ),
              const SizedBox(width: AppSize.gap12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CarTitleLine('${car.brand} ${car.model}', verified: car.status == CarStatus.verified),
                    const SizedBox(height: AppSize.gap4),
                    CarPlateSeatsLine(plate: car.plate, seats: l10n.carsSeats(car.seats)),
                  ],
                ),
              ),
              const SizedBox(width: AppSize.gap8),
              const AppIcon('arrows_alt_arrow_right', size: AppSize.icon20, color: AppColors.borderStrong),
            ],
          ),
        ),
      ),
    );
  }

  // Фото авто в списке — 42×42 («Транспортные средства»); такой ступени в шкале нет.
  static const _photo = 42.0;
}
