@Tags(['slow'])
library;

import 'dart:io';
import 'dart:math';

import 'package:casio_tutor_calc/core/editor/lcd_cursor_tokens.dart';
import 'package:casio_tutor_calc/presentation/theme/calculator_themes.dart';
import 'package:casio_tutor_calc/presentation/theme/theme_controller.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/blinking_cursor_builder.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_blinking_latex.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_helpers.dart';
import 'support/exercise_dsl.dart';
import 'support/header_select.dart';

/// Stress-test determinista (semilla fija) del editor en M1-M12: borrado parcial,
/// parentesis sin cerrar, operadores repetidos, cambio de modo, AC + DESHACER, `=` vacio.
///
/// Tras CADA pulsacion: 0 excepciones (incluye RenderFlex overflow y errores de parser
/// KaTeX), ningun `Math` con error de parseo y ningun texto visible con LaTeX crudo.
final RegExp _leak = RegExp(r'extcolor|\\textcolor|\\left|\\right|\\mid|\\lcdcursor|\\frac|\\sqrt|[\t\f\x07]');

class _Audit {
  final WidgetTester t;
  final String scope;
  final List<FlutterErrorDetails> errors = [];
  final List<String> trail = [];
  late final void Function(FlutterErrorDetails)? _prev;

  _Audit(this.t, this.scope) {
    _prev = FlutterError.onError;
    FlutterError.onError = errors.add;
  }

  void dispose() => FlutterError.onError = _prev;

  /// Lanza una pulsacion y valida el estado resultante.
  Future<void> step(String action, Future<void> Function() run) async {
    trail.add(action);
    await run();
    final ex = t.takeException();
    if (ex != null) errors.add(FlutterErrorDetails(exception: ex));
    verify();
  }

  void verify() {
    final where = '[$scope] ${trail.length > 14 ? trail.sublist(trail.length - 14) : trail}';
    expect(errors, isEmpty, reason: '$where excepcion/overflow: ${errors.map((e) => e.exceptionAsString()).join('\n')}');
    for (final m in t.widgetList<Math>(find.byType(Math))) {
      expect(m.parseError, isNull, reason: '$where error de parseo KaTeX: ${m.parseError}');
    }
    for (final r in t.widgetList<RichText>(find.byType(RichText))) {
      final s = r.text.toPlainText();
      expect(_leak.hasMatch(s), isFalse, reason: '$where LaTeX crudo en pantalla: "$s"');
    }
  }
}

final List<String> _skip = ['MODE', 'SHIFT', 'ALPHA', 'ON'];

List<String> _labels(WidgetTester t) => {
      for (final k in t.widgetList<CasioPhysicalKey>(find.byType(CasioPhysicalKey)))
        if (!_skip.contains(k.label)) k.label
    }.toList()
      ..sort();

/// Una accion aleatoria: tecla, SHIFT/ALPHA + tecla, D-Pad, DEL (peso alto) o `=`.
Future<void> _randomAction(_Audit a, Random rnd) async {
  final t = a.t;
  final labels = _labels(t);
  final roll = rnd.nextInt(20);
  if (roll < 8) {
    final l = labels[rnd.nextInt(labels.length)];
    if (l == 'AC' && rnd.nextInt(4) != 0) return _randomAction(a, rnd);
    await a.step('key $l', () => key(t, l));
  } else if (roll < 12) {
    await a.step('DEL', () => key(t, 'DEL'));
  } else if (roll < 16) {
    final d = ['left', 'right', 'up', 'down'][rnd.nextInt(4)];
    await a.step('pad $d', () => pad(t, d));
  } else if (roll < 17) {
    await a.step('=', () => key(t, '='));
  } else if (roll < 18) {
    final l = labels.where((e) => e != 'AC' && e != 'DEL' && e != 'CALC').toList()[rnd.nextInt(labels.length - 3)];
    await a.step('SHIFT+$l', () => shiftKey(t, l));
  } else {
    final l = labels.where((e) => e != 'AC' && e != 'DEL' && e != 'CALC').toList()[rnd.nextInt(labels.length - 3)];
    await a.step('ALPHA+$l', () => alphaKey(t, l));
  }
}

Future<void> _script(_Audit a, String script) async {
  for (final tok in script.split(RegExp(r'\s+')).where((s) => s.isNotEmpty)) {
    await a.step(tok, () => seq(a.t, tok));
  }
}

