import 'dart:math' as math;

import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/exact/ext_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/systems_free/free_system_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/systems_free/nd_common.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/systems_free/nonlinear_numeric_nd_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/trig_and_angles_solver.dart' show AngleUnit;
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_error_text.dart';
import 'package:casio_tutor_calc/presentation/widgets/modes/mode_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_helpers.dart';
import 'support/exercise_dsl.dart';

StepByStepResolution solve(List<String> l, List<String> r, {AngleUnit unit = AngleUnit.rad}) =>
    FreeSystemSolver.solve(l, r, unit: unit);

NdSystem ndOf(List<String> l, List<String> r, {AngleUnit unit = AngleUnit.rad}) {
  XParse p(String s) => ExtParser().parse(ExpressionParser.finalizeForEvaluation(s.isEmpty ? '0' : s));
  return NdSystem(l.length, [for (var i = 0; i < l.length; i++) (p(l[i]), p(r[i]))], unit, '');
}

typedef XParse = dynamic;

/// Soluciones `(a, b, ...)` de `exactResultLatex` como numeros.
List<List<double>> sols(StepByStepResolution r) {
  final txt = r.exactResultLatex.replaceAll(r'\left', '').replaceAll(r'\right', '').replaceAll(r'\,', '').replaceAll('{,}', '.');
  return [
    for (final m in RegExp(r'\(([^()]*)\)').allMatches(txt))
      [
        for (final part in m.group(1)!.split(','))
          if (part.contains('frac'))
            () {
              final f = RegExp(r'(-?)\\frac\{(\d+)\}\{(\d+)\}').firstMatch(part)!;
              return (f.group(1) == '-' ? -1 : 1) * int.parse(f.group(2)!) / int.parse(f.group(3)!);
            }()
          else
            double.parse(part),
      ],
  ];
}

bool has(List<List<double>> all, List<double> want, {double tol = 1e-3}) =>
    all.any((s) => s.length == want.length && List.generate(s.length, (i) => (s[i] - want[i]).abs() < tol).every((b) => b));

