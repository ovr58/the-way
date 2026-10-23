import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../theme/app_colors.dart';
import 'answers/answer_popups.dart';
import 'answers/paid_screen.dart';
import 'new/booking_form_screen.dart';
import 'new/booking_new_args.dart';

/// Маршруты раздела «booking». Окна «Пришёл ответ» и «Пришёл отказ» `checkUpdates` показывает прозрачным
/// маршрутом [answerPopupRoute]; записи здесь — для `pushNamed` из других экранов.
final Map<String, RouteBuilder> bookingRoutes = {
  // Шторку брони открывает showBookingSheet; запись — для pushNamed поверх затемнения.
  AppRoutes.bookingNew: (context, args) => Scaffold(
        backgroundColor: AppColors.overlayScrim,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: BookingFormScreen(args: args as BookingNewArgs),
        ),
      ),
  AppRoutes.bookingAccepted: (context, args) => AcceptedPopup(bookingId: args as String),
  AppRoutes.bookingDeclined: (context, args) => const DeclinedPopup(),
  AppRoutes.bookingPaid: (context, args) => BookingPaidScreen(bookingId: args as String),
};
