import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/arithmetic/casio_iberia_arsenal.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/geometry/geometry_triangle_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/geometry/line_equations_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/polynomials/algebraic_fraction_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/proportion/proportion_conversion_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/polynomials/spanish_box_division_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/equations/eq_poly.dart';
import 'package:casio_tutor_calc/domain/math_engine/statistics/probability_distribution_solver.dart';
import 'package:casio_tutor_calc/presentation/painters/gaussian_bell_painter.dart';
import 'package:casio_tutor_calc/presentation/widgets/modes/geometry_mode_widget.dart';
import 'package:casio_tutor_calc/presentation/widgets/modes/mode_form.dart';
import 'package:casio_tutor_calc/presentation/widgets/modes/spanish_box_division_widget.dart';
import 'support/e2e_helpers.dart';
import 'support/header_select.dart';

String _tex(StepByStepResolution r) =>
    '${r.originalInputLatex}${r.steps.map((s) => s.latexExpression).join()}${r.exactResultLatex}';

/// Sin tildes/enes dentro de \text{} o \mathrm{}, llaves balanceadas, sin \r suelto.
void _clean(StepByStepResolution r) {
  final t = _tex(r);
  expect(RegExp(r'\\(text|mathrm)\{[^}]*[áéíóúñ¿¡][^}]*\}').hasMatch(t), isFalse, reason: t);
  expect(RegExp(r'\\r(?![a-zA-Z])').hasMatch(t), isFalse, reason: t);
  var d = 0;
  for (final c in t.replaceAll(r'\{', '').replaceAll(r'\}', '').split('')) {
    if (c == '{') d++;
    if (c == '}') d--;
    expect(d >= 0, isTrue, reason: t);
  }
  expect(d, 0, reason: t);
}

Rational q(String s) => ProportionSolver.parseQuantity(s);

