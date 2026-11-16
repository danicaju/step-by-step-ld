import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart';

import 'package:casio_tutor_calc/domain/math_engine/core/algebraic_latex_formatter.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/step_evaluator.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/trig_and_angles_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/radical_and_factor_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_equation_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/quadratic_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/super_equation_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_system_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/ruffini_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/notable_identities_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/function_graph_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/inequality_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_inequality_2d_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/statistics_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/matrix_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/vector_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/complex_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/calculus_solver.dart';

import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';

/// Validador estricto de sintaxis LaTeX y compatibilidad con flutter_math_fork
void verifyLatexOutput(String label, String latex) {
  final sanitized = CasioLcdScreen.sanitizeForMathTex(latex);

  // 1. Regla de oro: Cero tildes y caracteres no ASCII dentro de \text{...} o \mathrm{...}
  final textMatches = RegExp(r'\\(?:text|mathrm)\{([^}]+)\}').allMatches(sanitized);
  for (final m in textMatches) {
    final inner = m.group(1)!;
    expect(
      RegExp(r'[áéíóúÁÉÍÓÚñÑ¿¡]').hasMatch(inner),
      isFalse,
      reason: 'Caracter acentuado/no-ASCII dentro de \\text{$inner} en [$label]',
    );
  }

  // 2. Subíndices y superíndices multi-carácter deben llevar llaves
  expect(
    RegExp(r'_(?:10|[a-zA-Z]{2,})').hasMatch(sanitized),
    isFalse,
    reason: 'Subíndice multi-carácter sin llaves en [$label]: $sanitized',
  );

  // 3. Renderizado real mediante TexParser de flutter_math_fork
  try {
    final ast = SyntaxTree(
      greenRoot: TexParser(sanitized, const TexParserSettings()).parse(),
    );
    ast.buildWidget(MathOptions(
      style: MathStyle.display,
      fontSize: 18,
    ));
  } catch (e) {
    fail('Error de compilación LaTeX en [$label]:\nRaw: $latex\nSanitized: $sanitized\nError: $e');
  }
}

void verifyResolutionLatex(String label, StepByStepResolution res) {
  verifyLatexOutput('$label.original', res.originalInputLatex);
  verifyLatexOutput('$label.exact', res.exactResultLatex);
  if (res.decimalApproxLatex.isNotEmpty) {
    verifyLatexOutput('$label.decimal', res.decimalApproxLatex);
  }
  for (int i = 0; i < res.steps.length; i++) {
    verifyLatexOutput('$label.step[$i]', res.steps[i].latexExpression);
  }
}

