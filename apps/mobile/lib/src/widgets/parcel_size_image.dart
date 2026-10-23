import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_size.dart';

/// Картинка размера посылки (`image 25` кадров «Новый заказ - Выбор веса посылки» — мастер поездки, «Бронирование - С доп услугами» — шторка брони):
/// белая рамка 42×42, в ней 38×75 — одна машина с открытым багажником из полосы трёх (S | M | L),
/// у каждого размера своя треть. Один виджет на все три кадра: правка одного места меняет все.
class ParcelSizeImage extends StatelessWidget {
  const ParcelSizeImage({super.key, required this.size});

  final ParcelSize size;

  static const asset = 'assets/images/parcel_size.webp';

  // Рамка в кадре — 42×42, картинка — 38×75; в шкале размеров таких ступеней нет.
  static const _box = 42.0;
  static const _imageWidth = 38.0;
  static const _imageHeight = 75.0;

  // Треть полосы своего размера: обрезка `cover` по ширине 38 оставляет ровно одну машину.
  Alignment get _third => switch (size) {
        ParcelSize.s => Alignment.centerLeft,
        ParcelSize.m => Alignment.center,
        _ => Alignment.centerRight,
      };

  @override
  Widget build(BuildContext context) => Container(
        width: _box,
        height: _box,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppSize.radius8),
        ),
        child: OverflowBox(
          minWidth: 0,
          minHeight: 0,
          maxWidth: _imageWidth,
          maxHeight: _imageHeight,
          child: Image.asset(
            asset,
            width: _imageWidth,
            height: _imageHeight,
            fit: BoxFit.cover,
            alignment: _third,
          ),
        ),
      );
}
