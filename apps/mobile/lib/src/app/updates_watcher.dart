import 'dart:async';

import 'package:flutter/widgets.dart';

import '../features/booking/answers/updates_flow.dart';

/// Проверка событий (`GET /updates`). Тело — `runUpdatesCheck`: одна проверка за раз,
/// вторая присоединяется к идущей.
Future<void> checkUpdates(BuildContext context) => runUpdatesCheck(context);

/// Автообновление событий (принятое решение 2026-10-22): пока приложение на переднем плане, проверка
/// раз в [interval] от конца предыдущей; в фоне таймер стоит ([pause]), при возврате — проверка сразу
/// ([resume]). Ручное обновление ([refresh], жест «потянуть вниз») делает ту же проверку и сбрасывает таймер.
/// Одна проверка за раз: и ручная, и тик таймера во время идущей присоединяются к ней (тот же `Future`), а
/// следующий тик — через [interval] от её конца.
class UpdatesPoller {
  UpdatesPoller({this.interval = const Duration(seconds: 30)});

  final Duration interval;

  Future<void> Function()? _check;
  Timer? _timer;
  Future<void>? _pending;
  bool _active = false;

  /// Проверка завершилась (по таймеру или вручную; присоединённая — один раз): экраны, которые должны
  /// обновляться на каждом тике (лента заказов водителя), слушают это.
  final ticks = ValueNotifier<int>(0);

  /// Оболочка даёт проверку (со своим контекстом); без неё [refresh] ничего не делает. Незавершённая
  /// проверка прежней оболочки забывается: её окна ушли вместе с ней (повтор не задвоит окно —
  /// `runUpdatesCheck` сам присоединяет второй вызов к идущему).
  void attach(Future<void> Function() check) {
    _check = check;
    _pending = null;
  }

  /// Снять проверку. [owner] — та, что давалась в [attach]: новая оболочка подключается раньше, чем
  /// снимается старая (`pushNamedAndRemoveUntil`), и старая не должна отключить новую.
  void detach([Future<void> Function()? owner]) {
    if (owner != null && owner != _check) return;
    pause();
    _check = null;
    _pending = null;
  }

  /// Приложение на переднем плане: проверка сразу и таймер.
  void resume() {
    _active = true;
    refresh();
  }

  /// Приложение в фоне: таймер стоит.
  void pause() {
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Проверить сейчас: идущая проверка — присоединиться к ней; иначе новая, таймер — от её конца.
  Future<void> refresh() {
    final pending = _pending;
    if (pending != null) return pending;
    final check = _check;
    if (check == null) return Future<void>.value();
    _timer?.cancel();
    _timer = null;
    late final Future<void> run;
    run = check().catchError((Object _) {}).whenComplete(() {
      // Забытая проверка (оболочку сменили) таймер не ставит: цепочка одна.
      if (!identical(_pending, run)) return;
      _pending = null;
      ticks.value++;
      if (_active && _check != null) _timer = Timer(interval, refresh);
    });
    _pending = run;
    return run;
  }
}

/// Автообновление оболочки: одно на приложение.
final updatesPoller = UpdatesPoller();

/// Ручное обновление списка (жест «потянуть вниз»): та же проверка событий, таймер сбрасывается.
Future<void> refreshUpdates() => updatesPoller.refresh();
