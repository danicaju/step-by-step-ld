import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/calculus/limits_asymptotes_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/functions/function_family_study_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/presentation/painters/graph_viewport_calculator.dart';
import 'package:casio_tutor_calc/presentation/painters/graph_viewport_controller.dart';
import 'package:casio_tutor_calc/presentation/painters/universal_function_painter.dart';
import 'support/e2e_helpers.dart';
import 'support/header_select.dart';

String _tex(StepByStepResolution r) =>
    '${r.originalInputLatex}${r.steps.map((s) => s.latexExpression).join()}${r.exactResultLatex}';

String _titles(StepByStepResolution r) => r.steps.map((s) => s.shortTitle).join('|');

/// LaTeX blindado: sin tildes dentro de `\text{}` / `\mathrm{}` y llaves balanceadas.
void _clean(StepByStepResolution r) {
  final t = _tex(r);
  expect(RegExp(r'\\(text|mathrm)\{[^}]*[áéíóúñ¿¡][^}]*\}').hasMatch(t), isFalse, reason: t);
  expect(RegExp(r'\\r(?![a-zA-Z])').hasMatch(t), isFalse, reason: t);
  expect(balanced(t), isTrue, reason: t);
  expect(r.steps, isNotEmpty);
}

FamilyStudy _study(String f, {int kind = 1, bool deg = false}) =>
    FunctionFamilyStudySolver.study(f, expectedKind: kind, degrees: deg);

GraphWindow _win(FamilyStudy s) => GraphViewportCalculator.window(s.result.model, s.result.asymptotes,
    info: s.info, deg: s.degrees);

