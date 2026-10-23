// Порождает lib/src/theme/{app_colors,app_type,app_size}.dart из design/tokens/*.json и
// design/frame-specs/components/*.json. Запуск из apps/mobile: `dart run tool/build_tokens.dart`.
// Руками порождённые файлы не править: правка идёт в токенах и повторном запуске.
import 'dart:convert';
import 'dart:io';

const _header = '// GENERATED CODE - DO NOT MODIFY BY HAND\n'
    '// Источник: design/tokens, design/frame-specs/components. Сборка: dart run tool/build_tokens.dart\n';

void main() {
  final root = Directory.current.path.replaceAll(r'\', '/');
  final design = '$root/../../design';
  final out = '$root/lib/src/theme';
  Directory(out).createSync(recursive: true);
  File('$out/app_colors.dart').writeAsStringSync(_colors(_readJson('$design/tokens/colors.json')));
  File('$out/app_type.dart').writeAsStringSync(_types(_readJson('$design/tokens/typography.json'), _lineHeights(design)));
  File('$out/app_size.dart').writeAsStringSync(_sizes(design));
}

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

String _camel(List<String> parts) {
  final words = parts.expand((p) => p.split('-')).toList();
  return words.first + words.skip(1).map((w) => w[0].toUpperCase() + w.substring(1)).join();
}

/// Обходит токены DTCG: узел с `$type` — токен, иначе группа.
Iterable<MapEntry<List<String>, Map<String, dynamic>>> _tokens(Map<String, dynamic> node, [List<String> path = const []]) sync* {
  for (final e in node.entries) {
    final value = e.value as Map<String, dynamic>;
    if (value.containsKey(r'$type')) {
      yield MapEntry([...path, e.key], value);
    } else {
      yield* _tokens(value, [...path, e.key]);
    }
  }
}

String _colors(Map<String, dynamic> json) {
  final b = StringBuffer(_header)
    ..writeln("import 'dart:ui';")
    ..writeln()
    ..writeln('/// Цвета проекта (светлая тема). Имя токена `group.name` → `groupName`.')
    ..writeln('abstract final class AppColors {');
  for (final t in _tokens(json)) {
    final hex = (t.value[r'$value'] as String).substring(1).toUpperCase();
    final opacity = ((t.value[r'$extensions'] as Map<String, dynamic>?)?['opacity'] as num?) ?? 1;
    final alpha = (opacity * 255).round().toRadixString(16).toUpperCase().padLeft(2, '0');
    b.writeln('  /// `${t.key.join('.')}` #$hex${opacity == 1 ? '' : ' @ $opacity'}');
    b.writeln('  static const Color ${_camel(t.key)} = Color(0x$alpha$hex);');
  }
  b.writeln('}');
  return b.toString();
}

/// Межстрочные множители из кадров: самый частый для пары (вес, кегль) по строкам `font` вида
/// `Gilroy 600 15/1.3333333333333333`. В токенах типографики высоты строки нет.
Map<String, double> _lineHeights(String design) {
  final counts = <String, Map<double, int>>{};
  final re = RegExp(r'Gilroy (\d+) (\d+)/([\d.]+)');
  for (final f in Directory('$design/frame-specs').listSync().whereType<File>()) {
    if (!f.path.endsWith('.json')) continue;
    for (final m in re.allMatches(f.readAsStringSync())) {
      final byRatio = counts.putIfAbsent('${m[1]}/${m[2]}', () => {});
      final ratio = double.parse(m[3]!);
      byRatio[ratio] = (byRatio[ratio] ?? 0) + 1;
    }
  }
  return {
    for (final e in counts.entries)
      e.key: (e.value.entries.toList()
            ..sort((a, b) => b.value != a.value ? b.value - a.value : a.key.compareTo(b.key)))
          .first
          .key,
  };
}

String _types(Map<String, dynamic> json, Map<String, double> lineHeights) {
  final b = StringBuffer(_header)
    ..writeln("import 'package:flutter/painting.dart';")
    ..writeln()
    ..writeln('/// Текстовые стили проекта (Gilroy). Группа `titles` + `title-3` → `title3`.')
    ..writeln('abstract final class AppType {');
  for (final t in _tokens(json)) {
    final group = t.key.first;
    final name = t.key.last;
    final singular = group.endsWith('s') ? group.substring(0, group.length - 1) : group;
    final id = name.startsWith(singular) ? _camel([name]) : _camel([group, name]);
    final v = t.value[r'$value'] as Map<String, dynamic>;
    b.writeln('  /// `${t.key.join('.')}`');
    b.writeln('  static const TextStyle $id = TextStyle(');
    b.writeln("    fontFamily: '${v['fontFamily']}',");
    b.writeln('    fontWeight: FontWeight.w${v['fontWeight']},');
    b.writeln('    fontSize: ${v['fontSize']},');
    final height = lineHeights['${v['fontWeight']}/${v['fontSize']}'];
    if (height != null) b.writeln('    height: ${double.parse(height.toStringAsFixed(4))},');
    b.writeln('  );');
  }
  b.writeln('}');
  return b.toString();
}

String _sizes(String design) {
  final strokes = <int>{}, pads = <int>{}, gaps = <int>{}, radii = <int>{}, icons = <int>{}, heights = <int>{};
  void add(Set<int> set, Object? v) {
    if (v is num && v == v.truncate() && v > 0) set.add(v.toInt());
  }

  void walk(Object? n) {
    if (n is List) {
      n.forEach(walk);
    } else if (n is Map<String, dynamic>) {
      final flex = n['flex'];
      if (flex is Map<String, dynamic>) {
        add(gaps, flex['gap']);
        for (final p in (flex['pad'] as List? ?? const [])) {
          add(pads, p);
        }
      }
      add(radii, n['r']);
      for (final st in (n['stroke'] as List? ?? const [])) {
        final w = RegExp(r'/([\d.]+)$').firstMatch(st as String)?[1];
        if (w != null) add(strokes, double.parse(w));
      }
      final name = n['n'];
      if (name is String && name.contains(' / ') && n['w'] == n['h']) add(icons, n['w']);
      n.values.forEach(walk);
    }
  }

  final files = Directory('$design/frame-specs/components').listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    walk(json);
    for (final v in (json['variants'] as List? ?? const [])) {
      add(heights, (v as Map<String, dynamic>)['spec']['h']);
    }
  }
  // Радиусы листов, окон и карточек живут в кадрах, а не в компонентах: берём и их.
  // Отступы и промежутки кадров входят в шкалу, если встречаются не реже 100 раз на все кадры.
  final frameGaps = <int, int>{}, framePads = <int, int>{};
  void walkFrames(Object? n) {
    if (n is List) {
      n.forEach(walkFrames);
    } else if (n is Map<String, dynamic>) {
      add(radii, n['r']);
      if (n['n'] == 'Button') add(heights, n['h']);
      final flex = n['flex'];
      if (flex is Map<String, dynamic>) {
        final g = flex['gap'];
        if (g is int && g > 0) frameGaps[g] = (frameGaps[g] ?? 0) + 1;
        for (final p in (flex['pad'] as List? ?? const [])) {
          if (p is int && p > 0) framePads[p] = (framePads[p] ?? 0) + 1;
        }
      }
      n.values.forEach(walkFrames);
    }
  }

  for (final f in Directory('$design/frame-specs').listSync().whereType<File>()) {
    if (f.path.endsWith('.json')) walkFrames(jsonDecode(f.readAsStringSync()));
  }
  gaps.addAll(frameGaps.entries.where((e) => e.value >= 100).map((e) => e.key));
  pads.addAll(framePads.entries.where((e) => e.value >= 100).map((e) => e.key));
  // Радиусы от 75 и выше — круг (скругление больше половины любой стороны): одна ступень.
  final round = radii.where((r) => r >= 75).isNotEmpty;
  radii.removeWhere((r) => r >= 75);

  final b = StringBuffer(_header)
    ..writeln('/// Шкала размеров из макета: отступы (`flex.pad`), промежутки (`gap`),')
    ..writeln('/// радиусы, иконки и высоты компонентов. Дробные значения импорта Figma → Penpot')
    ..writeln('/// (1.5, 5.25, 8.25, 4.3) в шкалу не входят.')
    ..writeln('abstract final class AppSize {');
  void emit(String prefix, Set<int> set) {
    for (final v in (set.toList()..sort())) {
      b.writeln('  static const double $prefix$v = $v;');
    }
  }

  emit('pad', pads);
  emit('gap', gaps);
  emit('radius', radii);
  if (round) b.writeln('  /// Круг / таблетка.\n  static const double radiusFull = 999;');
  emit('icon', icons);
  emit('height', heights);
  emit('stroke', strokes);
  b.writeln('}');
  return b.toString();
}
