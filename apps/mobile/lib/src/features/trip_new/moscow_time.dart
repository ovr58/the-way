import 'package:flutter/material.dart' show TimeOfDay;

/// Время поездки задаётся в поясе `Europe/Moscow`: UTC+3 круглый год, без перехода.
const moscowOffset = Duration(hours: 3);

/// Шаг времени отправления — 30 минут (`invalid_time_step`), поездки — не дальше 3 дней вперёд.
const timeStepMinutes = 30;
const maxDaysAhead = 3;

/// Сегодняшняя дата по Москве (только год, месяц, день).
DateTime moscowToday([DateTime? now]) {
  final wall = (now ?? DateTime.now()).toUtc().add(moscowOffset);
  return DateTime(wall.year, wall.month, wall.day);
}

/// Самое позднее время выезда в московский день [date] в окне публикации — [maxDaysAhead] суток
/// от [now] (сервер: `too_far_ahead`), с шагом [timeStepMinutes]. `null` — день внутри окна, ограничения
/// по времени нет. Дни за окном календарь не предлагает.
TimeOfDay? latestDepartOn(DateTime date, DateTime now) {
  final (lastDay, lastTime) = toMoscow(now.add(const Duration(days: maxDaysAhead)));
  if (date.isBefore(lastDay)) return null;
  return TimeOfDay(hour: lastTime.hour, minute: lastTime.minute - lastTime.minute % timeStepMinutes);
}

int _minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

/// Следующий получас после [now] по Москве — в минутах от полуночи (1440 и больше — сегодня слотов нет).
int _nextSlotMinutes(DateTime now) {
  final (_, time) = toMoscow(now);
  return (_minutesOf(time) ~/ timeStepMinutes + 1) * timeStepMinutes;
}

/// Самое раннее время выезда в московский день [date]: сегодня — следующий получас после [now] (сервер:
/// «Отправление в прошлом», шаг 30 минут); другие дни — `null`, ограничения нет. Если сегодня слотов
/// не осталось ([hasDepartSlotsOn] — `false`), возвращает последний слот суток.
TimeOfDay? earliestDepartOn(DateTime date, DateTime now) {
  if (date != toMoscow(now).$1) return null;
  final next = _nextSlotMinutes(now).clamp(0, 24 * 60 - timeStepMinutes);
  return TimeOfDay(hour: next ~/ 60, minute: next % 60);
}

/// Есть ли в московском дне [date] допустимое время выезда (сегодня после 23:30 — нет).
bool hasDepartSlotsOn(DateTime date, DateTime now) => date != toMoscow(now).$1 || _nextSlotMinutes(now) < 24 * 60;

/// Время выезда [time] на день [date] — внутри окна публикации: не раньше «сейчас» и не позже
/// «сейчас» + [maxDaysAhead] суток.
bool departWithinWindow(DateTime date, TimeOfDay time, DateTime now) {
  final minutes = _minutesOf(time);
  final earliest = earliestDepartOn(date, now);
  final latest = latestDepartOn(date, now);
  return (earliest == null || minutes >= _minutesOf(earliest)) && (latest == null || minutes <= _minutesOf(latest));
}

/// Момент по московской дате и времени. Результат — UTC, тот же миг, что «[date] [time] +03:00».
DateTime fromMoscow(DateTime date, TimeOfDay time) =>
    DateTime.utc(date.year, date.month, date.day, time.hour, time.minute).subtract(moscowOffset);

/// Московская дата и время момента [instant].
(DateTime, TimeOfDay) toMoscow(DateTime instant) {
  final wall = instant.toUtc().add(moscowOffset);
  return (DateTime(wall.year, wall.month, wall.day), TimeOfDay(hour: wall.hour, minute: wall.minute));
}

/// Время прибытия: на дату отправления, а если не позже времени отправления — на следующие сутки.
DateTime arrivalFrom(DateTime date, TimeOfDay depart, TimeOfDay arrive) {
  final next = arrive.hour * 60 + arrive.minute <= depart.hour * 60 + depart.minute;
  final day = next ? DateTime(date.year, date.month, date.day + 1) : date;
  return fromMoscow(day, arrive);
}

/// `YYYY-MM-DD` для `GET /trips/limits`.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// `ДД.ММ.ГГГГ` — как «04.06.2026» в кадрах.
String ruDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year.toString().padLeft(4, '0')}';

/// `Ч:ММ` — как «8:00» в кадрах.
String ruTime(TimeOfDay t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
