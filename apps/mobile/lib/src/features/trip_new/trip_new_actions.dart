import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/session.dart';
import 'data/trip_new_repository.dart';
import 'wizard_controller.dart';

/// Код ошибки сервера (`{code, message}`) из исключения запроса; `null` — не ответ сервера.
String? apiErrorCode(Object error) {
  if (error is! DioException) return null;
  final data = error.response?.data;
  final code = data is Map ? data['code'] : null;
  return code is String ? code : null;
}

/// Текст ошибки действия мастера по коду (сообщение сервера не показывается).
String tripErrorText(AppLocalizations l10n, Object error) => switch (apiErrorCode(error)) {
      'too_far_ahead' => l10n.tripNewErrorTooFar,
      'invalid_time_step' => l10n.tripNewErrorTimeStep,
      'validation' => l10n.tripNewErrorValidation,
      'car_invalid' => l10n.tripNewErrorCar,
      'edit_locked' => l10n.tripNewErrorEditLocked,
      'seats_below_taken' => l10n.tripNewErrorSeatsBelowTaken,
      // Отклик новой поездкой: заказ взят или поездка не подходит — поездка не создана.
      'order_unavailable' => l10n.driverOrdersErrorUnavailable,
      'order_mismatch' => l10n.orderErrorMismatch,
      _ => l10n.tripNewErrorGeneric,
    };

/// Текст ошибки публикации заказа пассажира по коду; `null` — подсказки нет: на `blocked` экран
/// блокировки открывает перехватчик (`app/http.dart`, путь `POST /orders`).
String? orderErrorText(AppLocalizations l10n, Object error) => switch (apiErrorCode(error)) {
      'too_far_ahead' => l10n.orderErrorTooFar,
      'invalid_time_step' => l10n.tripNewErrorTimeStep,
      'validation' => l10n.orderErrorValidation,
      'blocked' => null,
      _ => l10n.tripNewErrorGeneric,
    };

void showTripSnack(ScaffoldMessengerState messenger, String text) =>
    messenger.showSnackBar(SnackBar(content: Text(text)));

/// «Сохранить шаблон» («Новый заказ - Выбор доп услуг»/«Новый заказ - Выбор доп услуг», «Новый заказ - Маршрут сохранен»): маршрут черновика → `POST /route-templates`, снэкбар
/// «Шаблон сохранён». Возвращает `true`, если шаблон сохранён.
Future<bool> saveRouteTemplate(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  WizardController controller,
) async {
  try {
    await controller.repository.saveTemplate(controller.stopInputs);
    showTripSnack(messenger, l10n.tripNewTemplateSaved);
    return true;
  } catch (_) {
    showTripSnack(messenger, l10n.tripNewTemplateFailed);
    return false;
  }
}

/// Репозиторий раздела на `TheWayApi` сессии. Можно звать из `initState`: подписки на сессию нет.
TripNewRepository tripNewRepositoryOf(BuildContext context) =>
    TripNewRepository(context.getInheritedWidgetOfExactType<AppSessionScope>()!.notifier!.api);
