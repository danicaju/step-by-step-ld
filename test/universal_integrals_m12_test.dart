import 'dart:math' as math;

import 'package:casio_tutor_calc/domain/math_engine/calculus/non_elementary_integral_handler.dart';
import 'package:casio_tutor_calc/domain/math_engine/calculus/polynomial_real_factorizer.dart';
import 'package:casio_tutor_calc/domain/math_engine/calculus/universal_rational_integrator.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/calculus_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/equations/eq_poly.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/exact/exact_number.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/symbolic_integral_solver.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_test/flutter_test.dart';

final _tildes = RegExp(r'[áéíóúÁÉÍÓÚñÑ¿¡]');
final _textArg = RegExp(r'\\(?:text|mathrm)\{([^}]+)\}');

void _render(String label, String latex) {
  final sanitized = CasioLcdScreen.sanitizeForMathTex(latex);
  final inText = _textArg.allMatches(sanitized).map((m) => m.group(1)!).join();
  expect(_tildes.hasMatch(inText), isFalse, reason: 'tildes en \\text [$label]');
  expect(latex.contains('\r'), isFalse, reason: 'CR en [$label]');
  try {
    final ast = SyntaxTree(greenRoot: TexParser(sanitized, const TexParserSettings()).parse());
    ast.buildWidget(MathOptions(style: MathStyle.display, fontSize: 18));
  } catch (e) {
    fail('LaTeX invalido en [$label]: $latex\n$e');
  }
}

void _all(String label, StepByStepResolution r) {
  _render('$label.original', r.originalInputLatex);
  _render('$label.exact', r.exactResultLatex);
  _render('$label.decimal', r.decimalApproxLatex);
  for (var i = 0; i < r.steps.length; i++) {
    final s = r.steps[i];
    _render('$label.step$i', s.latexExpression);
    for (final plain in [s.pedagogicalNote, s.warningTrick ?? '', s.shortTitle]) {
      expect(RegExp(r'\\frac|\\cdot|\^\{|\$\d').hasMatch(plain), isFalse,
          reason: 'LaTeX crudo en texto plano [$label.step$i]: $plain');
    }
  }
}

RationalIntegration _ri(String raw) {
  final pq = PolyOps.rationalOf(SymbolicIntegralSolver.parse(raw))!;
  final r = UniversalRationalIntegrator.integrate(pq.$1, pq.$2);
  expect(r, isNotNull, reason: 'no integra $raw');
  return r!;
}

void _derivMatches(RationalIntegration r, double Function(double) f, List<double> xs) {
  const h = 1e-5;
  for (final x in xs) {
    final d = (r.primitive.eval(x + h) - r.primitive.eval(x - h)) / (2 * h);
    expect((d - f(x)).abs(), lessThan(1e-4), reason: "F'($x) = $d, f($x) = ${f(x)}");
  }
}

StepByStepResolution _ind(String f) =>
    CalculusSolver.solve(operation: CalculusOperation.indefiniteIntegral, expressionRaw: f);

StepByStepResolution _def(String f, Rational a, Rational b) => CalculusSolver.solve(
      operation: CalculusOperation.definiteIntegral,
      expressionRaw: f,
      integralLowerA: a,
      integralUpperB: b,
    );

String _allLatex(StepByStepResolution r) =>
    [r.exactResultLatex, ...r.steps.map((s) => s.latexExpression)].join(' ');

