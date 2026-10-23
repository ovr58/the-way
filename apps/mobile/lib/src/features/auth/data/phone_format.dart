import 'dart:math';

import 'package:flutter/services.dart';

const _minDigits = 8;
const _maxDigits = 15;
// С кодом страны `+7` или `+1` — ровно 11 цифр.
const _shortCountryDigits = 11;
const _groupsShortCountry = [3, 3, 2, 2];
const _groupsLongCountry = [2, 3, 2, 2];

/// Только цифры номера.
String phoneDigits(String input) => input.replaceAll(RegExp(r'\D'), '');

/// Номер для показа: «+» и цифры группами, как в кадре «+375 25 777 44 20». Код страны из одной
/// цифры — только `1` и `7`, остальные — из трёх; дальше группы 2-3-2-2… (для `7` и `1` — 3-3-2-2…).
String formatPhone(String input) {
  var digits = phoneDigits(input);
  if (digits.isEmpty) return '';
  if (digits.length > _maxDigits) digits = digits.substring(0, _maxDigits);
  final countryLength = (digits[0] == '7' || digits[0] == '1') ? 1 : 3;
  final groups = <String>[digits.substring(0, min(countryLength, digits.length))];
  final sizes = countryLength == 1 ? _groupsShortCountry : _groupsLongCountry;
  var pos = groups.first.length;
  var i = 0;
  while (pos < digits.length) {
    final size = i < sizes.length ? sizes[i] : 2;
    groups.add(digits.substring(pos, min(pos + size, digits.length)));
    pos += size;
    i++;
  }
  return '+${groups.join(' ')}';
}

/// Номер годится для запроса кода: 8–15 цифр (E.164); с кодом `+7` или `+1` — ровно 11.
bool isValidPhone(String input) {
  final digits = phoneDigits(input);
  if (digits.startsWith('7') || digits.startsWith('1')) return digits.length == _shortCountryDigits;
  return digits.length >= _minDigits && digits.length <= _maxDigits;
}

/// Номер для сервера: «+» и цифры без пробелов.
String toE164(String input) => '+${phoneDigits(input)}';

/// Подставляет «+» и пробелы по мере ввода.
class PhoneInputFormatter extends TextInputFormatter {
  const PhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = formatPhone(newValue.text);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