void main() {
  test('ningun .dart de lib/ supera las 500 lineas (y los nuevos <= 450)', () {
    final big = <String>[];
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is File && e.path.endsWith('.dart')) {
        final n = e.readAsLinesSync().length;
        if (n >= 500) big.add('${e.path}: $n');
        if (e.path.replaceAll('\\', '/').contains('math_engine/functions/') ||
            e.path.contains('graph_viewport') ||
            e.path.contains('graph_key_points') ||
            e.path.contains('graph_axis_ticks') ||
            e.path.contains('universal_function_painter')) {
          expect(n <= 450, isTrue, reason: '${e.path}: $n');
        }
      }
    }
    expect(big, isEmpty);
  });

  group('Clasificacion y auto-deteccion', () {
    const cases = {
      '5': FunctionFamily.constant,
      '2x+3': FunctionFamily.linear,
      'x^2-4x+3': FunctionFamily.quadratic,
      'x^3-3x': FunctionFamily.cubic,
      '(2x+1)/(x-3)': FunctionFamily.rational,
      '3/x': FunctionFamily.rational,
      'sqrt(x-1)': FunctionFamily.radicalEven,
      'cbrt(x+2)': FunctionFamily.radicalOdd,
      '2^x': FunctionFamily.exponential,
      'log_2(x)': FunctionFamily.logarithmic,
      'ln(x+1)': FunctionFamily.logarithmic,
      'sin(x)': FunctionFamily.sine,
      '2sin(3x)+1': FunctionFamily.sine,
      'cos(x)': FunctionFamily.cosine,
      'tan(x)': FunctionFamily.tangent,
    };
    cases.forEach((f, fam) {
      test('$f -> $fam', () {
        final s = _study(f);
        expect(s.family, fam);
        _clean(s.result.resolution);
        for (final st in s.result.resolution.steps) {
          expect(st.pedagogicalNote, isNotEmpty);
        }
      });
    });

    test('tipo del desplegable incorrecto avisa con mensaje didactico', () {
      expect(() => _study('x^2', kind: 2), throwsA(isA<FormatException>()));
      expect(() => _study('sin(x)', kind: 7), throwsA(isA<FormatException>()));
      expect(_study('x^2', kind: 3).family, FunctionFamily.quadratic);
    });
  });

  group('Polinomicas', () {
    test('constante: m=0, corte OY, sin cortes OX', () {
      final r = _study('5', kind: 2).result.resolution;
      expect(_tex(r), contains('m = 0'));
      expect(_tex(r), contains(r'\left(0,\,5\right)'));
      expect(_tex(r), contains('sin cortes'));
    });
    test('afin: monotonia, OY y OX', () {
      final r = _study('2x+3', kind: 2).result.resolution;
      expect(_titles(r), contains('Monotonía'));
      expect(_tex(r), contains('creciente'));
      expect(_tex(r), contains(r'\left(-\frac{3}{2},\,0\right)'));
      expect(_tex(_study('-x+1', kind: 2).result.resolution), contains('decreciente'));
    });
    test('cuadratica: vertice, eje, discriminante y cortes', () {
      final r = _study('x^2-4x+3', kind: 3).result.resolution;
      final t = _tex(r);
      expect(t, contains(r'\text{Vertice}\left(2,\,-1\right)'));
      expect(_titles(r), contains('Eje de simetría'));
      expect(t, contains(r'\Delta'));
      expect(t, contains('x_{1} = 1'));
      expect(_tex(_study('-x^2+4', kind: 3).result.resolution), contains(r'\left(-\infty'));
    });
    test('cubica: ramas, Ruffini y extremos', () {
      final r = _study('x^3-3x', kind: 4).result.resolution;
      final t = _tex(r);
      expect(t, contains(r'\lim_{x \to -\infty}'));
      expect(_titles(r), contains('Extremos relativos'));
      expect(t, contains(r'\text{max}'));
      expect(t, contains(r'\text{min}'));
      expect(_titles(_study('x^3-6x^2+11x-6', kind: 4).result.resolution), contains('Ruffini'));
    });
  });

  group('Racionales', () {
    test('(px+q)/(rx+s): dominio, AV con laterales, AH y cortes', () {
      final s = _study('(2x+1)/(x-3)', kind: 5);
      final t = _tex(s.result.resolution);
      expect(t, contains(r'x_{AV} = 3'));
      expect(t, contains(r'x \to 3^{-}'));
      expect(t, contains(r'x \to 3^{+}'));
      expect(t, contains(r'y_{AH} = 2'));
      expect(s.result.asymptotes.vertical.single.x, 3);
      expect(s.result.asymptotes.horizontal.single.n, 2);
    });
    test('k/x: AV x=0, AH y=0, sin cortes', () {
      final s = _study('3/x', kind: 5);
      final t = _tex(s.result.resolution);
      expect(t, contains(r'y_{AH} = 0'));
      expect(s.result.asymptotes.vertical.single.x, 0);
      expect(_titles(s.result.resolution), contains('Cortes con el eje OX'));
    });
    test('asintota oblicua si grado(P) = grado(Q) + 1', () {
      final s = _study('(x^2+1)/x', kind: 5);
      expect(_tex(s.result.resolution), contains(r'y_{AO} = x'));
    });
    test('encuadre centrado en (AV, AH) con las dos ramas', () {
      final s = _study('(2x+1)/(x-3)');
      final w = _win(s);
      // El encuadre inteligente abarca el corte con OX, el corte con OY y el cruce de asintotas (3, 2).
      expect(w.xMin < -0.5 && w.xMax > 3, isTrue);
      expect(w.yMin < -0.33 && w.yMax > 2, isTrue);
      final br = UniversalFunctionPainter.branchesFor(s.result.model, s.result.asymptotes, w);
      expect(br.length, 2);
      final k = _study('3/x');
      final wk = _win(k);
      expect((wk.xMin + wk.xMax) / 2, closeTo(0, 1e-9));
      expect(UniversalFunctionPainter.branchesFor(k.result.model, k.result.asymptotes, wk).length, 2);
    });
  });

  group('Radicales', () {
    test('sqrt(x): inecuacion de existencia, arranque y tabla exacta', () {
      final s = _study('sqrt(x)', kind: 6);
      final t = _tex(s.result.resolution);
      expect(t, contains(r'x \ge 0'));
      expect(t, contains(r'\left[0,\,+\infty\right)'));
      expect(t, contains(r'\left(0,\,0\right)'));
      expect(_titles(s.result.resolution), contains('Tabla de valores'));
      expect(t, contains(r'4\to 2'));
      expect(s.result.model.at(-1), isNull); // no dibuja donde el radicando es negativo
    });
    test('cbrt(x): dominio R y simetria; encuadre empieza en x0 - 1 para la par', () {
      final s = _study('cbrt(x)', kind: 6);
      final t = _tex(s.result.resolution);
      expect(t, contains(r'\mathbb{R}'));
      expect(_titles(s.result.resolution), contains('Punto de simetría'));
      expect(s.result.model.at(-8), closeTo(-2, 1e-9));
      final e = _study('sqrt(x-2)');
      final we = _win(e);
      expect(we.xMin <= 2 && we.xMax >= 2, isTrue, reason: 'el inicio del dominio (2, 0) esta en la ventana');
    });
  });

  group('Exponenciales y logaritmicas', () {
    test('2^x: Dom, Im, (0,1), creciente y AH y=0', () {
      final s = _study('2^x', kind: 7);
      final t = _tex(s.result.resolution);
      expect(t, contains(r'\left(0,\,+\infty\right)'));
      expect(t, contains(r'\left(0,\,1\right)'));
      expect(t, contains('creciente'));
      expect(s.result.asymptotes.horizontal.single.n, 0);
      expect(_tex(_study('(1/2)^x', kind: 7).result.resolution), contains('decreciente'));
    });
    test('log_2(x): argumento > 0, (1,0), AV x=0', () {
      final s = _study('log_2(x)', kind: 7);
      final t = _tex(s.result.resolution);
      expect(t, contains(r'x > 0'));
      expect(t, contains(r'\left(1,\,0\right)'));
      expect(t, contains(r'x_{AV} = 0'));
      expect(s.result.asymptotes.vertical.single.x, 0);
      expect(s.result.model.at(0), isNull);
      expect(s.result.model.at(-3), isNull);
      final wl = _win(s);
      expect(wl.xMin <= 0 && wl.xMax >= 1, isTrue, reason: 'la ventana incluye la AV x=0 y el corte (1, 0)');
    });
  });

  group('Trigonometricas', () {
    test('sin x: Im [-1,1], periodo 2pi, max/min', () {
      final s = _study('sin(x)', kind: 8);
      final t = _tex(s.result.resolution);
      expect(t, contains(r'\left[-1,\,1\right]'));
      expect(t, contains(r'T = \frac{2\pi}{|B|} = 2\pi'));
      expect(t, contains(r'\text{Max}\left(\frac{\pi}{2},\,1\right)'));
    });
    test('A sin(Bx+C)+D: imagen y periodo; DEG usa 360', () {
      expect(_tex(_study('2sin(3x)+1', kind: 8).result.resolution), contains(r'\left[-1,\,3\right]'));
      final d = _study('sin(x)', kind: 8, deg: true);
      expect(_tex(d.result.resolution), contains(r'360^\circ'));
      final w = _win(d);
      expect(w.xMin, -360);
      expect(w.xMax, 360);
    });
    test('cos x: encuadre [-2pi, 2pi] y marcas en multiplos de pi/2', () {
      final s = _study('cos(x)', kind: 8);
      final w = _win(s);
      expect(w.xMin, closeTo(-2 * math.pi, 1e-9));
      expect(w.xMax, closeTo(2 * math.pi, 1e-9));
      final labels = GraphViewportCalculator.angleTicks(w, false)!.map((e) => e.$2).toList();
      expect(labels, containsAll(['-π', '-π/2', 'π/2', 'π', '2π']));
      final dl = GraphViewportCalculator.angleTicks(_win(_study('cos(x)', deg: true)), true)!.map((e) => e.$2);
      expect(dl, containsAll(['90°', '180°', '270°', '360°']));
    });
    test('tan x: AV en pi/2 + k pi, Im R, periodo pi; la curva se corta en las AV', () {
      final s = _study('tan(x)', kind: 8);
      final t = _tex(s.result.resolution);
      expect(t, contains(r'\frac{\pi}{2} + k \cdot \pi'));
      expect(t, contains(r'\text{Im}(f) = \mathbb{R}'));
      expect(t, contains(r'T = \frac{\pi}{|B|} = \pi'));
      final xs = s.result.asymptotes.verticalXs;
      expect(xs.any((x) => (x - math.pi / 2).abs() < 1e-9), isTrue);
      expect(xs.any((x) => (x + math.pi / 2).abs() < 1e-9), isTrue);
      final w = _win(s);
      final br = UniversalFunctionPainter.branchesFor(s.result.model, s.result.asymptotes, w);
      for (final b in br) {
        for (final c in xs) {
          expect(b.first.$1 < c && b.last.$1 > c, isFalse, reason: 'rama cruza la AV en $c');
        }
      }
      final d = _study('tan(x)', kind: 8, deg: true);
      expect(_tex(d.result.resolution), contains(r'90^\circ + k \cdot 180^\circ'));
      expect(d.result.asymptotes.verticalXs, contains(90));
    });
  });

  group('Renderizado sin overflow (5 familias)', () {
    for (final f in ['5', '2x+3', 'x^2-4x+3', 'x^3-3x', '(2x+1)/(x-3)', '3/x', 'sqrt(x)', 'cbrt(x)', '2^x', 'log_2(x)', 'sin(x)', 'cos(x)', 'tan(x)']) {
      testWidgets('visor $f dentro de ClipRRect', (t) async {
        final s = _study(f);
        await t.pumpWidget(MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 180,
              child: UniversalGraphView(model: s.result.model, asymptotes: s.result.asymptotes, info: s.info, controller: GraphViewportController()..panByFraction(0.3, -0.2)),
            ),
          ),
        ));
        expect(find.byKey(const Key('universal_graph_clip')), findsOneWidget);
        expect(find.byKey(const Key('universal_graph_paint')), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  });

  group('E2E M5: selector de tipos y D-Pad', () {
    Future<void> goM5(WidgetTester t) async {
      await tapF(t, find.text('MODE'));
      await tapF(t, find.byKey(const Key('menu_page_next')));
      await tapF(t, find.byKey(const Key('menu_mode_5')));
    }

    testWidgets('ocho tipos con atajos 1:-8:', (t) async {
      await boot(t);
      await goM5(t);
      await tapF(t, find.byKey(const Key('hdr_graph_kind')));
      for (var k = 0; k < 8; k++) {
        expect(find.byKey(Key('graph_kind_$k')), findsOneWidget);
      }
      for (var k = 1; k <= 8; k++) {
        expect(find.textContaining('$k:'), findsWidgets);
      }
    });

    testWidgets('lineal: = ejecuta, grafica visible y D-Pad la desplaza', (t) async {
      await boot(t);
      await goM5(t);
      await pickHeader(t, 'hdr_graph_kind', 'graph_kind_1');
      await keys(t, ['2']);
      await alphaKey(t, ')');
      await keys(t, ['+', '3', '=']);
      expect(find.byKey(const Key('universal_graph_clip')), findsOneWidget);
      final before = t.widget<UniversalGraphView>(find.byType(UniversalGraphView)).controller!.window.xMin;
      await pad(t, 'right');
      final after = t.widget<UniversalGraphView>(find.byType(UniversalGraphView)).controller!.window.xMin;
      expect(after > before, isTrue);
      expect(t.takeException(), isNull);
    });

    testWidgets('tipo equivocado muestra aviso LCD y no cuelga', (t) async {
      await boot(t);
      await goM5(t);
      await pickHeader(t, 'hdr_graph_kind', 'graph_kind_2');
      await keys(t, ['2']);
      await alphaKey(t, ')');
      await keys(t, ['+', '3', '=']);
      expect(find.byKey(const Key('lcd_error_screen')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  test('estudio libre sigue funcionando para una expresion fuera de las familias', () {
    final s = _study('x^2+x^4');
    expect(s.family, FunctionFamily.unknown);
    expect(LimitsAsymptotesSolver.study('x^2+x^4').domain.latex, r'\mathbb{R}');
  });
}
