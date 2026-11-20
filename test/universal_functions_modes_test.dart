import 'dart:math' as math;

import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/calculus/sym_build.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/exact/ext_expr.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/exact/ext_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/symbolic_derivative_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/symbolic_integral_solver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/exercise_dsl.dart';

XNode _p(String s) => ExtParser().parse(s);

double _f(XNode n, double x) => Sx.numAt(n, x)!;

/// f'(x) simbolica contra diferencia central.
void _derivMatches(String raw, List<double> xs) {
  final f = _p(raw);
  final d = SymbolicDerivativeSolver.differentiate(f).derivative;
  const h = 1e-5;
  for (final x in xs) {
    final numeric = (_f(f, x + h) - _f(f, x - h)) / (2 * h);
    expect((_f(d, x) - numeric).abs(), lessThan(1e-4 * (1 + numeric.abs())),
        reason: "d/dx $raw en x=$x: simbolica ${_f(d, x)} vs numerica $numeric");
  }
  expectCleanNotes(SymbolicDerivativeSolver.derivative(raw));
}

/// F'(x) = f(x) para la primitiva devuelta por el integrador.
void _antiderivMatches(String raw, List<double> xs) {
  final f = _p(raw);
  final big = SymbolicIntegralSolver.antiderivative(f).antiderivative;
  const h = 1e-5;
  for (final x in xs) {
    final numeric = (_f(big, x + h) - _f(big, x - h)) / (2 * h);
    expect((numeric - _f(f, x)).abs(), lessThan(1e-4 * (1 + _f(f, x).abs())),
        reason: "F'($x) de $raw: $numeric vs ${_f(f, x)}");
  }
  expectCleanNotes(SymbolicIntegralSolver.indefinite(raw));
}

StepByStepResolution _def(String raw, int a, int b) =>
    SymbolicIntegralSolver.definite(raw, Rational(a), Rational(b));

void main() {
  group('M12 derivadas de las 8 familias', () {
    test('raiz cubica, log base 2, inversas e hiperbolicas', () {
      _derivMatches('cbrt(x+2)', [-1, 0.5, 3]);
      _derivMatches('log_(2,x)', [0.5, 1, 4]);
      _derivMatches('arctan(2x)', [-1, 0.3, 2]);
      _derivMatches('arcsin(x)', [-0.5, 0.2, 0.7]);
      _derivMatches('sinh(3x)', [-1, 0.2, 0.9]);
      _derivMatches('cosh(x)', [-1, 0.4, 1.3]);
      _derivMatches('tanh(x)', [-1, 0.4, 1.3]);
    });

    test('forma de la raiz n-esima y hiperbolica no cae en log', () {
      final sq = SymbolicDerivativeSolver.derivative('sqrt(x+1)').exactResultLatex;
      expect(sq, contains(r'\sqrt{x + 1}'));
      final cb = SymbolicDerivativeSolver.derivative('cbrt(x+2)').exactResultLatex;
      expect(cb, contains(r'\sqrt[3]'));
      final sh = SymbolicDerivativeSolver.derivative('sinh(x)').exactResultLatex;
      expect(sh, contains(r'\cosh'));
      expect(sh, isNot(contains(r'\ln')));
    });
  });

  group('M12 integrales de las 8 familias', () {
    test('primitivas verificadas por derivacion numerica', () {
      _antiderivMatches('cbrt(x+2)', [-1, 0.5, 3]);
      _antiderivMatches('cosh(2x)', [-1, 0.4, 1.3]);
      _antiderivMatches('sinh(x)', [-1, 0.4, 1.3]);
      _antiderivMatches('tanh(x)', [-1, 0.4, 1.3]);
      _antiderivMatches('arctan(x)', [-1, 0.4, 1.3]);
      _antiderivMatches('arcsin(x)', [-0.5, 0.2, 0.7]);
      _antiderivMatches('1/sqrt(4-x^2)', [-1, 0.4, 1.3]);
      _antiderivMatches('1/(4+x^2)', [-1, 0.4, 1.3]);
      _antiderivMatches('1/cosh(x)^2', [-1, 0.4, 1.3]);
      _antiderivMatches('log_(2,x)', [0.5, 1, 4]);
    });

    test('integrales definidas', () {
      for (final (raw, a, b, expected) in [
        ('cbrt(x+2)', -1, 1, 0.75 * (math.pow(3, 4 / 3) - 1)),
        ('cosh(x)', 0, 1, 1.1752011936438014),
        ('arctan(x)', 0, 1, 0.4388245731174757),
      ]) {
        final r = _def(raw, a, b);
        expectCleanNotes(r);
        final dec = double.parse(r.decimalApproxLatex.replaceAll('{,}', '.').replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.\-]'), ''));
        expect((dec - expected).abs(), lessThan(1e-4), reason: '$raw -> ${r.decimalApproxLatex}');
      }
    });
  });
}
