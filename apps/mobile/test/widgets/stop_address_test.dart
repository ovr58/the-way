import 'package:api_client/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/widgets/trip_card_view.dart';

/// Адрес точки везде — «Город, улица, дом»: город приписывается к адресу без задвоения.
void main() {
  Stop stop(String city, String address, [String? short]) =>
      Stop(idx: 0, cityId: 1, cityName: city, address: address, shortAddress: short ?? address);

  group('withCity', () {
    test('адрес без города (seed) — город спереди', () {
      expect(withCity('Ярославль', 'улица Свободы, 62'), 'Ярославль, улица Свободы, 62');
    });
    test('адрес уже с городом (подсказка) — без задвоения', () {
      expect(withCity('Краснотурьинск', 'Краснотурьинск, улица Попова, 18'), 'Краснотурьинск, улица Попова, 18');
    });
    test('пустой адрес — город', () => expect(withCity('Серов', ''), 'Серов'));
    test('адрес — сам город — город', () => expect(withCity('Серов', 'Серов'), 'Серов'));
    test('город неизвестен (ввод, подсказка в черновике) — адрес как есть', () {
      expect(withCity('', 'Ярославль, улица Свободы, 1'), 'Ярославль, улица Свободы, 1');
    });
  });

  test('stopAddress — город и адрес', () {
    expect(stopAddress(stop('Ярославль', 'улица Свободы, 62')), 'Ярославль, улица Свободы, 62');
  });

  group('cardAddress', () {
    test('короткий адрес — с городом', () {
      expect(
        cardAddress(stop('Краснотурьинск', 'Краснотурьинск, улица Попова, 18', 'улица Попова, 18')),
        'Краснотурьинск, улица Попова, 18',
      );
    });
    test('точка-город: область из полного адреса, если она в данных есть', () {
      expect(cardAddress(stop('Серов', 'Серов, Свердловская область', 'Серов')), 'Серов, Свердловская область');
    });
    test('точка-город без области в данных — только город', () {
      expect(cardAddress(stop('Серов', 'Серов', 'Серов')), 'Серов');
      expect(cardAddress(stop('Серов', '', '')), 'Серов');
    });
  });
}