void main() {
  group('ALPHA y log con base en M3 libre', () {
    bool alphaOn(WidgetTester t) => t.widget<CasioPhysicalKey>(find.byWidgetPredicate((w) => w is CasioPhysicalKey && w.label == '1')).isAlphaActive;

    testWidgets('ALPHA se activa, se desactiva con la 2.a pulsacion y se limpia al escribir', (t) async {
      await boot(t);
      await goMode(t, 3);
      expect(alphaOn(t), isFalse);
      await tapF(t, find.text('ALPHA'));
      expect(alphaOn(t), isTrue);
      await tapF(t, find.text('ALPHA'));
      expect(alphaOn(t), isFalse);
      await tapF(t, find.text('ALPHA'));
      await key(t, ')');
      expect(alphaOn(t), isFalse);
      expect(t.takeException(), isNull);
    });

    test('LOG inserta log_ con el cursor en la base; ▶ ◀ y DEL mantienen el par balanceado', () {
      final f = ModeFormState(layouts: [
        [ModeField('a', expr: true)]
      ]);
      f.key('LOG');
      expect(f.fields[0].text, startsWith('log_('));
      f.key('2');
      expect(f.fields[0].text, contains('2'));
      f.dpad('right'); // base -> argumento
      f.key(')', alpha: true);
      expect(f.fields[0].text, contains('x'));
      f.dpad('right'); // sale tras )
      f.dpad('left'); // vuelve al argumento
      f.dpad('left');
      f.dpad('left'); // a la base
      final before = f.fields[0].text;
      expect('('.allMatches(before).length, ')'.allMatches(before).length);
      f.key('DEL');
      final after = f.fields[0].text;
      expect('('.allMatches(after).length, ')'.allMatches(after).length);
    });

    test('log_2(x) + log_2(y) = 5, x - y = 4 -> (8, 4)', () {
      final r = solve(['log_(2,x)+log_(2,y)', 'x-y'], ['5', '4']);
      expect(has(sols(r), [8, 4]), isTrue, reason: r.exactResultLatex);
      expect(has(sols(r), [-4, -8]), isFalse);
      expectCleanNotes(r);
    });

    test('base invalida del logaritmo da un error en mayuscula', () {
      expect(() => solve(['log_(1,x)+y', 'x-y'], ['2', '1']), throwsFormatException);
    });
  });

  group('Error en la LCD: pista de logaritmo solo en errores de dominio', () {
    test('"Ecuacion no soportada ... logaritmos" no sugiere el argumento del logaritmo', () {
      final i = LcdErrorText.info('Ecuación no soportada: usa polinomios, fracciones, logaritmos o exponenciales.', syntax: false);
      expect(i.hint, isNot(contains('argumento del logaritmo')));
      expect(i.hint, contains('sintaxis'));
    });

    test('dominio logaritmico real si sugiere argumento > 0', () {
      expect(LcdErrorText.info('Error de dominio logarítmico: log(-5)', syntax: false).hint, contains('argumento del logaritmo'));
      expect(LcdErrorText.info('El argumento de ln(0) no es válido', syntax: false).hint, contains('argumento del logaritmo'));
    });
  });

  group('Constantes trascendentes', () {
    for (final unit in [AngleUnit.deg, AngleUnit.rad]) {
      test('log(5)·sin(5)·x = 8 y 5xy = 3 (${unit.name})', () {
        final r = solve(['log(5)sin(5)x', '5xy'], ['8', '3'], unit: unit);
        final k = (math.log(5) / math.ln10) * math.sin(unit == AngleUnit.deg ? 5 * math.pi / 180 : 5);
        final x = 8 / k, y = 3 / (5 * x);
        expect(has(sols(r), [x, y], tol: 6e-4 * (1 + x.abs() + y.abs())), isTrue, reason: '${r.exactResultLatex} vs ($x, $y)');
        expectCleanNotes(r);
      });
    }
  });

  group('Lineal desordenado 4x4', () {
    test('x+y+z+w=10, 2(x-y)+z=1, w-(x+z)=0, 3x+y/2=w -> (1, 2, 3, 4)', () {
      final r = solve(['x+y+z+w', '2(x-y)+z', 'w-(x+z)', '3x+y/2'], ['10', '1', '0', 'w']);
      expect(norm(r.exactResultLatex), 'x=1,y=2,z=3,w=4');
      expectCleanNotes(r);
    });
  });

  group('Cambios de variable N x N', () {
    test('3x3 racional (1/x, 1/y, 1/z)', () {
      final r = solve(['1/x+1/y', '1/y+1/z', '1/x+1/z'], ['3/2', '3/4', '5/4']);
      expect(has(sols(r), [1, 2, 4]), isTrue, reason: r.exactResultLatex);
      expectCleanNotes(r);
    });

    test('3x3 logaritmico mezclado con lineales', () {
      final r = solve(['ln(x)+y+z', 'ln(x)-y+z', 'ln(x)+y-z'], ['4', '2', '0']);
      expect(has(sols(r), [math.e, 1, 2]), isTrue, reason: r.exactResultLatex);
      expectCleanNotes(r);
    });

    test('3x3 exponencial 2^x + 3^y + z', () {
      final r = solve(['2^x+3^y+z', '2^x-3^y+z', '2^x+3^y-z'], ['14', '4', '8']);
      // 2^x = 6, 3^y = 5, z = 3
      expect(has(sols(r), [math.log(6) / math.ln2, math.log(5) / math.log(3), 3]), isTrue, reason: r.exactResultLatex);
      expectCleanNotes(r);
    });

    test('2x2 radical sqrt(x) + sqrt(y) = 5, x - y = 5 -> (9, 4)', () {
      final r = solve(['√(x)+√(y)', 'x-y'], ['5', '5']);
      expect(has(sols(r), [9, 4]), isTrue, reason: r.exactResultLatex);
      expect(sols(r).length, 1);
      expectCleanNotes(r);
    });

    test('2x2 trigonometrico en DEG', () {
      final r = solve(['sin(x)+cos(y)', 'sin(x)-cos(y)'], ['1', '0'], unit: AngleUnit.deg);
      for (final p in [
        [30.0, 60.0],
        [30.0, 300.0],
        [150.0, 60.0],
        [150.0, 300.0],
      ]) {
        expect(has(sols(r), p), isTrue, reason: '$p en ${r.exactResultLatex}');
      }
      expectCleanNotes(r);
    });

    test('2x2 trigonometrico en RAD', () {
      final r = solve(['sin(x)+cos(y)', 'sin(x)-cos(y)'], ['1', '0']);
      expect(has(sols(r), [math.pi / 6, math.pi / 3]), isTrue, reason: r.exactResultLatex);
      expect(has(sols(r), [5 * math.pi / 6, 5 * math.pi / 3]), isTrue);
      expectCleanNotes(r);
    });
  });

  group('Cascada y recetas', () {
    test('3x3: z = 2x - 1, x + y = 7, x² + y² = 25 -> (3,4,5) y (4,3,7)', () {
      final r = solve(['z', 'x+y', 'x^2+y^2'], ['2x-1', '7', '25']);
      expect(has(sols(r), [3, 4, 5]), isTrue, reason: r.exactResultLatex);
      expect(has(sols(r), [4, 3, 7]), isTrue);
      expect(sols(r).length, 2);
      expectCleanNotes(r);
    });

    test('4x4 en cascada con una ecuacion de una sola incognita', () {
      final r = solve(['w', 'z^2', 'x+y', 'x-y'], ['2x-1', '9', '5', '1']);
      // x = 3, y = 2, w = 5, z = ±3
      expect(has(sols(r), [3, 2, 3, 5]), isTrue, reason: r.exactResultLatex);
      expect(has(sols(r), [3, 2, -3, 5]), isTrue);
      expectCleanNotes(r);
    });

    test('simetrico x² + y² = 25, x·y = 12 -> cuatro soluciones', () {
      final r = solve(['x^2+y^2', 'x*y'], ['25', '12']);
      for (final p in [
        [3.0, 4.0],
        [4.0, 3.0],
        [-3.0, -4.0],
        [-4.0, -3.0],
      ]) {
        expect(has(sols(r), p), isTrue, reason: r.exactResultLatex);
      }
      expectCleanNotes(r);
    });

    test('dos circunferencias (eje radical)', () {
      final r = solve(['x^2+y^2', 'x^2+y^2-2x'], ['25', '16']);
      expect(sols(r).length, 2, reason: r.exactResultLatex);
      expectCleanNotes(r);
    });
  });

  group('Newton-Raphson N-D', () {
    test('2x2: e^x + y = 3, x + y² = 2', () {
      final sys = ndOf(['ℯ^x+y', 'x+y^2'], ['3', '2']);
      final found = NonlinearNumericNdSolver.findAll(sys);
      expect(found, isNotEmpty);
      for (final s in found) {
        expect(sys.residual(0, s)!.abs(), lessThan(1e-5));
        expect(sys.residual(1, s)!.abs(), lessThan(1e-5));
      }
      final r = solve(['ℯ^x+y', 'x+y^2'], ['3', '2']);
      expect(sols(r), isNotEmpty);
      expectCleanNotes(r);
    });

    test('3x3 acoplado', () {
      final sys = ndOf(['ℯ^x+y+z', 'x+y^2+z', 'x+y+z^3'], ['4', '3', '3']);
      final found = NonlinearNumericNdSolver.findAll(sys);
      expect(found, isNotEmpty);
      for (final s in found) {
        for (var i = 0; i < 3; i++) {
          expect(sys.residual(i, s)!.abs(), lessThan(1e-5));
        }
      }
      expectCleanNotes(solve(['ℯ^x+y+z', 'x+y^2+z', 'x+y+z^3'], ['4', '3', '3']));
    });

    test('sin solucion real: mensaje didactico, sin excepcion', () {
      final r = solve(['x^2+y^2', 'x*y'], ['-1', '1']);
      expect(sols(r), isEmpty);
      expect(r.exactResultLatex, contains('Sin solucion'));
      expectCleanNotes(r);
    });

    test('rapido: menos de 1 s en un sistema 4x4', () {
      final sw = Stopwatch()..start();
      NonlinearNumericNdSolver.findAll(ndOf(['ℯ^x+y+z+w', 'x+y^2+z', 'x+y+z^3+w', 'x+w^2'], ['6', '3', '3', '2']));
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('UI M3 libre 4x4', () {
    bothSizes('4x4 sin overflow, con scroll vertical y D-Pad hasta la ultima fila', (t) async {
      await seq(t, 'mode:3 pick:hdr_sys_size:sys_dim_4');
      expect(find.byKey(const Key('sys_free_scroll')), findsOneWidget);
      for (var i = 0; i < 8; i++) {
        await pad(t, 'down');
      }
      expect(find.byKey(const Key('sys_free_cell_7')), findsOneWidget);
      await seq(t, 'x + y + 1 = 2');
    });
  });
}
