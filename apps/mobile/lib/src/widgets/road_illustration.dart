import 'package:api_client/api_client.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Что нарисовано над маршрутом — по сути заказа (тема road-or-box, принятое решение 2026-10-22):
/// [box] — везут только посылку (поездка типа «посылка», бронь без пассажира, шторка посылки «Бронирование»);
/// [road] — едет пассажир; [roadWithBox] — место и посылка вместе. В макете коробка только на «Бронирование»:
/// правило подстановки и совмещённая картинка — принятое решение сверх кадра.
enum TripArt {
  road,
  box,
  roadWithBox;

  /// Поездка: «посылка» — коробка, с местами — дорога.
  static TripArt ofTrip(TripKind kind) => kind == TripKind.parcel ? box : road;

  /// Бронь: без пассажира — коробка; место и посылка — вместе; только место — дорога.
  static TripArt ofBooking(Booking b) =>
      b.parcelOnly ? box : (b.parcelSize == ParcelSize.none ? road : roadWithBox);
}

/// Иллюстрация над маршрутом. Дорога на сером — векторная группа `road` кадров «Детали поездки - Места есть», «Бронирование», «Детали поездки - С пассажирами», «Редактирование - Пассажиры есть»
/// (`assets/images/road.svg`), лежит вверху карточки маршрута у левого края. Размер по кадру: 293×169
/// («Детали поездки - Места есть», «Редактирование - Пассажиры есть»), 284×164 («Бронирование»), 293×290 («Детали поездки - С пассажирами» — в кадре та же картинка растянута по высоте); рисунок
/// заполняет весь размер без сохранения пропорций, как группа в Penpot.
/// Коробка ([TripArt.box]) — группа шторки посылки «Бронирование» (`assets/images/box.svg`), 252×188, как в кадре,
/// по центру поля по горизонтали (принятое решение: в кадре «Бронирование» она у левого
/// края). В низком поле — ниже дороги «Бронирование» (164), то есть в карточке брони у водителя высотой 85, —
/// коробка вписана в высоту поля. [TripArt.roadWithBox] — дорога того же размера и коробка поверх:
/// 1/3 ширины дороги, в её правом верхнем углу, по пропорции коробки.
class RoadIllustration extends StatelessWidget {
  const RoadIllustration({super.key, this.width = 293, this.height = 169, this.art = TripArt.road});

  final double width;
  final double height;
  final TripArt art;

  // Коробка «Бронирование» — 251.579×188.4 (группа `1cd1507c`); в шкале размеров этих ступеней нет.
  static const _boxWidth = 251.579;
  static const _boxHeight = 188.4;

  // Поле полной высоты — от дороги «Бронирование» (164) и выше: коробка своего размера, как на «Бронирование».
  static const _fullHeight = 164.0;

  static Widget _box(double width) => SvgPicture.asset(
        'assets/images/box.svg',
        width: width,
        height: width * _boxHeight / _boxWidth,
        fit: BoxFit.fill,
      );

  @override
  Widget build(BuildContext context) {
    final road = SizedBox(
      width: width,
      height: height,
      child: SvgPicture.asset('assets/images/road.svg', fit: BoxFit.fill),
    );
    if (art == TripArt.box) {
      final boxWidth = height >= _fullHeight ? _boxWidth : height * _boxWidth / _boxHeight;
      return Align(alignment: Alignment.topCenter, child: _box(boxWidth));
    }
    return Align(
      alignment: Alignment.topLeft,
      child: art == TripArt.road
          ? road
          : Stack(
              children: [
                road,
                Positioned(top: 0, right: 0, child: _box(width / 3)),
              ],
            ),
    );
  }
}