void main() {
  const pts = [0.0, 0.5, 1.5, -0.5];

  group('Integrador racional universal', () {
    test('1/(x^5+1): factorizacion con (1 ± √5)/2 y F\' = f', () {
      final r = _ri('1/(x^5+1)');
      expect(r.factorization.level, FactorLevel.exactRadical);
      final fl = r.factorization.latex();
      expect(fl, contains(r'\frac{1 + \sqrt{5}}{2}'));
      expect(fl, contains(r'\sqrt{5} - 1'));
      _derivMatches(r, (x) => 1 / (math.pow(x, 5) + 1), pts);
      final res = _ind('1/(x^5+1)');
      expect(_allLatex(res), contains(r'\sqrt{5}'));
      expect(res.steps.any((s) => s.shortTitle.contains('Factorización real')), isTrue);
      expect(res.steps.any((s) => s.shortTitle.contains('fracciones simples')), isTrue);
      expect(res.exactResultLatex, endsWith('+ C'));
      _all('x5+1', res);
    });

    test('1/(x^4+1): factorizacion con √2 y F\' = f', () {
      final r = _ri('1/(x^4+1)');
      expect(r.factorization.latex(), contains(r'\sqrt{2}'));
      _derivMatches(r, (x) => 1 / (math.pow(x, 4) + 1), pts);
      final res = _ind('1/(x^4+1)');
      expect(res.exactResultLatex, contains(r'\arctan'));
      _all('x4+1', res);
    });

    test('1/(x^5+x+1): Aberth, fracciones simples y F\' = f', () {
      final r = _ri('1/(x^5+x+1)');
      expect(r.factorization.level, FactorLevel.numeric);
      // x^5 + x + 1 = (x^2 + x + 1)(x^3 - x^2 + 1): el factor racional sale exacto.
      expect(r.factorization.latex(), contains(r'x^{2} + x + 1'));
      expect(r.fractions.length, 3);
      _derivMatches(r, (x) => 1 / (math.pow(x, 5) + x + 1), pts);
      _all('x5+x+1', _ind('1/(x^5+x+1)'));
    });

    test('x^5/(x^5+1): division polinomica previa', () {
      final r = _ri('x^5/(x^5+1)');
      expect(r.quotient, isNotEmpty);
      _derivMatches(r, (x) => math.pow(x, 5) / (math.pow(x, 5) + 1), pts);
      final res = _ind('x^5/(x^5+1)');
      expect(res.steps.first.shortTitle, contains('División polinómica'));
      _all('x5/(x5+1)', res);
    });

    test('raices multiples y cuadraticos repetidos', () {
      final a = _ri('1/((x-1)^2*(x^2+1)^2)');
      _derivMatches(a, (x) => 1 / (math.pow(x - 1, 2) * math.pow(x * x + 1, 2)), [0, 0.5, 2, -1.5]);
      final b = _ri('(x^2+3)/(x^3-2x)');
      _derivMatches(b, (x) => (x * x + 3) / (x * x * x - 2 * x), [0.5, 2, -0.7, 3]);
      expect(b.factorization.latex(), contains(r'\sqrt{2}'));
      _all('rep', _ind('1/((x-1)^2*(x^2+1)^2)'));
    });

    test('Aberth: raices de x^5 + x + 1', () {
      final roots = PolynomialRealFactorizer.aberth({5: Rational(1), 1: Rational(1), 0: Rational(1)});
      for (final z in roots) {
        // |p(z)| ≈ 0 en complejos
        var re = 1.0, im = 0.0, pr = 0.0, pi = 0.0;
        for (var k = 0; k <= 5; k++) {
          final c = k == 5 || k == 1 || k == 0 ? 1.0 : 0.0;
          pr += c * re;
          pi += c * im;
          final nre = re * z.re - im * z.im;
          im = re * z.im + im * z.re;
          re = nre;
        }
        expect(math.sqrt(pr * pr + pi * pi), lessThan(1e-9));
      }
    });

    test('definida racional: Barrow y polos en [a, b]', () {
      final r = _def('1/(x^4+1)', Rational(0), Rational(1));
      expect(r.decimalApproxLatex, anyOf(contains('0.866973'), contains('0,866973')));
      _all('def x4+1', r);
      expect(() => _def('1/(x^5+1)', Rational(-2), Rational(0)), throwsA(isA<ExMathError>()));
    });
  });

  group('Integrales sin primitiva elemental', () {
    test('indefinida e^(-x^2): erf sin error', () {
      final r = _ind('e^(-x^2)');
      expect(r.exactResultLatex, contains(r'\mathrm{erf}'));
      expect(r.steps.any((s) => s.pedagogicalNote.contains('Liouville')), isTrue);
      expect(r.steps.any((s) => s.shortTitle.contains('Integral Definida')), isTrue);
      _all('e^-x2', r);
    });

    test('indefinida sin(x)/x: seno integral', () {
      final r = _ind('sin(x)/x');
      expect(r.exactResultLatex, contains(r'\mathrm{Si}'));
      _all('sinx/x', r);
    });

    test('otras familias se detectan', () {
      for (final f in ['x^2*e^(-x^2)', 'cos(2x)/x', 'e^x/x', '1/ln(x)', 'sin(x^2)', 'sqrt(1+x^3)', 'sqrt(1-x^4)', '3e^(x^2)']) {
        final r = _ind(f);
        expect(r.steps.any((s) => s.pedagogicalNote.contains('Liouville')), isTrue, reason: f);
        _all(f, r);
      }
    });

    test('definida e^(-x^2) en [0, 1] ≈ 0.746824', () {
      final f = SymbolicIntegralSolver.parse('e^(-x^2)');
      final v = NonElementaryIntegralHandler.numericValue(f, 0, 1);
      expect((v - 0.746824132812427).abs(), lessThan(1e-5));
      final r = _def('e^(-x^2)', Rational(0), Rational(1));
      expect(r.decimalApproxLatex, anyOf(contains('0.746824'), contains('0,746824')));
      _all('def e^-x2', r);
    });

    test('definida sin(x)/x en [0, 1] (singularidad evitable) e impropias', () {
      final f = SymbolicIntegralSolver.parse('sin(x)/x');
      expect((NonElementaryIntegralHandler.numericValue(f, 0, 1) - 0.946083070367183).abs(), lessThan(1e-6));
      expect(() => _def('e^x/x', Rational(-1), Rational(1)), throwsA(isA<ExMathError>()));
    });
  });
}