void main() {
  // ===========================================================================
  // MODO 1: CALCULAR (Aritmética, Fracciones, Jerarquía, Raíces y Trigonometría)
  // ===========================================================================
  group('Fase 9D - Modo 1: Calcular', () {
    final parser = ExpressionParser();
    final evaluator = StepEvaluator();

    test('Jerarquía de operaciones: -3^2 vs (-3)^2', () {
      final res1 = evaluator.evaluate(parser.parse('-3^2'));
      expect(res1.exactResultLatex, equals('-9'));

      final res2 = evaluator.evaluate(parser.parse('(-3)^2'));
      expect(res2.exactResultLatex, equals('9'));

      verifyResolutionLatex('Hierarchy -3^2', res1);
      verifyResolutionLatex('Hierarchy (-3)^2', res2);
    });

    test('Fracciones combinadas irreducibles: 1/2 + (3/4)*(2/3) = 1', () {
      final res = evaluator.evaluate(parser.parse('1/2 + (3/4) * (2/3)'));
      expect(res.exactResultLatex, equals('1'));
      verifyResolutionLatex('Fracciones combinadas', res);
    });

    test('Simplificación radical exacta y racionalización: sqrt(72) y 6/sqrt(3)', () {
      final resSqrt = RadicalAndFactorSolver.simplifySquareRoot(72);
      expect(resSqrt.exactResultLatex, equals(r'6\sqrt{2}'));
      verifyResolutionLatex('sqrt(72)', resSqrt);

      final ratLatex = AlgebraicLatexFormatter.rationalSqrtLatex(Rational(12));
      expect(ratLatex, equals(r'2\sqrt{3}'));
      verifyLatexOutput('6/sqrt(3) -> 2sqrt(3)', ratLatex);
    });

    test('Expresiones algebraicas, funciones anidadas y potencias trigonométricas', () {
      final rawTrig = 'sin^2(30)';
      final latexTrig = ExpressionParser.rawToLiveLatex(rawTrig);
      expect(latexTrig, contains('sin'));
      verifyLatexOutput('sin^2(30)', latexTrig);

      final rawNested = 'sin(cos(x))';
      final latexNested = ExpressionParser.rawToLiveLatex(rawNested);
      verifyLatexOutput('sin(cos(x))', latexNested);

      final rawExp = '2^(2+x)';
      final latexExp = ExpressionParser.rawToLiveLatex(rawExp);
      verifyLatexOutput('2^(2+x)', latexExp);
    });

    test('Identidad pitagórica fundamental: sin²(30°) + cos²(30°) = 1 (DEG) y sin²(π/4) + cos²(π/4) = 1 (RAD)', () {
      final degEval = StepEvaluator(angleUnit: AngleUnit.deg);
      final resDeg = degEval.evaluate(parser.parse('sin(30)^2+cos(30)^2'));
      expect(resDeg.exactResultLatex, equals('1'));
      verifyResolutionLatex('Trig DEG Identity', resDeg);

      final radEval = StepEvaluator(angleUnit: AngleUnit.rad);
      final resRad = radEval.evaluate(parser.parse('sin(pi/4)^2+cos(pi/4)^2'));
      expect(resRad.exactResultLatex, equals('1'));
      verifyResolutionLatex('Trig RAD Identity', resRad);
    });

    test('Funciones anidadas e inversas: cos(sin(0)) = 1 y sqrt(sin(90°)) = 1', () {
      final degEval = StepEvaluator(angleUnit: AngleUnit.deg);
      final resCosSin = degEval.evaluate(parser.parse('cos(sin(0))'));
      expect(resCosSin.exactResultLatex, equals('1'));
      verifyResolutionLatex('cos(sin(0))', resCosSin);

      final resSqrtSin = degEval.evaluate(parser.parse('sqrt(sin(90))'));
      expect(resSqrtSin.exactResultLatex, equals('1'));
      verifyResolutionLatex('sqrt(sin(90))', resSqrtSin);
    });

    test('Navegación y salida de cursor: sqrt(4)+5 = 7, sin(30)*4 = 2 y 2^(2+1) = 8', () {
      final degEval = StepEvaluator(angleUnit: AngleUnit.deg);
      final res1 = degEval.evaluate(parser.parse('sqrt(4)+5'));
      expect(res1.exactResultLatex, equals('7'));
      verifyResolutionLatex('sqrt(4)+5', res1);

      final res2 = degEval.evaluate(parser.parse('sin(30)*4'));
      expect(res2.exactResultLatex, equals('2'));
      verifyResolutionLatex('sin(30)*4', res2);

      final res3 = degEval.evaluate(parser.parse('2^(2+1)'));
      expect(res3.exactResultLatex, equals('8'));
      verifyResolutionLatex('2^(2+1)', res3);
    });

    test('Precisión decimal de logaritmo: log_5(2) * 6 = 2,584062', () {
      final degEval = StepEvaluator(angleUnit: AngleUnit.deg);
      final res = degEval.evaluate(parser.parse('log(5,2)*6'));
      expect(res.decimalApproxLatex, equals('2,584062'));
      verifyResolutionLatex('log_5(2)*6', res);
    });
  });

  // ===========================================================================
  // MODO 2: ECUACIONES (Polinómicas, Bicuadradas, Irracionales, Exponenciales, Logarítmicas, Racionales)
  // ===========================================================================
  group('Fase 9D - Modo 2: Ecuaciones', () {
    test('Ecuación 1.º Grado desordenada con reducción', () {
      // 3x - 5 + 2x = 7 - x => 5x - 5 = 7 - x => 6x = 12 => x = 2
      final res = LinearEquationSolver.solveEquationString('3x - 5 + 2x = 7 - x');
      expect(res.exactResultLatex, equals('x = 2'));
      verifyResolutionLatex('Lineal desordenada', res);
    });

    test('Ecuación 2.º Grado: Δ > 0 (2 reales), Δ = 0 (doble) y Δ < 0 (sin sol. real)', () {
      // Δ > 0: x² - 5x + 6 = 0 => x = 2, 3
      final res2Roots = QuadraticEquationSolver.solve(a: 1, b: -5, c: 6);
      expect(res2Roots.exactResultLatex, contains('2'));
      expect(res2Roots.exactResultLatex, contains('3'));
      verifyResolutionLatex('Quad delta>0', res2Roots);

      // Δ = 0: x² - 4x + 4 = 0 => x = 2
      final resDouble = QuadraticEquationSolver.solve(a: 1, b: -4, c: 4);
      expect(resDouble.exactResultLatex, equals('x = 2'));
      verifyResolutionLatex('Quad delta=0', resDouble);

      // Δ < 0: x² + 4 = 0 => Sin solucion real
      final resNoReal = QuadraticEquationSolver.solve(a: 1, b: 0, c: 4);
      expect(resNoReal.exactResultLatex, contains('Sin solucion real'));
      verifyResolutionLatex('Quad delta<0', resNoReal);
    });

    test('Ecuación Bicuadrada: x^4 - 5x^2 + 4 = 0', () {
      final res = SuperEquationSolver.solve('x^4 - 5x^2 + 4 = 0');
      expect(res.exactResultLatex, contains('x = -2'));
      expect(res.exactResultLatex, contains('x = -1'));
      expect(res.exactResultLatex, contains('x = 1'));
      expect(res.exactResultLatex, contains('x = 2'));
      verifyResolutionLatex('Bicuadrada', res);
    });

    test('Ecuación Irracional aislando radical y descartando raíz extraña', () {
      // \sqrt{2x + 3} = x => 2x + 3 = x^2 => x = 3 (válida), x = -1 (extraña)
      final res = SuperEquationSolver.solve(r'\sqrt{2x + 3} = x');
      expect(res.exactResultLatex, equals('x = 3'));
      expect(res.steps.last.latexExpression, anyOf(contains('extraña'), contains('extrana')));
      verifyResolutionLatex('Irracional', res);
    });

    test('Ecuaciones Exponenciales: bases iguales, potencias negativas y bases distintas', () {
      // Bases iguales: 2^{x+1} = 8 => x = 2
      final resEqual = SuperEquationSolver.solve('2^{x+1} = 8');
      expect(resEqual.exactResultLatex, equals('x = 2'));
      verifyResolutionLatex('Exp bases iguales', resEqual);

      // Potencias negativas: 3^{2x-1} = 1/27 => x = -1
      final resNeg = SuperEquationSolver.solve('3^{2x-1} = 1/27');
      expect(resNeg.exactResultLatex, contains('-1'));
      verifyResolutionLatex('Exp potencia negativa', resNeg);

      // Bases distintas: 5^x = 7 => x = ln(7)/ln(5)
      final resDiff = SuperEquationSolver.solve('5^x = 7');
      expect(resDiff.exactResultLatex, contains(r'\frac{\ln(7)}{\ln(5)}'));
      verifyResolutionLatex('Exp bases distintas', resDiff);
    });

    test('Ecuaciones Logarítmicas: inyectividad y descarte de argumento <= 0', () {
      // Inyectividad: ln(2x - 1) = ln(x + 5) => x = 6
      final resIny = SuperEquationSolver.solve(r'\ln(2x - 1) = \ln(x + 5)');
      expect(resIny.exactResultLatex, contains('x = 6'));
      verifyResolutionLatex('Log inyectividad', resIny);

      // Argumento <= 0: log(x) + log(x - 3) = 1 => x = 5 (x = -2 descartada)
      final resDescarte = SuperEquationSolver.solve(r'\log(x) + \log(x - 3) = 1');
      expect(resDescarte.exactResultLatex, equals('x = 5'));
      expect(resDescarte.steps.last.latexExpression, contains('Descartada'));
      verifyResolutionLatex('Log descarte', resDescarte);
    });

    test('Ecuación Racional con descarte por valor prohibido', () {
      final res = SuperEquationSolver.solve(r'\frac{2x}{x-1} = 3');
      expect(res.exactResultLatex, contains('x = 3'));
      verifyResolutionLatex('Racional', res);
    });
  });

  // ===========================================================================
  // MODO 3: SISTEMAS DE ECUACIONES (2x2, 3x3 y 4x4)
  // ===========================================================================
  group('Fase 9D - Modo 3: Sistemas de Ecuaciones', () {
    test('Sistema 2x2 desordenado: reducción, sustitución e igualación', () {
      // 2x + y = 5
      // x - y = 1  => x = 2, y = 1
      for (final method in [
        SystemResolutionMethod.reduccion,
        SystemResolutionMethod.sustitucion,
        SystemResolutionMethod.igualacion,
      ]) {
        final res = LinearSystemSolver.solve(
          a1: 2, b1: 1, c1: 5,
          a2: 1, b2: -1, c2: 1,
          method: method,
        );
        expect(res.exactResultLatex, contains('x = 2'));
        expect(res.exactResultLatex, contains('y = 1'));
        verifyResolutionLatex('Sys2x2 $method', res);
      }
    });

    test('Detección exacta de Sistema Incompatible (S.I.) y Compatible Indeterminado (S.C.I.)', () {
      // Incompatible: x + y = 2, x + y = 5
      final resSI = LinearSystemSolver.solve(
        a1: 1, b1: 1, c1: 2,
        a2: 1, b2: 1, c2: 5,
        method: SystemResolutionMethod.reduccion,
      );
      expect(resSI.exactResultLatex, contains('S.I.'));
      verifyResolutionLatex('Sys2x2 S.I.', resSI);

      // Indeterminado: x + y = 2, 2x + 2y = 4
      final resSCI = LinearSystemSolver.solve(
        a1: 1, b1: 1, c1: 2,
        a2: 2, b2: 2, c2: 4,
        method: SystemResolutionMethod.reduccion,
      );
      expect(resSCI.exactResultLatex, contains('S.C.I.'));
      verifyResolutionLatex('Sys2x2 S.C.I.', resSCI);
    });

    test('Sistema 3x3 por Reducción escalonada', () {
      final rows3x3 = [
        [Rational(1), Rational(1), Rational(1), Rational(6)],
        [Rational(1), Rational(-1), Rational(1), Rational(2)],
        [Rational(2), Rational(1), Rational(-1), Rational(1)],
      ];
      final res3 = LinearSystemSolver.solveNxN(
        augmentedRows: rows3x3,
        method: SystemResolutionMethod.reduccion,
      );
      expect(res3.exactResultLatex, contains('x = 1'));
      expect(res3.exactResultLatex, contains('y = 2'));
      expect(res3.exactResultLatex, contains('z = 3'));
      verifyResolutionLatex('Sys 3x3', res3);
    });

    test('Sistema 4x4 con 4 incógnitas (x, y, z, w)', () {
      final rows4x4 = [
        [Rational(1), Rational(1), Rational(1), Rational(1), Rational(10)],
        [Rational(1), Rational(-1), Rational(1), Rational(-1), Rational(-2)],
        [Rational(2), Rational(1), Rational(-1), Rational(1), Rational(5)],
        [Rational(3), Rational(-2), Rational(2), Rational(1), Rational(9)],
      ];
      final res4 = LinearSystemSolver.solveNxN(
        augmentedRows: rows4x4,
        method: SystemResolutionMethod.reduccion,
      );
      expect(res4.exactResultLatex, contains('x = 1'));
      expect(res4.exactResultLatex, contains('y = 2'));
      expect(res4.exactResultLatex, contains('z = 3'));
      expect(res4.exactResultLatex, contains('w = 4'));
      verifyResolutionLatex('Sys 4x4', res4);
    });
  });

  // ===========================================================================
  // MODO 4: POLINOMIOS (Ruffini, Factorización e Identidades Notables)
  // ===========================================================================
  group('Fase 9D - Modo 4: Polinomios y Ruffini', () {
    test('Ruffini con polinomios completos e incompletos', () {
      // Completo: x³ - 3x² - 4x + 12 => raíces: -2, 2, 3
      final resComp = RuffiniSolver.factorize([1, -3, -4, 12]);
      expect(resComp.exactResultLatex, contains('(x - 2)'));
      expect(resComp.exactResultLatex, contains('(x + 2)'));
      expect(resComp.exactResultLatex, contains('(x - 3)'));
      verifyResolutionLatex('Ruffini completo', resComp);

      // Incompleto (grado 3 con término x² nulo): x³ - 4x = 0
      final resIncomp = RuffiniSolver.factorize([1, 0, -4, 0]);
      expect(resIncomp.exactResultLatex, contains('x'));
      verifyResolutionLatex('Ruffini incompleto', resIncomp);
    });

    test('Identidades Notables: (a+b)², (a-b)² y (a+b)(a-b)', () {
      final n1 = NotableIdentitiesSolver.solveExpressionString('(2x + 3)^2');
      expect(n1.exactResultLatex, contains('4x^2 + 12x + 9'));
      verifyResolutionLatex('(2x+3)^2', n1);

      final n2 = NotableIdentitiesSolver.solveExpressionString('(x - 4)^2');
      expect(n2.exactResultLatex, contains('x^2 - 8x + 16'));
      verifyResolutionLatex('(x-4)^2', n2);

      final n3 = NotableIdentitiesSolver.solveExpressionString('(3x + 1)(3x - 1)');
      expect(n3.exactResultLatex, contains('9x^2 - 1'));
      verifyResolutionLatex('Suma por diferencia', n3);
    });
  });

  // ===========================================================================
  // MODO 5: FUNCIONES (Gráficas, Vértices, Cortes y Tablas de Valores)
  // ===========================================================================
  group('Fase 9D - Modo 5: Funciones', () {
    test('Función Cuadrática: ramas, vértice, cortes y tabla de valores simétrica', () {
      // y = x² - 2x - 3 => Vértice: (1, -4), Cortes OX: (-1, 0), (3, 0), Corte OY: (0, -3)
      final resQuad = FunctionGraphSolver.analyzeQuadratic(a: 1, b: -2, c: -3);
      expect(resQuad.vertexX, equals(1.0));
      expect(resQuad.vertexY, equals(-4.0));
      expect(resQuad.samplePoints.length, greaterThanOrEqualTo(5));
      verifyResolutionLatex('Graph Parabola', resQuad.resolution);
    });

    test('Función Lineal: pendiente, ordenada, cortes y tabla', () {
      final resLin = FunctionGraphSolver.analyzeLinear(m: 2, n: -4);
      expect(resLin.resolution.originalInputLatex, contains('y = 2x - 4'));
      expect(resLin.resolution.exactResultLatex, contains('m = 2'));
      verifyResolutionLatex('Graph Recta', resLin.resolution);
    });
  });

  // ===========================================================================
  // MODO 6: INECUACIONES (1.º Grado, 2.º Grado, Valor Absoluto)
  // ===========================================================================
  group('Fase 9D - Modo 6: Inecuaciones', () {
    test('1.º Grado con cambio de sentido al dividir por coeficiente negativo', () {
      // -2x + 4 < 10 => -2x < 6 => x > -3 => S: (-3, +\infty)
      final res = InequalitySolver.solveString('-2x + 4 < 10');
      expect(res.exactResultLatex, contains('x > -3'));
      expect(res.exactResultLatex, contains('(-3,'));
      verifyResolutionLatex('Ineq 1D negativa', res);
    });

    test('2.º Grado con recta real y zonas SÍ/NO evaluadas', () {
      // x² - 4x + 3 <= 0 => (x-1)(x-3) <= 0 => S: [1, 3]
      final res = InequalitySolver.solveString('x^2 - 4x + 3 <= 0');
      expect(res.exactResultLatex, contains('[1, 3]'));
      verifyResolutionLatex('Ineq 2.º Grado', res);
    });

    test('Inecuación con Valor Absoluto: |x - 5| < 3 => 2 < x < 8', () {
      final res = InequalitySolver.solveString('|x - 5| < 3');
      expect(res.exactResultLatex, contains('(2, 8)'));
      verifyResolutionLatex('Ineq Valor Absoluto', res);
    });
  });

  // ===========================================================================
  // MODO 7: SISTEMAS DE INECUACIONES (1D en Recta Real y 2D en Plano Cartesiano)
  // ===========================================================================
  group('Fase 9D - Modo 7: Sistemas de Inecuaciones', () {
    test('Sistema 1D: intersección de rectas reales con zona en malla XXX', () {
      final res1D = InequalitySolver.solveSystem1D(['2x - 4 > 0', 'x + 1 <= 5']);
      expect(res1D.resolution.exactResultLatex, contains('(2, 4]'));
      verifyResolutionLatex('Ineq 1D System', res1D.resolution);
    });

    test('Sistema de Inecuaciones 2D: región factible y cálculo de vértices', () {
      final sys2d = LinearInequality2DSolver.solveSystem2D([
        'x + y <= 4',
        'x >= 0',
        'y >= 0',
      ]);
      expect(sys2d.visualData.vertices.length, equals(3));
      verifyResolutionLatex('Ineq 2D System', sys2d.resolution);
    });
  });

  // ===========================================================================
  // MODO 8: ESTADÍSTICA (1 y 2 Variables con Regresión y Varianza Cero)
  // ===========================================================================
  group('Fase 9D - Modo 8: Estadística', () {
    test('Estadística 1 Variable: media, mediana, varianza y cuartiles', () {
      final data = [
        StatDataPoint(Rational(2), 1),
        StatDataPoint(Rational(4), 2),
        StatDataPoint(Rational(6), 1),
      ];
      final res = StatisticsOneVarSolver.analyze(data);
      expect(res.mean, equals(Rational(4)));
      expect(res.variance, equals(Rational(2)));
      expect(res.median, equals(Rational(4)));
      verifyResolutionLatex('Stats 1 Var', res.resolution);
    });

    test('Estadística 2 Variables: recta de regresión y coeficiente de Pearson r', () {
      final points = [
        TwoVarPoint(Rational(1), Rational(2)),
        TwoVarPoint(Rational(2), Rational(4)),
        TwoVarPoint(Rational(3), Rational(6)),
      ];
      final res = StatisticsTwoVarSolver.analyze(points);
      expect(res.slopeM, equals(Rational(2)));
      expect(res.interceptN, equals(Rational(0)));
      expect(res.pearsonR, closeTo(1.0, 1e-4));
      verifyResolutionLatex('Stats 2 Var Regresion', res.resolution);
    });

    test('Estadística 2 Variables: manejo seguro de varianza cero (recta vertical)', () {
      final pointsConst = [
        TwoVarPoint(Rational(5), Rational(1)),
        TwoVarPoint(Rational(5), Rational(3)),
        TwoVarPoint(Rational(5), Rational(7)),
      ];
      final res = StatisticsTwoVarSolver.analyze(pointsConst);
      expect(res.varX.isZero, isTrue);
      expect(res.resolution.exactResultLatex, contains('x = 5'));
      verifyResolutionLatex('Stats 2 Var Varianza Cero', res.resolution);
    });
  });

  // ===========================================================================
  // MODO 9: MATRICES (Multiplicación, Det 3x3/4x4, Adjunta, Inversa, Det=0, Gauss, Cramer)
  // ===========================================================================
  group('Fase 9D - Modo 9: Matrices', () {
    test('Determinante 3x3 por Sarrus y 4x4 por Laplace', () {
      final m3 = RationalMatrix.fromInts([
        [1, 2, 3],
        [0, 1, 4],
        [5, 6, 0],
      ]);
      final res3 = MatrixSolver.determinant(m3);
      expect(res3.exactResultLatex, contains(r'\left|A\right| = 1'));
      verifyResolutionLatex('Det 3x3 Sarrus', res3);

      final m4 = RationalMatrix.fromInts([
        [2, 0, 0, 0],
        [0, 3, 0, 0],
        [0, 0, 4, 0],
        [0, 0, 0, 5],
      ]);
      final res4 = MatrixSolver.determinant(m4);
      expect(res4.exactResultLatex, contains('120'));
      verifyResolutionLatex('Det 4x4 Laplace', res4);
    });

    test('Multiplicación de matrices rectangulares A(2x3) y B(3x2)', () {
      final a = RationalMatrix.fromInts([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      final b = RationalMatrix.fromInts([
        [7, 8],
        [9, 1],
        [2, 3],
      ]);
      final res = MatrixSolver.multiply(a, b);
      expect(res.exactResultLatex, contains('31'));
      verifyResolutionLatex('MatMul 2x3 por 3x2', res);
    });

    test('Detección de matriz singular (det = 0) al intentar calcular la inversa', () {
      final singular = RationalMatrix.fromInts([
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9],
      ]);
      final res = MatrixSolver.inverse(singular);
      expect(res.exactResultLatex, contains(r'\nexists A^{-1}'));
      verifyResolutionLatex('Matriz singular', res);
    });

    test('Rango por Gauss y Regla de Cramer para sistema matricial A·X = B', () {
      final a = RationalMatrix.fromInts([
        [1, 2, 1],
        [2, 4, 2],
        [1, 1, 3],
      ]);
      final resGauss = MatrixSolver.gauss(a);
      expect(resGauss.exactResultLatex, contains(r'\text{rg}(A) = 2'));
      verifyResolutionLatex('Gauss rango', resGauss);

      final aCramer = RationalMatrix.fromInts([
        [1, 1, 1],
        [1, -1, 1],
        [2, 1, -1],
      ]);
      final bCramer = RationalMatrix.fromInts([
        [6],
        [2],
        [1],
      ]);
      final resCramer = MatrixSolver.cramer(aCramer, bCramer);
      expect(resCramer.exactResultLatex, contains('x = 1'));
      expect(resCramer.exactResultLatex, contains('y = 2'));
      expect(resCramer.exactResultLatex, contains('z = 3'));
      verifyResolutionLatex('Cramer matriz', resCramer);
    });
  });

  // ===========================================================================
  // MODO 10: VECTORES 3D (Módulo, Unitario, Escalar, Vectorial 3D, Ortogonalidad)
  // ===========================================================================
  group('Fase 9D - Modo 10: Vectores 3D', () {
    test('Módulo, vector unitario y producto escalar con comprobación de ortogonalidad', () {
      final u = RationalVector.fromInts([3, 4]);
      final resMod = VectorSolver.modulus(u);
      expect(resMod.exactResultLatex, contains('5'));
      verifyResolutionLatex('Vector modulus', resMod);

      final v1 = RationalVector.fromInts([1, 2, -1]);
      final v2 = RationalVector.fromInts([2, 0, 2]);
      final resDot = VectorSolver.dotProductAndAngle(v1, v2);
      expect(resDot.exactResultLatex, contains(r'\vec{u} \cdot \vec{v} = 0'));
      expect(resDot.steps.last.pedagogicalNote, contains('90'));
      verifyResolutionLatex('Vector ortogonal', resDot);
    });

    test('Producto vectorial 3D (u × v) y área del paralelogramo', () {
      final u = RationalVector.fromInts([1, 0, 0]);
      final v = RationalVector.fromInts([0, 1, 0]);
      final resCross = VectorSolver.crossProductAndArea(u, v);
      expect(resCross.exactResultLatex, contains('(0, 0, 1)'));
      verifyResolutionLatex('Vector cross product', resCross);
    });
  });

  // ===========================================================================
  // MODO 11: NÚMEROS COMPLEJOS (Aritmética, División por Conjugado, Potencias de i, Polar)
  // ===========================================================================
  group('Fase 9D - Modo 11: Números Complejos', () {
    test('División de números complejos multiplicando por el conjugado del denominador', () {
      final z1 = RationalComplex.fromInts(2, 1);
      final z2 = RationalComplex.fromInts(1, -1);
      final resDiv = ComplexSolver.divide(z1, z2);
      expect(resDiv.exactResultLatex, contains(r'\frac{1}{2}'));
      expect(resDiv.exactResultLatex, contains(r'\frac{3}{2}i'));
      verifyResolutionLatex('Complejos division', resDiv);
    });

    test('Potencias de la unidad imaginaria con reducción cíclica mod 4', () {
      final resI17 = ComplexSolver.powerOfI(17);
      expect(resI17.exactResultLatex, equals('i'));
      verifyResolutionLatex('i^17', resI17);

      final resI20 = ComplexSolver.powerOfI(20);
      expect(resI20.exactResultLatex, equals('1'));
      verifyResolutionLatex('i^20', resI20);

      final resI2 = ComplexSolver.powerOfI(2);
      expect(resI2.exactResultLatex, equals('-1'));

      final resI3 = ComplexSolver.powerOfI(3);
      expect(resI3.exactResultLatex, equals('-i'));
    });

    test('Conversión binómica a polar y trigonométrica', () {
      final z = RationalComplex.fromInts(1, 1);
      final resPolar = ComplexSolver.toPolar(z);
      expect(resPolar.exactResultLatex, contains(r'_{45^{\circ}}'));
      verifyResolutionLatex('Complejos polar', resPolar);
    });
  });

  // ===========================================================================
  // MODO 12: DERIVADAS E INTEGRALES (Cálculo Infinitesimal)
  // ===========================================================================
  group('Fase 9D - Modo 12: Derivadas e Integrales', () {
    test('Derivada simbólica término a término f\'(x)', () {
      final poly = RationalPolynomial.parseExpression('x^3 - 3x^2 + 2');
      final res = CalculusSolver.derivative(poly);
      expect(res.exactResultLatex, contains('3x^{2} - 6x'));
      verifyResolutionLatex('Derivada', res);
    });

    test('Integral Indefinida término a término con constante obligatoria + C', () {
      final poly = RationalPolynomial.parseExpression('3x^2 - 2x + 1');
      final res = CalculusSolver.indefiniteIntegral(poly);
      expect(res.exactResultLatex, contains('+ C'));
      expect(res.exactResultLatex, contains('x^{3} - x^{2} + x'));
      verifyResolutionLatex('Integral indefinida', res);
    });

    test('Integral Definida por Regla de Barrow [F(x)]_a^b = F(b) - F(a)', () {
      // \int_0^2 3x² dx = [x³]_0^2 = 8 - 0 = 8
      final poly = RationalPolynomial.parseExpression('3x^2');
      final res = CalculusSolver.definiteIntegralBarrow(poly, Rational(0), Rational(2));
      expect(res.exactResultLatex, contains('8'));
      verifyResolutionLatex('Integral Barrow', res);
    });
  });

  // ===========================================================================
  // UI & UX RESPONSIVA: Menú Completo (1 al 12 en 3 Páginas) y Sin Overflow
  // ===========================================================================
  group('Fase 9D - UI & UX Responsiva', () {
    Future<void> pumpCalculator(WidgetTester tester, Size size) async {
      await tester.binding.setSurfaceSize(size);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CalculatorScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Navegación completa del Menú (Modos 1 al 12 en 3 páginas)', (tester) async {
      await pumpCalculator(tester, const Size(400, 850));

      // Abrir menú
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();

      // Página 1: Modos 1 a 4
      expect(find.byKey(const Key('menu_mode_1')), findsOneWidget);
      expect(find.byKey(const Key('menu_mode_4')), findsOneWidget);

      // Siguiente página (Página 2: Modos 5 a 8)
      await tester.tap(find.byKey(const Key('menu_page_next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu_mode_5')), findsOneWidget);
      expect(find.byKey(const Key('menu_mode_7')), findsOneWidget);
      expect(find.byKey(const Key('menu_mode_8')), findsOneWidget);

      // Seleccionar Modo 7 (Sistemas de Inec.)
      await tester.tap(find.byKey(const Key('menu_mode_7')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Volver a MODE y avanzar a Página 3 (Modos 9 a 12)
      // Como el modo activo es el 7 (Página 2), el menú abre directamente en Página 2
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_page_next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu_mode_9')), findsOneWidget);
      expect(find.byKey(const Key('menu_mode_10')), findsOneWidget);
      expect(find.byKey(const Key('menu_mode_11')), findsOneWidget);
      expect(find.byKey(const Key('menu_mode_12')), findsOneWidget);

      // Seleccionar Modo 9 (Matrices)
      await tester.tap(find.byKey(const Key('menu_mode_9')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Volver a MODE (abre en Página 3 donde está el Modo 9 activo) y seleccionar Modo 12 (Derivadas e Integrales)
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu_mode_12')), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu_mode_12')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sin desbordamientos (RenderFlex overflow) en móvil vertical estrecho (360x800)', (tester) async {
      await pumpCalculator(tester, const Size(360, 800));
      expect(tester.takeException(), isNull);

      // Probar navegación a modo 2 y modo 8
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_mode_2')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_page_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_mode_8')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Layout apaisado / horizontal (Landscape 800x360) sin overflow', (tester) async {
      await pumpCalculator(tester, const Size(800, 360));
      expect(tester.takeException(), isNull);

      // Navegar a modo 1 y escribir
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_mode_1')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
