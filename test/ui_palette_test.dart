import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Casio anti-slop: prohibido azul/cian/violeta en controles de la UI.
/// (Las graficas, el sticker de exportacion y el tutor IA conservan su propia paleta de dibujo.)
void main() {
  test('ningun control de lib/presentation usa azul, cian o violeta saturado', () {
    const allowed = [
      'painters/',
      'number_line_painter.dart',
      'casio_graph_canvas.dart',
      'goodnotes_sticker_canvas.dart',
      'ai_tutor_sheet.dart',
    ];
    final re = RegExp(r'0x[Ff][Ff]([0-9A-Fa-f]{6})');
    final offenders = <String>[];
    for (final f in Directory('lib/presentation').listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') || allowed.any(path.contains)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in re.allMatches(lines[i])) {
          final c = Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
          final hsv = HSVColor.fromColor(c);
          final cool = hsv.hue >= 190 && hsv.hue <= 300;
          if (cool && hsv.saturation > 0.45 && hsv.value > 0.35) {
            offenders.add('$path:${i + 1} ${m.group(0)}');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
    expect(math.pi, isNonZero);
  });
}
