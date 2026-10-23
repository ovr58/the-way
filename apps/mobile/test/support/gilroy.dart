import 'package:flutter/services.dart';

/// Подгружает настоящий Gilroy: без него тест рисует шрифт-заглушку (буква — квадрат), и проверки
/// ширины текста (переполнения вёрстки) ничего не стоят. Вызывать из `setUpAll`.
Future<void> loadGilroy() async {
  final loader = FontLoader('Gilroy');
  for (final weight in ['Regular', 'Medium', 'Semibold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Gilroy-$weight.ttf'));
  }
  await loader.load();
}
