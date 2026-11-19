import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/calculus_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/complex_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/inequality_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_equation_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_inequality_2d_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_system_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/matrix_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/rational_function_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/ruffini_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/statistics_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/super_equation_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/vector_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/exact/extended_calc_solver.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';

/// LaTeX valido: sin tildes en \text, indices con llaves y compilable por flutter_math_fork.
void checkLatex(String label, String latex) {
  final s = CasioLcdScreen.sanitizeForMathTex(latex);
  for (final m in RegExp(r'\\(?:text|mathrm)\{([^}]+)\}').allMatches(s)) {
    expect(RegExp(r'[áéíóúÁÉÍÓÚñÑ¿¡]').hasMatch(m.group(1)!), isFalse,
        reason: 'tilde en \\text{} [$label]: ${m.group(1)}');
  }
  expect(RegExp(r'_(?:10|[a-zA-Z]{2,})').hasMatch(s), isFalse, reason: 'indice sin llaves [$label]: $s');
  expect(RegExp(r'\+ ?-|- ?-').hasMatch(s), isFalse, reason: 'doble signo [$label]: $s');
  expect(RegExp(r'(?<![\d.}a-zA-Z_^])[+-]?1x').hasMatch(s), isFalse, reason: '1x [$label]: $s');
  try {
    SyntaxTree(greenRoot: TexParser(s, const TexParserSettings()).parse())
        .buildWidget(MathOptions(style: MathStyle.display, fontSize: 18));
  } catch (e) {
    fail('LaTeX no compila [$label]: $latex -> $e');
  }
}

StepByStepResolution ok(String label, StepByStepResolution r) {
  checkLatex('$label.in', r.originalInputLatex);
  checkLatex('$label.out', r.exactResultLatex);
  for (final s in r.steps) {
    checkLatex('$label.step${s.index}', s.latexExpression);
  }
  return r;
}

String m1(String e) => ExtendedCalcSolver.solve(e).exactResultLatex;
String d(String f) => CalculusSolver.solve(operation: CalculusOperation.derivative, expressionRaw: f).exactResultLatex;
String ig(String f) => CalculusSolver.solve(operation: CalculusOperation.indefiniteIntegral, expressionRaw: f).exactResultLatex;
StepByStepResolution eq(String e) => ok(e, SuperEquationSolver.solve(e));