void _fuzz(String name, int mode, int seed, {int steps = 40, List<Size> sizes = const [kPhone]}) {
  for (final size in sizes) {
    testWidgets('fuzz M$mode $name (${size.width.toInt()}x${size.height.toInt()}, semilla $seed)', (t) async {
      await boot(t, size: size);
      final a = _Audit(t, 'M$mode $name');
      try {
        final rnd = Random(seed + mode);
        if (mode != 1) await a.step('mode:$mode', () => goMode(t, mode));
        for (var i = 0; i < steps; i++) {
          await _randomAction(a, rnd);
        }
        // Vaciar con DEL desde el final y `=` con pantalla vacia/AC + DESHACER.
        for (var i = 0; i < 8; i++) {
          await a.step('DEL', () => key(t, 'DEL'));
        }
        await a.step('=', () => key(t, '='));
        await a.step('AC', () => key(t, 'AC'));
        await a.step('=', () => key(t, '='));
        await _randomAction(a, rnd);
      } finally {
        a.dispose();
      }
      expect(a.errors, isEmpty);
    });
  }
}

void main() {
  group('el detector funciona (autocomprobacion)', () {
    testWidgets('detecta LaTeX crudo, errores de parseo y overflow', (t) async {
      final a = _Audit(t, 'autotest');
      try {
        await t.pumpWidget(MaterialApp(
          home: Column(children: [
            const Text('\textcolor{#929F9C}{)}'),
            Math.tex(r'rac{1}{'),
            const SizedBox(width: 50, child: Row(children: [SizedBox(width: 400, height: 10)])),
          ]),
        ));
        final leaks = t.widgetList<RichText>(find.byType(RichText)).where((r) => _leak.hasMatch(r.text.toPlainText()));
        expect(leaks, isNotEmpty);
        expect(t.widgetList<Math>(find.byType(Math)).any((m) => m.parseError != null), isTrue);
        expect(a.errors, isNotEmpty); // el overflow quedo registrado por el colector
      } finally {
        a.dispose();
      }
    });
  });

  group('secuencias dirigidas M1', () {
    testWidgets('ln(5): DEL sobre ")", mover, + 2, =', (t) async {
      await boot(t, size: kPhone);
      final a = _Audit(t, 'M1 ln(5)');
      try {
        await _script(a, 'ln 5 > DEL < < + 2 =');
        await _script(a, 'AC ln 5 > DEL DEL DEL DEL + 2 =');
        await _script(a, 'AC sin 3 0 > DEL = AC');
      } finally {
        a.dispose();
      }
    });

    testWidgets('3 parentesis anidados sin cerrar: DEL desde medio y final hasta vaciar', (t) async {
      await boot(t, size: kPhone);
      final a = _Audit(t, 'M1 anidados');
      try {
        await _script(a, 'sin ln sqrt x');
        for (var i = 0; i < 6; i++) {
          await a.step('<', () => pad(t, 'left'));
          await a.step('DEL', () => key(t, 'DEL'));
        }
        for (var i = 0; i < 14; i++) {
          await a.step('DEL', () => key(t, 'DEL'));
        }
        await _script(a, '= sin ln sqrt x = AC');
      } finally {
        a.dispose();
      }
    });

    testWidgets('fracciones, raices y exponentes con DEL en posiciones arbitrarias', (t) async {
      await boot(t, size: kPhone);
      final a = _Audit(t, 'M1 plantillas');
      try {
        await _script(a, 'frac 1 > 2 > + sqrt 3 > + S:pow 2 > DEL DEL < < DEL DEL DEL DEL DEL DEL');
        await _script(a, 'AC ( ( ( 1 + 2 DEL DEL DEL ) ) = AC + + × × 3 = ÷ ÷ 0 =');
      } finally {
        a.dispose();
      }
    });
  });

  group('secuencias dirigidas M2, M6, M9, M11, M12', () {
    testWidgets('M2 ecuacion con fraccion', (t) async {
      await boot(t, size: kPhone);
      final a = _Audit(t, 'M2');
      try {
        await _script(a, 'mode:2 frac 2 x - 1 v 3 > = 5 DEL DEL DEL < < DEL = AC =');
      } finally {
        a.dispose();
      }
    });

    testWidgets('M6 inecuacion: parentesis abierto y signo', (t) async {
      await boot(t, size: kPhone);
      final a = _Audit(t, 'M6');
      try {
        await _script(a, 'mode:6 ( x + 1 DEL DEL DEL = AC ( x + 1 ) DEL < DEL = AC x S:pow DEL DEL =');
      } finally {
        a.dispose();
      }
    });

    testWidgets('M9 matrices', (t) async {
      await boot(t, size: kPhone);
      final a = _Audit(t, 'M9');
      try {
        await _script(a, 'mode:9 1 > 2 > 3 > 4 DEL DEL < < DEL = AC =');
      } finally {
        a.dispose();
      }
    });

    testWidgets('M12 derivadas e integrales', (t) async {
      await boot(t, size: kPhone);
      final a = _Audit(t, 'M12');
      try {
        await _script(a, 'mode:12 x S:pow 3 > + sin x DEL DEL < DEL = AC x DEL DEL DEL =');
      } finally {
        a.dispose();
      }
    });
  });

  // Aleatorio determinista en los modos con editor de expresion o celdas.
  for (final (mode, name) in [
    (1, 'Calcular'),
    (2, 'Ecuaciones'),
    (3, 'Sistemas'),
    (4, 'Polinomios'),
    (5, 'Funciones'),
    (6, 'Inecuaciones'),
    (7, 'Sistemas de inecuaciones'),
    (8, 'Estadistica'),
    (9, 'Matrices'),
    (10, 'Vectores'),
    (11, 'Complejos'),
    (12, 'Derivadas e integrales'),
  ]) {
    _fuzz(name, mode, 20260519, sizes: [kPhone, if (const [1, 6, 12].contains(mode)) kDesktop]);
  }

  testWidgets('fuzz en los 5 temas (M1 movil + M6 escritorio)', (t) async {
    final a = _Audit(t, 'temas');
    try {
      for (final hw in HardwareThemes.all) {
        ThemeController.instance.select(hw, persist: false);
        await boot(t, size: kPhone);
        ThemeController.instance.select(hw, persist: false);
        await t.pumpAndSettle();
        a.trail.add('tema ${hw.id}');
        final rnd = Random(7);
        for (var i = 0; i < 18; i++) {
          await _randomAction(a, rnd);
        }
        await _script(a, 'AC ln 5 > DEL = AC');
      }
    } finally {
      a.dispose();
      ThemeController.instance.resetForTests();
    }
  });

  group('cursor de ancho 0 en la LCD', () {
    List<double> glyphXs(WidgetTester t) {
      final math = find.descendant(of: find.byType(LcdBlinkingLatex), matching: find.byType(Math));
      final xs = <double>[];
      void visit(RenderObject r) {
        if (r is RenderBox && r.hasSize && r.size.width > 3) {
          xs.add(double.parse(r.localToGlobal(Offset.zero).dx.toStringAsFixed(3)));
        }
        r.visitChildren(visit);
      }

      visit(t.renderObject(math.first));
      return xs;
    }

    testWidgets('mover ◀ ▶ entre 1 y 2 en 1234 no desplaza digitos; parpadear tampoco', (t) async {
      await boot(t, size: kPhone);
      await seq(t, '1 2 3 4');
      final mathF = find.descendant(of: find.byType(LcdBlinkingLatex), matching: find.byType(Math));
      expect(lcd(t).currentInputLatex, contains(LcdCursor.bar));
      final base = glyphXs(t);
      final baseW = t.getSize(mathF.first).width;
      for (final move in ['<', '<', '<', '>', '>', '<', '<', '<']) {
        await seq(t, move);
        expect(t.takeException(), isNull);
        expect(glyphXs(t), base, reason: 'tras $move los digitos se desplazaron');
        expect(t.getSize(mathF.first).width, closeTo(baseW, 0.001));
      }
      // Parpadeo real: visible -> oculto -> visible.
      LcdBlink.enabled = true;
      LcdBlink.markActivity();
      await t.pump(const Duration(milliseconds: 10));
      final on = glyphXs(t);
      await t.pump(LcdBlink.period + const Duration(milliseconds: 20));
      final off = glyphXs(t);
      await t.pump(LcdBlink.period);
      final on2 = glyphXs(t);
      expect(on, base);
      expect(off, base, reason: 'el parpadeo mueve los digitos');
      expect(on2, base);
      LcdBlink.enabled = false;
      await t.pumpWidget(const SizedBox()); // cancela los Timer
    });
  });

  group('estatico sobre lib/', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    test('ningun .dart de lib/ supera las 500 lineas', () {
      final big = [for (final f in files) if (f.readAsLinesSync().length >= 500) f.path];
      expect(big, isEmpty);
    });

    test('ningun cursor \\mid ni string no-raw que se coma un comando LaTeX', () {
      // `\t\f\b\v` + sufijo de comando conocido en un string NO raw = comando destruido.
      final bad = RegExp(r'(?<!\\)\\[tfbv](extcolor|rac|inom|ext|imes|heta|fl)');
      final hits = <String>[];
      for (final f in files) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (RegExp(r'textcolor\{[^}]*\}\{\\mid\}').hasMatch(line)) hits.add('${f.path}:${i + 1} usa \\mid como cursor');
          for (final m in bad.allMatches(line)) {
            // Conservador: cualquier `r'` / `r"` antes del hallazgo en la linea cuenta como raw.
            final raw = RegExp('''(^|[^A-Za-z0-9_])r['"]''').hasMatch(line.substring(0, m.start));
            if (!raw) hits.add('${f.path}:${i + 1} escape perdido: ${line.trim()}');
          }
        }
      }
      expect(hits, isEmpty, reason: hits.join('\n'));
    });
  });
}
