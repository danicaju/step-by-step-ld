import 'package:flutter/gestures.dart';
import 'package:casio_tutor_calc/core/formatting/smart_latex_wrapper.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/calculus_solver.dart';
import 'package:casio_tutor_calc/presentation/widgets/common/responsive_math_formula.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_helpers.dart';
import 'support/exercise_dsl.dart';

final String _bigIntegral = CalculusSolver.solve(
  operation: CalculusOperation.indefiniteIntegral,
  expressionRaw: '1/(x^5+1)',
).exactResultLatex;

bool _balanced(String s) => isLatexBalanced(s);

void main() {
  group('splitLongLatex', () {
    test('formula corta: una sola linea intacta', () {
      const f = r'x^{2} + 3x - 5 = 0';
      expect(splitLongLatex(f, maxVisualCharsPerLine: 40), [f]);
      expect(splitLongLatex(r'\frac{a + b}{c}', maxVisualCharsPerLine: 3), [r'\frac{a + b}{c}']);
    });

    test('primitiva de 1/(x^5+1): varias lineas balanceadas con el signo al inicio', () {
      expect(_bigIntegral, endsWith('+ C'));
      final lines = splitLongLatex(_bigIntegral, maxVisualCharsPerLine: 38);
      expect(lines.length, greaterThan(1), reason: _bigIntegral);
      for (final l in lines) {
        expect(_balanced(l), isTrue, reason: 'desbalanceada: $l');
      }
      // Las lineas 2.. empiezan por operador de nivel superior.
      for (final l in lines.skip(1)) {
        expect(RegExp(r'^[+\-=]|^\\approx').hasMatch(l), isTrue, reason: 'linea sin operador: $l');
      }
      // Recomponer no pierde ni inventa contenido.
      String strip(String s) => s.replaceAll(RegExp(r'\s+'), '');
      expect(strip(lines.join(' ')), strip(_bigIntegral));
      // Ningun corte parte funciones: cada linea con \ln, \arctan o \frac cierra su argumento.
      for (final l in lines) {
        expect(RegExp(r'\\(ln|arctan)\s*$').hasMatch(l), isFalse, reason: l);
        expect(l.split(r'\left').length, l.split(r'\right').length);
      }
    });

    test('nunca parte dentro de parentesis, fracciones, raices, valor absoluto ni entornos', () {
      const inner = r'\ln\left(x^{2} - \frac{1 + \sqrt{5}}{2}x + 1\right) + \ln|x + 1| - \arctan(x - 3)';
      final lines = splitLongLatex('a = $inner + b', maxVisualCharsPerLine: 20);
      for (final l in lines) {
        expect(_balanced(l), isTrue, reason: l);
      }
      expect(lines.join(' ').contains(r'\left(x^{2} - \frac{1 + \sqrt{5}}{2}x + 1\right)'), isTrue);
      expect(lines.join(' ').contains(r'\ln|x + 1|'), isTrue);
      const matrix = r'\begin{pmatrix} 1 + 2 & 3 - 4 \\ 5 + 6 & 7 - 8 \end{pmatrix} + \begin{pmatrix} 1 & 2 \\ 3 & 4 \end{pmatrix}';
      final m = splitLongLatex(matrix, maxVisualCharsPerLine: 10);
      for (final l in m) {
        expect(_balanced(l), isTrue, reason: l);
        expect(l.split(r'\begin').length, l.split(r'\end').length);
      }
      const sys = r'\left\{\begin{array}{l} x = 1 + 2 \\ y = 3 - 4 \end{array}\right.';
      expect(splitLongLatex(sys, maxVisualCharsPerLine: 5), [sys]);
    });

    test('signos unarios no son puntos de corte', () {
      const f = r'x = -3 + 4 \cdot -2 + y^{-1} - 7';
      for (final l in splitLongLatex(f, maxVisualCharsPerLine: 6)) {
        expect(_balanced(l), isTrue);
        expect(l.trim().endsWith('='), isFalse);
        expect(l.trim().endsWith(r'\cdot'), isFalse);
      }
    });

    test('splitArrayRows separa las filas de un array simple y no toca los sistemas', () {
      expect(splitArrayRows(r'\begin{array}{l} a = 1 \\ b = 2 \end{array}'), ['a = 1', 'b = 2']);
      expect(splitArrayRows(r'\left\{\begin{array}{l} x = 1 \\ y = 2 \end{array}\right.'), isNull);
      expect(splitArrayRows(r'\begin{array}{l} a = 1 \end{array}'), isNull);
    });

    test('stripLeadingStatement quita el enunciado repetido', () {
      const o = r'\int \frac{1}{x^{5} + 1}\,dx';
      expect(stripLeadingStatement('$o = F + C', o), '= F + C');
      expect(stripLeadingStatement(r'F(x) = 3', o), r'F(x) = 3');
      expect(stripLeadingStatement(r'\begin{array}{l} A(1) \\ b = 2 \\ c = 3 \end{array}', 'A(1)'),
          r'\begin{array}{l} b = 2 \\ c = 3 \end{array}');
      expect(stripLeadingStatement(r'\begin{array}{l} A(1) \\ b = 2 \end{array}', 'A(1)'), 'b = 2');
    });
  });

  group('ResponsiveMathFormula', () {
    Future<void> pumpFormula(WidgetTester t, double width, {double height = 400}) async {
      t.view.physicalSize = Size(width + 40, height + 40);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: ResponsiveMathFormula(
                latex: _bigIntegral,
                textStyle: const TextStyle(fontSize: 22, color: Colors.black),
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();
    }

    for (final w in [360.0, 900.0]) {
      testWidgets('integral de grado 5 a ${w.toInt()} px: sin overflow ni errores KaTeX y legible', (t) async {
        await pumpFormula(t, w);
        expect(t.takeException(), isNull);
        final maths = t.widgetList<Math>(find.byType(Math)).toList();
        expect(maths, isNotEmpty);
        for (final m in maths) {
          expect(m.parseError, isNull);
        }
        if (w < 500) {
          // En movil no cabe en una linea: salto en varias lineas (no una sola microscopica).
          expect(maths.length, greaterThan(1));
        }
        // Escala efectiva de cada Math >= suelo (0,78) salvo las que van en scroll (fuente ya a escala).
        for (var i = 0; i < maths.length; i++) {
          final mf = find.byType(Math).at(i);
          final fitted = find.ancestor(of: mf, matching: find.byType(FittedBox));
          if (fitted.evaluate().isEmpty) continue;
          final scale = t.getSize(fitted.first).width / t.getSize(mf).width;
          expect(scale, greaterThanOrEqualTo(0.77), reason: 'linea $i muy encogida');
        }
        // Todas las lineas caben en el ancho disponible o estan en scroll horizontal.
        for (var i = 0; i < maths.length; i++) {
          final mf = find.byType(Math).at(i);
          final inScroll = find.ancestor(of: mf, matching: find.byKey(const Key('math_scroll_line'))).evaluate().isNotEmpty;
          final fitted = find.ancestor(of: mf, matching: find.byType(FittedBox));
          final visible = fitted.evaluate().isNotEmpty ? t.getSize(fitted.first).width : t.getSize(mf).width;
          if (!inScroll) expect(visible, lessThanOrEqualTo(w + 0.5));
        }
      });
    }

    testWidgets('fila indivisible larga: scroll horizontal con indicador', (t) async {
      t.view.physicalSize = const Size(340, 200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      const wide = r'\frac{1234567890 + 1234567890 + 1234567890 + 1234567890}{9876543210 \cdot 9876543210 \cdot 9876543210}';
      await t.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 120,
            child: ResponsiveMathFormula(
              latex: wide,
              textStyle: TextStyle(fontSize: 22, color: Colors.black),
              backgroundColor: Colors.white,
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('math_scroll_line')), findsOneWidget);
      expect(find.byKey(const Key('math_scroll_hint_right')), findsOneWidget);
      expect(find.byKey(const Key('math_scroll_hint_left')), findsNothing);
      await t.drag(find.byKey(const Key('math_scroll_line')), const Offset(-400, 0), kind: PointerDeviceKind.mouse);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('math_scroll_hint_left')), findsOneWidget);
    });

    testWidgets('formula corta: sin escalar ni scroll', (t) async {
      await t.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: ResponsiveMathFormula(latex: r'x = 5', textStyle: TextStyle(fontSize: 22)),
          ),
        ),
      ));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('math_scroll_line')), findsNothing);
      final fitted = find.byType(FittedBox);
      if (fitted.evaluate().isNotEmpty) {
        expect(t.getSize(fitted.first).width, closeTo(t.getSize(find.byType(Math)).width, 0.5));
      }
      expect(t.takeException(), isNull);
    });
  });

  group('LCD de pasos y panel derecho (M12)', () {
    bothSizes('integral 1/(x^5+1): ultimo paso legible, sin repetir el enunciado y sin errores KaTeX', (t) async {
      await seq(t, 'mode:12 pick:hdr_calculus_op:calculus_op_indefiniteIntegral frac 1 v x S:pow 5 > + 1 > =');
      final r = res(t);
      for (var i = 0; i < r.steps.length - 1; i++) {
        await key(t, '=');
        expect(t.takeException(), isNull);
      }
      expect(find.byKey(const Key('lcd_step_formula')), findsOneWidget);
      for (final m in t.widgetList<Math>(find.byType(Math))) {
        expect(m.parseError, isNull);
      }
      // El enunciado ya esta arriba: el paso final empieza por "= ...".
      final shown = t.widget<ResponsiveMathFormula>(find.byKey(const Key('lcd_step_formula')));
      expect(shown.latex.trimLeft().startsWith('='), isTrue, reason: shown.latex);
    });
  });
}