void main() {
  test('M1 jerarquia y logaritmos', () {
    expect(m1('-3^2'), '-9');
    expect(m1('(-3)^2'), '9');
    expect(m1('6/√(3)'), r'2\sqrt{3}');
    expect(m1('log_2(8)+ln(e^2)'), '5');
  });

  group('M2 ecuaciones', () {
    test('1.º grado desordenada y 2.º grado (3 casos)', () {
      expect(ok('lin', LinearEquationSolver.solveEquationString('3x - 5 + 2x = 7 - x')).exactResultLatex, 'x = 2');
      expect(eq('x^2 - 5x + 6 = 0').exactResultLatex, allOf(contains('2'), contains('3')));
      expect(eq('x^2 - 4x + 4 = 0').exactResultLatex, 'x = 2');
      expect(eq('x^2 + 4 = 0').exactResultLatex, contains('Sin solucion real'));
    });
    test('bicuadrada, racional, irracional, exponencial y logaritmica', () {
      expect(eq('x^4 - 5x^2 + 4 = 0').exactResultLatex, allOf(contains('x = -2'), contains('x = 2')));
      expect(eq(r'\frac{x+1}{x-1} = \frac{2}{x-1}').exactResultLatex, anyOf(contains('Sin'), contains('emptyset')));
      final irr = eq(r'\sqrt{2x + 3} = x');
      expect(irr.exactResultLatex, 'x = 3');
      expect(irr.steps.map((s) => s.latexExpression).join(), contains('-1'));
      expect(eq('2^{2x-1} = 32').exactResultLatex, 'x = 3');
      expect(eq('5^x = 12').exactResultLatex, contains(r'\frac{\ln(12)}{\ln(5)}'));
      expect(eq(r'\log(x) + \log(x-3) = 1').exactResultLatex, 'x = 5');
    });
  });

  group('M3 sistemas', () {
    test('2x2 desordenado por los 3 metodos y sistema incompatible', () {
      for (final m in SystemResolutionMethod.values) {
        final r = ok('2x2 $m', LinearSystemSolver.solveFromEquations(['y + 2x = 5', '1 = x - y'], method: m));
        expect(r.exactResultLatex, allOf(contains('x = 2'), contains('y = 1')), reason: '$m');
      }
      final si = ok('SI', LinearSystemSolver.solveFromEquations(['x + y = 2', 'x + y = 5']));
      expect(si.exactResultLatex, contains('S.I.'));
    });
    test('3x3 desordenado', () {
      for (final m in SystemResolutionMethod.values) {
        final r = ok('3x3 $m', LinearSystemSolver.solveFromEquations(
            ['x + y + z = 6', '2y - x + z = 6', 'x - y - z + 4 = 0'], method: m));
        expect(r.exactResultLatex, allOf(contains('x = 1'), contains('y = 2'), contains('z = 3')), reason: '$m');
      }
    });
  });

  group('M4 Ruffini y notables', () {
    test('x^4 - 16 entre x - 2 con polinomio incompleto', () {
      final step = RuffiniSolver.executeRuffiniStep([1, 0, 0, 0, -16], 2);
      expect(step.remainder, 0);
      expect(step.quotientCoeffs, [1, 2, 4, 8]);
      final r = ok('x4-16', RuffiniSolver.factorize([1, 0, 0, 0, -16]));
      expect(r.exactResultLatex, contains('(x - 2)'));
      expect(r.exactResultLatex, contains('(x + 2)'));
    });
  });

  group('M5 funcion racional', () {
    test('(2x+1)/(x-3): dominio, cortes y asintotas sin evaluar en 3', () {
      final r = ok('racional', RationalFunctionSolver.analyze('(2x+1)/(x-3)'));
      expect(r.exactResultLatex, allOf(contains(r'\mathbb{R}'), contains('x = 3'), contains('y = 2')));
      final cuts = r.steps[1].latexExpression;
      expect(cuts, contains(r'\left(0,\,-\frac{1}{3}\right)'));
      expect(cuts, contains(r'-\frac{1}{2}'));
    });
  });

  group('M6/M7 inecuaciones', () {
    test('M6', () {
      expect(ok('a', InequalitySolver.solveString('-2x + 6 > 10')).exactResultLatex, contains(r'(-\infty, -2)'));
      expect(ok('b', InequalitySolver.solveString('x^2 - 4 <= 0')).exactResultLatex, contains('[-2, 2]'));
      expect(ok('c', InequalitySolver.solveString('|2x - 8| > 3')).exactResultLatex,
          allOf(contains(r'\infty'), contains(r'\cup')));
    });
    test('M7 1D, 2D acotado, no acotado y vacio', () {
      final s1 = InequalitySolver.solveSystem1D(['x^2 - 4 <= 0', 'x > 0']);
      expect(ok('1d', s1.resolution).exactResultLatex, contains('(0, 2]'));
      final tri = LinearInequality2DSolver.solveSystem2D(['x >= 0', 'y >= 0', 'x + y <= 4']);
      expect(tri.visualData.isBounded, isTrue);
      expect(tri.visualData.vertices, hasLength(3));
      final open = LinearInequality2DSolver.solveSystem2D(['x + y > 0', 'x - 2y <= 5']);
      expect(open.visualData.isEmpty, isFalse);
      expect(open.visualData.isBounded, isFalse);
      final empty = LinearInequality2DSolver.solveSystem2D(['x + y > 5', 'x + y < 2']);
      expect(empty.visualData.isEmpty, isTrue);
      ok('2d-empty', empty.resolution);
    });
  });

  group('M8 estadistica', () {
    test('1 variable con frecuencias y regresion con varianza cero', () {
      final r = StatisticsOneVarSolver.analyze([
        StatDataPoint(Rational(1), 2),
        StatDataPoint(Rational(2), 3),
        StatDataPoint(Rational(3), 5),
      ]);
      expect(r.mean, Rational(23, 10));
      ok('1var', r.resolution);
      final lin = StatisticsTwoVarSolver.analyze([
        TwoVarPoint(Rational(1), Rational(3)),
        TwoVarPoint(Rational(2), Rational(5)),
        TwoVarPoint(Rational(3), Rational(7)),
      ]);
      expect(lin.slopeM, Rational(2));
      final zero = StatisticsTwoVarSolver.analyze([
        TwoVarPoint(Rational(4), Rational(1)),
        TwoVarPoint(Rational(4), Rational(2)),
      ]);
      expect(zero.varX.isZero, isTrue);
      ok('2var0', zero.resolution);
    });
  });

  group('M9 matrices', () {
    test('2x3 por 3x2, det 3x3 y 4x4, inversa, singular y AX=B 4x1', () {
      final a = RationalMatrix.fromInts([[1, 2, 3], [4, 5, 6]]);
      final b = RationalMatrix.fromInts([[7, 8], [9, 1], [2, 3]]);
      expect(ok('mul', MatrixSolver.multiply(a, b)).exactResultLatex, allOf(contains('31'), contains('19')));
      final m3 = RationalMatrix.fromInts([[2, 0, 1], [1, 3, 2], [1, 1, 1]]);
      expect(ok('d3', MatrixSolver.determinant(m3)).exactResultLatex, contains('= 0'));
      final m4 = RationalMatrix.fromInts([[1, 2, 0, 1], [0, 1, 3, 2], [2, 0, 1, 1], [1, 1, 1, 0]]);
      ok('d4', MatrixSolver.determinant(m4));
      final inv = RationalMatrix.fromInts([[2, 1], [1, 1]]);
      expect(ok('inv', MatrixSolver.inverse(inv)).exactResultLatex, contains('1 & -1'));
      final sing = RationalMatrix.fromInts([[1, 2], [2, 4]]);
      expect(ok('sing', MatrixSolver.inverse(sing)).exactResultLatex, contains(r'\nexists'));
      final a4 = RationalMatrix.fromInts([[2, 1, 0, 0], [1, 3, 1, 0], [0, 1, 4, 1], [0, 0, 1, 5]]);
      final b4 = RationalMatrix.fromInts([[1], [2], [3], [4]]);
      ok('AX=B', MatrixSolver.cramer(a4, b4));
    });
  });

  group('M10 vectores', () {
    test('modulo, escalar, vectorial, mixto, angulo y nulo', () {
      final u = RationalVector.fromInts([1, 2, 2]);
      final v = RationalVector.fromInts([2, 0, 1]);
      final w = RationalVector.fromInts([0, 1, 1]);
      expect(ok('mod', VectorSolver.modulus(u)).exactResultLatex, contains('3'));
      ok('dot', VectorSolver.dotProductAndAngle(u, v));
      ok('cross', VectorSolver.crossProductAndArea(u, v));
      final mixed = ok('mixto', VectorSolver.mixedProduct(u, v, w));
      expect(mixed.exactResultLatex, contains('-1'));
      final zero = RationalVector.fromInts([0, 0, 0]);
      expect(() => ok('nulo', VectorSolver.dotProductAndAngle(u, zero)), returnsNormally);
      expect(() => ok('nulo-mod', VectorSolver.modulus(zero)), returnsNormally);
    });
  });

  group('M11 complejos', () {
    test('operaciones, i^2026 y binomica <-> polar', () {
      final z1 = RationalComplex.fromInts(2, 3);
      final z2 = RationalComplex.fromInts(1, -1);
      ok('add', ComplexSolver.add(z1, z2));
      ok('mul', ComplexSolver.multiply(z1, z2));
      expect(ok('div', ComplexSolver.divide(z1, z2)).exactResultLatex, contains(r'\frac{1}{2}'));
      expect(ok('i2026', ComplexSolver.powerOfI(2026)).exactResultLatex, '-1');
      expect(ok('polar', ComplexSolver.toPolar(RationalComplex.fromInts(1, 1))).exactResultLatex,
          contains(r'_{45^{\circ}}'));
      ok('binomica', ComplexSolver.fromPolar(modulus: Rational(2), angleDegrees: 90));
    });
  });

  group('M12 calculo', () {
    test('derivadas', () {
      expect(d('x^3'), r"f'(x) = 3x^{2}");
      expect(d('sin(3x^2)'), r"f'(x) = 6x\cos\left(3x^{2}\right)");
      expect(d('x*e^x'), r"f'(x) = \left(x + 1\right)e^{x}");
      expect(d('(x+1)/(x-1)'), contains(r'\frac'));
      expect(d('ln(x^2+1)'), r"f'(x) = \frac{2x}{x^{2} + 1}");
      final t = CalculusSolver.solve(
          operation: CalculusOperation.tangentLine, expressionRaw: 'ln(x^2+1)', tangentX0: Rational(1));
      ok('tangente', t);
      expect(t.exactResultLatex, startsWith('y ='));
    });
    test('integrales', () {
      expect(ig('x^2+cos(x)'), allOf(contains(r'\sin'), contains('+ C')));
      expect(ig('2x/(x^2+1)'), allOf(contains(r'\ln'), contains('+ C')));
      expect(ig('x*e^x'), allOf(contains('e^{x}'), contains('+ C')));
      final def = CalculusSolver.solve(
          operation: CalculusOperation.definiteIntegral,
          expressionRaw: 'x^2',
          integralLowerA: Rational(0),
          integralUpperB: Rational(2));
      expect(ok('barrow', def).exactResultLatex, contains(r'\frac{8}{3}'));
    });
  });
}