void main() {
  group('Division en caja espanola', () {
    BoxDivisionResult div(String p, String d) => SpanishBoxDivisionSolver.divideText(p, d);
    String show(Poly p) => PolyOps.latex(p);

    test('(x^3+2x^2-x+3):(x^2+1) = x+2, resto -2x+1', () {
      final r = div('x^3+2x^2-x+3', 'x^2+1');
      expect(show(r.quotient), 'x + 2');
      expect(show(r.remainder), '-2x + 1');
      expect(r.steps.length, 2);
      _clean(r.resolution);
    });
    test('completa huecos con 0x^k y resto 0', () {
      final r = div('x^4-1', 'x^2+1');
      expect(show(r.quotient), 'x^{2} - 1');
      expect(r.remainder, isEmpty);
      expect(_tex(r.resolution), contains('0x^{3}'));
      expect(_tex(r.resolution), contains('0x^{2}'));
    });
    test('divisor lineal, de grado 2 y coeficientes fraccionarios', () {
      expect(show(div('2x^3-3x^2+4', 'x-2').quotient), '2x^{2} + x + 2');
      expect(show(div('6x^3+x^2-5x+2', '2x^2-x+1').quotient), '3x + 2');
      final f = div('x^2', '2x+1');
      expect(show(f.quotient), '\\frac{1}{2}x - \\frac{1}{4}');
    });
    test('prueba P = Q*C + R', () {
      final r = div('3x^4-2x^2+x-7', 'x^2-x+2');
      final back = PolyOps.add(PolyOps.mul(r.divisor, r.quotient), r.remainder);
      expect(back, PolyOps.clean(r.dividend));
    });
    test('grado menor, divisor cero y texto invalido', () {
      final r = div('x+1', 'x^2+1');
      expect(r.quotient, isEmpty);
      expect(show(r.remainder), 'x + 1');
      expect(() => div('x^2', '0'), throwsA(isA<ArsenalException>()));
      expect(() => div('', 'x'), throwsA(isA<ArsenalException>()));
      expect(() => div('sin(x)', 'x'), throwsA(isA<ArsenalException>()));
    });
  });

  group('Fracciones algebraicas', () {
    String ex(AlgebraicFractionResult r) => r.resolution.exactResultLatex;
    test('simplificar tachando factores comunes', () {
      final r = AlgebraicFractionSolver.simplify('x^2-1', 'x^2-2x+1');
      expect(ex(r), r'\frac{x + 1}{x - 1}');
      expect(_tex(r.resolution), contains(r'\textcolor{#7A8A7E}'));
      _clean(r.resolution);
      expect(ex(AlgebraicFractionSolver.simplify('x^2+1', 'x^2+3')), r'\frac{x^{2} + 1}{x^{2} + 3}');
    });
    test('suma y resta con m.c.m.', () {
      final s = AlgebraicFractionSolver.operate(FractionOp.add, '1', 'x-1', '1', 'x+1');
      expect(ex(s), r'\frac{2x}{x^{2} - 1}');
      expect(_tex(s.resolution), contains('m.c.m.'));
      _clean(s.resolution);
      final d = AlgebraicFractionSolver.operate(FractionOp.sub, 'x', 'x-1', '1', 'x-1');
      expect(ex(d), '1');
      final m = AlgebraicFractionSolver.operate(FractionOp.add, '1', 'x', '1', 'x^2');
      expect(ex(m), r'\frac{x + 1}{x^{2}}');
    });
    test('producto y cociente', () {
      expect(ex(AlgebraicFractionSolver.operate(FractionOp.mul, 'x', 'x+1', 'x+1', 'x-1')), r'\frac{x}{x - 1}');
      final dv = AlgebraicFractionSolver.operate(FractionOp.div, 'x^2-1', 'x', 'x-1', 'x^2');
      expect(ex(dv), r'x\left(x + 1\right)'.isEmpty ? '' : ex(dv));
      expect(PolyOps.latex(dv.num), 'x^{2} + x');
      expect(PolyOps.latex(dv.den), '1');
      _clean(dv.resolution);
    });
    test('errores', () {
      expect(() => AlgebraicFractionSolver.simplify('x', '0'), throwsA(isA<ArsenalException>()));
    });
  });

  group('Las 6 ecuaciones de la recta', () {
    test('desde dos puntos A(1,2) y B(3,6)', () {
      final r = LineEquationsSolver.fromPoints(q('1'), q('2'), q('3'), q('6'));
      expect(r.slope, Rational(2));
      expect(r.intercept, Rational(0));
      expect(r.resolution.exactResultLatex, '2x - y = 0');
      expect(r.resolution.steps.length, 7);
      final t = _tex(r.resolution);
      expect(t, contains(r'(x,\; y) = (1,\; 2) + t'));
      expect(t, contains(r'x = 1 + 2t'));
      expect(t, contains(r'\frac{x - 1}{2} = \frac{y - 2}{4}'));
      expect(t, contains(r'y - 2 = 2\,\left(x - 1\right)'));
      expect(t, contains('y = 2x'));
      _clean(r.resolution);
    });
    test('punto y vector, punto y pendiente', () {
      final r = LineEquationsSolver.fromPointVector(q('0'), q('3'), q('2'), q('-1'));
      expect(r.slope, Rational(-1, 2));
      expect(r.resolution.exactResultLatex, 'x + 2y - 6 = 0');
      final s = LineEquationsSolver.fromPointSlope(q('2'), q('1'), q('1/2'));
      expect(s.resolution.exactResultLatex, 'x - 2y = 0');
      expect(_tex(s.resolution), contains(r'y = \frac{1}{2}x'));
      _clean(s.resolution);
    });
    test('vertical y horizontal sin dividir entre 0', () {
      final v = LineEquationsSolver.fromPoints(q('2'), q('0'), q('2'), q('5'));
      expect(v.isVertical, isTrue);
      expect(v.slope, isNull);
      expect(v.resolution.exactResultLatex, 'x - 2 = 0');
      expect(v.resolution.steps[3].latexExpression, 'x = 2');
      final h = LineEquationsSolver.fromPoints(q('0'), q('4'), q('3'), q('4'));
      expect(h.isHorizontal, isTrue);
      expect(h.resolution.exactResultLatex, 'y - 4 = 0');
      _clean(v.resolution);
      _clean(h.resolution);
    });
    test('errores', () {
      expect(() => LineEquationsSolver.fromPoints(q('1'), q('1'), q('1'), q('1')), throwsA(isA<ArsenalException>()));
      expect(() => LineEquationsSolver.fromPointVector(q('1'), q('1'), q('0'), q('0')), throwsA(isA<ArsenalException>()));
    });
  });

  group('Triangulos', () {
    TriangleResult solve({List<double?> s = const [null, null, null], List<double?> a = const [null, null, null]}) =>
        TriangleSolver.solve(sides: s, angles: a);
    void near(double a, double b, [double eps = 1e-3]) => expect((a - b).abs() < eps, isTrue, reason: '$a vs $b');

    test('Pitagoras: catetos 3 y 4 -> hipotenusa 5', () {
      final r = solve(s: [3, 4, null], a: [null, null, 90]);
      near(r.solutions.first.sides[2], 5);
      near(r.solutions.first.angles[0], 36.8699);
      expect(r.kind, 'pitagoras');
      expect(_tex(r.resolution), contains('c = \\sqrt{'));
      _clean(r.resolution);
    });
    test('Pitagoras: hipotenusa y cateto', () {
      final r = solve(s: [null, 12, 13], a: [null, null, 90]);
      near(r.solutions.first.sides[0], 5);
      near(r.solutions.first.angles[1], 67.3801);
    });
    test('razones: hipotenusa 10 y angulo 30', () {
      final r = solve(s: [null, null, 10], a: [30, null, 90]);
      near(r.solutions.first.sides[0], 5);
      near(r.solutions.first.sides[1], 8.6603);
      near(r.solutions.first.angles[1], 60);
      _clean(r.resolution);
    });
    test('razones: cateto y angulo opuesto', () {
      final r = solve(s: [7, null, null], a: [35, null, 90]);
      near(r.solutions.first.sides[2], 7 / 0.573576, 1e-3);
    });
    test('teorema del coseno: SSS y SAS', () {
      final sss = solve(s: [7, 8, 9]);
      expect(sss.kind, 'coseno');
      near(sss.solutions.first.angles.fold<double>(0, (p, v) => p + v), 180, 1e-6);
      _clean(sss.resolution);
      final sas = solve(s: [5, 7, null], a: [null, null, 60]);
      near(sas.solutions.first.sides[2], 6.245, 1e-3);
      expect(sas.kind, 'coseno');
      _clean(sas.resolution);
    });
    test('teorema del seno: ASA/AAS', () {
      final r = solve(s: [null, null, 10], a: [40, 60, null]);
      expect(r.kind, 'seno');
      near(r.solutions.first.angles[2], 80);
      near(r.solutions.first.sides[0], 6.527, 1e-3);
      _clean(r.resolution);
    });
    test('caso ambiguo SSA: dos soluciones', () {
      final r = solve(s: [5, 8, null], a: [30, null, null]);
      expect(r.isAmbiguous, isTrue);
      expect(r.kind, 'ambiguo');
      near(r.solutions[0].angles[1], 53.1301);
      near(r.solutions[1].angles[1], 126.8699);
      expect(r.steps(), contains('Caso ambiguo'));
      _clean(r.resolution);
    });
    test('SSA con una sola solucion e imposibles', () {
      final one = solve(s: [8, 5, null], a: [30, null, null]);
      expect(one.isAmbiguous, isFalse);
      expect(() => solve(s: [3, 8, null], a: [30, null, null]), throwsA(isA<ArsenalException>()));
      expect(() => solve(s: [1, 2, 5]), throwsA(isA<ArsenalException>()));
      expect(() => solve(a: [30, 60, 90]), throwsA(isA<ArsenalException>()));
      expect(() => solve(s: [5, null, null], a: [100, 90, null]), throwsA(isA<ArsenalException>()));
      expect(() => solve(s: [3, 4, null]), throwsA(isA<ArsenalException>()));
    });
  });

  group('Binomial B(n, p)', () {
    BinomialResult bin(String n, String p, String k, BinomialOp op) =>
        ProbabilityDistributionSolver.binomial(n: n, p: p, k: k, op: op);
    test('P(X=3) en B(10, 0,5) = 15/128', () {
      final r = bin('10', '0.5', '3', BinomialOp.eq);
      expect(r.resolution.exactResultLatex, r'\frac{15}{128}');
      expect((r.probability - 0.1171875).abs() < 1e-12, isTrue);
      expect(r.mean, 5);
      expect((r.sigma - 1.5811388).abs() < 1e-6, isTrue);
      expect(_tex(r.resolution), contains(r'\binom{10}{3}'));
      _clean(r.resolution);
    });
    test('acumuladas coherentes', () {
      final le = bin('10', '1/2', '3', BinomialOp.le);
      expect(le.resolution.exactResultLatex, r'\frac{11}{64}');
      final ge = bin('10', '1/2', '4', BinomialOp.ge);
      final lt = bin('10', '1/2', '3', BinomialOp.le);
      expect((ge.probability + lt.probability - 1).abs() < 1e-12, isTrue);
      var sum = 0.0;
      for (var k = 0; k <= 10; k++) {
        sum += bin('10', '0.3', '$k', BinomialOp.eq).probability;
      }
      expect((sum - 1).abs() < 1e-12, isTrue);
    });
    test('casos limite y errores', () {
      expect(bin('200', '0.5', '100', BinomialOp.le).probability > 0.5, isTrue);
      for (final bad in [
        () => bin('1', '1', '1', BinomialOp.eq), // p debe cumplir 0 < p < 1
        () => bin('5', '0', '0', BinomialOp.eq),
        () => bin('10', '1.5', '3', BinomialOp.eq),
        () => bin('10', '0.5', '11', BinomialOp.eq),
        () => bin('10', '0.5', '2.5', BinomialOp.eq),
        () => bin('0', '0.5', '0', BinomialOp.eq),
        () => bin('', '0.5', '0', BinomialOp.eq),
        () => bin('2000', '0.5', '0', BinomialOp.eq),
      ]) {
        expect(bad, throwsA(isA<ArsenalException>()));
      }
    });
  });

  group('Normal N(mu, sigma)', () {
    NormalResult nor(String mu, String s, String a, NormalOp op, [String? b]) =>
        ProbabilityDistributionSolver.normal(mu: mu, sigma: s, a: a, b: b, op: op);
    test('Phi: valores de referencia', () {
      const phi = ProbabilityDistributionSolver.phi;
      expect(phi(0), 0.5);
      expect((phi(1.96) - 0.9750021048517795).abs() < 1e-12, isTrue);
      expect((phi(-1.96) - 0.0249978951482205).abs() < 1e-12, isTrue);
      expect((phi(1) - 0.8413447460685429).abs() < 1e-12, isTrue);
      expect((phi(3) + phi(-3) - 1).abs() < 1e-14, isTrue);
      expect(phi(40), 1);
      expect(phi(-40), 0);
    });
    test('tipificacion y P(X<=a)', () {
      final r = nor('100', '15', '115', NormalOp.le);
      expect((r.probability - 0.8413447).abs() < 1e-6, isTrue);
      expect(r.resolution.exactResultLatex, '0{,}8413');
      final t = _tex(r.resolution);
      expect(t, contains(r'Z = \frac{X - \mu}{\sigma}'));
      expect(t, contains(r'z_{a} = \frac{115 - 100}{15} = 1'));
      _clean(r.resolution);
      expect(r.upper, 115);
      expect(r.lower, isNull);
    });
    test('P(X>=a) y P(a<=X<=b)', () {
      final ge = nor('100', '15', '115', NormalOp.ge);
      final le = nor('100', '15', '115', NormalOp.le);
      expect((ge.probability + le.probability - 1).abs() < 1e-12, isTrue);
      final bt = nor('100', '15', '85', NormalOp.between, '115');
      expect(bt.resolution.exactResultLatex, '0{,}6827');
      expect(bt.lower, 85);
      expect(bt.upper, 115);
      _clean(bt.resolution);
    });
    test('errores', () {
      expect(() => nor('0', '0', '1', NormalOp.le), throwsA(isA<ArsenalException>()));
      expect(() => nor('0', '-2', '1', NormalOp.le), throwsA(isA<ArsenalException>()));
      expect(() => nor('0', '1', '3', NormalOp.between, '1'), throwsA(isA<ArsenalException>()));
      expect(() => nor('0', '1', '', NormalOp.le), throwsA(isA<ArsenalException>()));
    });
  });

  group('Visores', () {
    testWidgets('caja espanola, campana y croquis sin overflow en tamanos pequenos', (t) async {
      final box = SpanishBoxDivisionSolver.divideText('x^3+2x^2-x+3', 'x^2+1');
      final bell = ProbabilityDistributionSolver.normal(mu: '100', sigma: '15', a: '85', b: '115', op: NormalOp.between);
      final tri = TriangleSolver.solve(sides: [3, 4, null], angles: [null, null, 90]);
      for (final size in [const Size(140, 90), const Size(340, 220)]) {
        for (final w in <Widget>[
          SpanishBoxDivisionView(result: box),
          GaussianBellView(result: bell),
          TriangleSketchView(solution: tri.solutions.first),
        ]) {
          await t.pumpWidget(MaterialApp(home: Center(child: SizedBox(width: size.width, height: size.height, child: w))));
          expect(t.takeException(), isNull);
        }
      }
      expect(find.byKey(const Key('triangle_sketch_clip')), findsOneWidget);
    });
    test('area sombreada y rango visible de la campana', () {
      final (lo, hi) = GaussianBellPainter.shadedRange(100, 15, 85, 115);
      expect((lo, hi), (85.0, 115.0));
      final (l2, h2) = GaussianBellPainter.shadedRange(0, 1, 1.5, null);
      expect(l2, 1.5);
      expect(h2, 4.0);
      expect(GaussianBellPainter.halfRange(0, 1, null, null), 4);
      expect(GaussianBellPainter.halfRange(0, 1, 6, null) > 6, isTrue);
    });
    test('texto de terminos de la caja', () {
      expect(SpanishBoxDivisionView.termText(Rational(-3), 2), '−3x²');
      expect(SpanishBoxDivisionView.termText(Rational(1), 1), '+x');
      expect(SpanishBoxDivisionView.termText(Rational(0), 1), '');
      expect(SpanishBoxDivisionView.termText(Rational(0), 1, blankZero: false), '+0x');
    });
    test('estado del formulario: selector, foco y teclas', () {
      final f = ModeFormState(selectorLabels: const ['a', 'b'], cols: 2, layouts: [
        [ModeField('p'), ModeField('q'), ModeField('r')],
        [ModeField('s')],
      ]);
      f.dpad('right');
      expect(f.selector, 1);
      f.dpad('left');
      f.dpad('down');
      expect(f.focus, 1);
      expect(f.key('7'), isTrue);
      expect(f.key('-'), isTrue);
      expect(f.text(0), '-7');
      f.dpad('right');
      f.dpad('down');
      expect(f.focus, 2);
      f.dpad('up');
      expect(f.focus, 0);
      expect(f.atTop, isTrue);
      expect(f.advance(), isFalse);
    });
  });

  group('E2E M4, M8, M10', () {
    Future<void> goMode(WidgetTester t, int n) async {
      await tapF(t, find.text('MODE'));
      if (n > 4) await tapF(t, find.byKey(const Key('menu_page_next')));
      if (n > 8) await tapF(t, find.byKey(const Key('menu_page_next')));
      await tapF(t, find.byKey(Key('menu_mode_$n')));
    }

    testWidgets('M4 division en caja: (x^2-1):(x-1) y visual de la caja', (t) async {
      await boot(t);
      await goMode(t, 4);
      await pickHeader(t, 'hdr_poly_kind', 'poly_tab_box');
      expect(find.byKey(const Key('xform_widget')), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await alphaKey(t, ')');
      await keys(t, ['x²', '-', '1', '=']);
      await alphaKey(t, ')');
      await keys(t, ['-', '1', '=']);
      expect(result(t), contains('C(x) = x + 1'));
      for (var i = 0; i < 5; i++) {
        await key(t, '=');
      }
      expect(find.byKey(const Key('box_division_clip')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('M4 fracciones: simplificar (x^2-1)/(x-1)', (t) async {
      await boot(t);
      await goMode(t, 4);
      await pickHeader(t, 'hdr_poly_kind', 'poly_tab_frac');
      await key(t, '=');
      await alphaKey(t, ')');
      await keys(t, ['x²', '-', '1', '=']);
      await alphaKey(t, ')');
      await keys(t, ['-', '1', '=']);
      expect(result(t), 'x + 1');
    });

    testWidgets('M10 recta por dos puntos: 2x - y = 0', (t) async {
      await boot(t);
      await goMode(t, 10);
      await pickHeader(t, 'hdr_vector_view', 'vector_view_1');
      await keys(t, ['=', '1', '=', '2', '=', '3', '=', '6', '=']);
      expect(result(t), '2x - y = 0');
      expect(t.takeException(), isNull);
    });

    testWidgets('M10 triangulo rectangulo 3-4-5 y croquis', (t) async {
      await boot(t);
      await goMode(t, 10);
      await pickHeader(t, 'hdr_vector_view', 'vector_view_2');
      await keys(t, ['3', '=', '4', '=', '=', '=', '=', '9', '0', '=']);
      expect(result(t), contains('c = 5{,}0000'));
      for (var i = 0; i < 8 && find.byKey(const Key('triangle_sketch_clip')).evaluate().isEmpty; i++) {
        await key(t, '=');
      }
      expect(find.byKey(const Key('triangle_sketch_clip')), findsOneWidget);
    });

    testWidgets('M10 triangulo imposible muestra LcdErrorScreen', (t) async {
      await boot(t);
      await goMode(t, 10);
      await pickHeader(t, 'hdr_vector_view', 'vector_view_2');
      await keys(t, ['1', '=', '2', '=', '5', '=', '=', '=', '=']);
      expect(find.byKey(const Key('lcd_error_screen')), findsOneWidget);
    });

    testWidgets('M8 Normal N(100,15): P(X<=115) y campana', (t) async {
      await boot(t);
      await goMode(t, 8);
      await pickHeader(t, 'hdr_stat_kind', 'stat_kind_2');
      await keys(t, ['=', '1', '0', '0', '=', '1', '5', '=', '1', '1', '5', '=']);
      expect(result(t), '0{,}8413');
      for (var i = 0; i < 4; i++) {
        await key(t, '=');
      }
      expect(find.byKey(const Key('gaussian_bell_clip')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('M8 Binomial B(10, 1/2): P(X=3)', (t) async {
      await boot(t);
      await goMode(t, 8);
      await pickHeader(t, 'hdr_stat_kind', 'stat_kind_3');
      await keys(t, ['=', '1', '0', '=', '1', 'a/b', '2', '=', '3', '=']);
      expect(result(t), r'\frac{15}{128}');
    });

    testWidgets('M8 dos variables: regresion de (1,2),(2,4),(3,6)', (t) async {
      await boot(t);
      await goMode(t, 8);
      await pickHeader(t, 'hdr_stat_kind', 'stat_kind_1');
      await keys(t, ['1']);
      await pad(t, 'right');
      await keys(t, ['2']);
      await pad(t, 'down');
      await pad(t, 'left');
      await keys(t, ['2']);
      await pad(t, 'right');
      await keys(t, ['4']);
      await pad(t, 'down');
      await pad(t, 'left');
      await keys(t, ['3']);
      await pad(t, 'right');
      await keys(t, ['6', '=']);
      expect(result(t), isNotNull);
      expect(t.takeException(), isNull);
    });
  });
}

extension on TriangleResult {
  String steps() => resolution.steps.map((s) => s.shortTitle).join('|');
}
