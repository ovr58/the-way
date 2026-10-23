import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/l10n/app_localizations_ru.dart';

/// Принятое решение 2026-10-23: суммы в рублях везде «N ₽» с пробелом, как итоги (`commonPrice`);
/// кадры рисуют «150₽» без пробела — принятое отступление (docs/DESIGN_CHANGES.md).
void main() {
  final l10n = AppLocalizationsRu();

  test('доп. услуги и посылки: «+150 ₽», «до 350 ₽», «150 ₽» — пробел перед ₽, как в commonPrice', () {
    final sep = l10n.commonPrice(1).substring(1, 2);
    expect(l10n.bookingExtraPrice(150), '+150$sep₽');
    expect(l10n.bookingParcelUpTo(350), 'до 350$sep₽');
    expect(l10n.tripNewExtraUpTo(350), 'до 350$sep₽');
    expect(l10n.tripNewExtraPrice(150), '150$sep₽');
  });
}
