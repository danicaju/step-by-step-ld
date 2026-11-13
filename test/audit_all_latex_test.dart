import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/step_evaluator.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/radical_and_factor_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_equation_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/quadratic_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/ruffini_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_system_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/notable_identities_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/function_graph_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/inequality_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/statistics_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/matrix_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/system_3x3_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/vector_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/complex_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/calculus_solver.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';

final List<String> allFailures = [];

void verifyLatex(String label, String rawLatex) {
  final sanitized = CasioLcdScreen.sanitizeForMathTex(rawLatex);
  try {
    final ast = SyntaxTree(
      greenRoot: TexParser(sanitized, const TexParserSettings()).parse(),
    );
    ast.buildWidget(MathOptions(
      style: MathStyle.display,
      fontSize: 20,
    ));
  } catch (e) {
    allFailures.add('LaTeX FAILED [$label]:\n  Raw: $rawLatex\n  Sanitized: $sanitized\n  Error: $e');
  }
}

void verifyResolution(String name, StepByStepResolution res) {
  verifyLatex('$name.originalInputLatex', res.originalInputLatex);
  verifyLatex('$name.exactResultLatex', res.exactResultLatex);
  if (res.decimalApproxLatex.isNotEmpty) {
    verifyLatex('$name.decimalApproxLatex', res.decimalApproxLatex);
  }
  for (int i = 0; i < res.steps.length; i++) {
    verifyLatex('$name.step[$i].latexExpression', res.steps[i].latexExpression);
  }
}

void main() {
  test('Audit ALL solvers and expressions for flutter_math_fork build exceptions (CrNode, etc.)', () {
    final parser = ExpressionParser();
    final evaluator = StepEvaluator();

    // 1. StepEvaluator expressions
    final rawExprs = [
      '',
      '0',
      '4/',
      '(x-2)/',
      '(x-2)/3',
      '3^',
      '3^(',
      '√(72',
      '³√(27',
      'mcm(',
      'mcm(12,',
      'mcm(12,18)',
      'mcd(',
      'mcd(12,',
      'mcd(12,18)',
      'ANS',
      'ANS + 5',
      '2 + 3 * 4',
      '-3^2',
      '(-3)^2',
      '4/6 + 2/3',
      '√(72)',
      '√(36)',
      '³√(27)',
      'root(4, 16)',
      '5 / 0',
    ];
    for (final expr in rawExprs) {
      verifyLatex('rawToLiveLatex($expr)', ExpressionParser.rawToLiveLatex(expr));
      for (int pos = 0; pos <= expr.length; pos++) {
        verifyLatex(
          'rawToLiveLatex($expr, cursorPos: $pos)',
          ExpressionParser.rawToLiveLatex(expr, cursorPos: pos),
        );
      }
      try {
        final ast = parser.parse(expr);
        final res = evaluator.evaluate(ast);
        verifyResolution('eval($expr)', res);
      } catch (_) {}
    }

    // 2. RadicalAndFactorSolver
    verifyResolution('factorize(360)', RadicalAndFactorSolver.factorize(360));
    verifyResolution('factorize(1)', RadicalAndFactorSolver.factorize(1));
    verifyResolution('factorize(17)', RadicalAndFactorSolver.factorize(17));

    // 3. LinearEquationSolver
    final linEqs = [
      '2x + 4 = 16',
      '3x - 5 = 7 - x',
      '(x-2)/3 - (x+1)/4 = 2',
      'x = x + 1',
      '2x + 4 = 2x + 4',
      '2x - 8',
    ];
    for (final eq in linEqs) {
      verifyResolution('linear($eq)', LinearEquationSolver.solveEquationString(eq));
    }

    // 4. QuadraticEquationSolver
    verifyResolution('quad(1,-5,6)', QuadraticEquationSolver.solve(a: 1, b: -5, c: 6));
    verifyResolution('quad(1,-4,4)', QuadraticEquationSolver.solve(a: 1, b: -4, c: 4));
    verifyResolution('quad(1,0,4)', QuadraticEquationSolver.solve(a: 1, b: 0, c: 4));
    verifyResolution('quad(2,0,-8)', QuadraticEquationSolver.solve(a: 2, b: 0, c: -8));
    verifyResolution('quad(3,-6,0)', QuadraticEquationSolver.solve(a: 3, b: -6, c: 0));
    verifyResolution('quad(1,-2,-1)', QuadraticEquationSolver.solve(a: 1, b: -2, c: -1));

    // 5. RuffiniSolver
    verifyResolution('ruffini([1,-3,-4,12])', RuffiniSolver.factorize([1, -3, -4, 12]));
    verifyResolution('ruffini([1,0,-4,0])', RuffiniSolver.factorize([1, 0, -4, 0]));
    verifyResolution('ruffini([1,0,1])', RuffiniSolver.factorize([1, 0, 1]));

    // 6. LinearSystemSolver
    for (final method in SystemResolutionMethod.values) {
      verifyResolution('sys($method, unique)', LinearSystemSolver.solve(a1: 2, b1: 1, c1: 5, a2: 1, b2: -1, c2: 1, method: method));
      verifyResolution('sys($method, incompatible)', LinearSystemSolver.solve(a1: 1, b1: 1, c1: 2, a2: 1, b2: 1, c2: 5, method: method));
      verifyResolution('sys($method, sci)', LinearSystemSolver.solve(a1: 1, b1: 1, c1: 2, a2: 2, b2: 2, c2: 4, method: method));
    }

    // 7. NotableIdentitiesSolver
    final notables = [
      '(2x + 3)^2',
      '(x - 4)^2',
      '(3x + 1)(3x - 1)',
    ];
    for (final n in notables) {
      verifyResolution('notable($n)', NotableIdentitiesSolver.solveExpressionString(n));
    }

    // 8. FunctionGraphSolver
    verifyResolution('graphQuad(1,-2,-3)', FunctionGraphSolver.analyzeQuadratic(a: 1, b: -2, c: -3).resolution);
    verifyResolution('graphQuad(-1,4,-4)', FunctionGraphSolver.analyzeQuadratic(a: -1, b: 4, c: -4).resolution);
    verifyResolution('graphQuad(1,0,2)', FunctionGraphSolver.analyzeQuadratic(a: 1, b: 0, c: 2).resolution);
    verifyResolution('graphLin(2,-4)', FunctionGraphSolver.analyzeLinear(m: 2, n: -4).resolution);
    verifyResolution('graphLin(0,5)', FunctionGraphSolver.analyzeLinear(m: 0, n: 5).resolution);

    // 9. InequalitySolver (Fase 7B)
    verifyResolution('ineqLin(-2x+4<10)', InequalitySolver.solveString('-2x + 4 < 10'));
    verifyResolution('ineqLin((x-2)/3-(x+1)/4<=2)', InequalitySolver.solveString('(x-2)/3 - (x+1)/4 <= 2'));
    verifyResolution('ineqQuad(1,-4,3<=0)', InequalitySolver.solveString('x^2 - 4x + 3 <= 0'));
    verifyResolution('ineqQuad(1,-4,3>0)', InequalitySolver.solveQuadratic(a: 1, b: -4, c: 3, sign: InequalitySign.greater));
    verifyResolution('ineqQuad(1,-4,4<=0)', InequalitySolver.solveQuadratic(a: 1, b: -4, c: 4, sign: InequalitySign.lessOrEqual));
    verifyResolution('ineqQuad(-1,0,-1<0)', InequalitySolver.solveQuadratic(a: -1, b: 0, c: -1, sign: InequalitySign.less));

    // 10. StatisticsOneVarSolver (Fase 7B)
    verifyResolution(
      'stats([2,4,6],[1,2,1])',
      StatisticsOneVarSolver.solve([
        StatDataPoint(Rational(2), 1),
        StatDataPoint(Rational(4), 2),
        StatDataPoint(Rational(6), 1),
      ]),
    );
    verifyResolution(
      'stats([1,2,3],[3,1,1])',
      StatisticsOneVarSolver.solve([
        StatDataPoint(Rational(1), 3),
        StatDataPoint(Rational(2), 1),
        StatDataPoint(Rational(3), 1),
      ]),
    );

    // 10. Fase 8A: MatrixSolver (2x2 y 3x3) y System3x3Solver (Gauss / Cramer)
    final m2a = RationalMatrix.fromInts([
      [3, 5],
      [2, 4],
    ]);
    final m2b = RationalMatrix.fromInts([
      [1, -2],
      [0, 3],
    ]);
    final m3a = RationalMatrix.fromInts([
      [2, 1, 0],
      [1, 2, 1],
      [0, 1, 2],
    ]);
    final m3b = RationalMatrix.fromInts([
      [1, 0, -1],
      [2, 3, 1],
      [-1, 1, 2],
    ]);
    final m3Singular = RationalMatrix.fromInts([
      [1, 2, 3],
      [4, 5, 6],
      [7, 8, 9],
    ]);
    verifyResolution('matrix_2x2_det', MatrixSolver.determinant(m2a));
    verifyResolution('matrix_2x2_inv', MatrixSolver.inverse(m2a));
    verifyResolution('matrix_2x2_mul', MatrixSolver.multiply(m2a, m2b));
    verifyResolution('matrix_3x3_sarrus', MatrixSolver.determinant(m3a));
    verifyResolution('matrix_3x3_adj', MatrixSolver.adjoint(m3a));
    verifyResolution('matrix_3x3_inv', MatrixSolver.inverse(m3a));
    verifyResolution('matrix_3x3_inv_singular', MatrixSolver.inverse(m3Singular));
    verifyResolution('matrix_3x3_add', MatrixSolver.add(m3a, m3b));
    verifyResolution('matrix_3x3_sub', MatrixSolver.subtract(m3a, m3b));
    verifyResolution('matrix_3x3_scalar', MatrixSolver.scalarMultiply(Rational(-3, 2), m3a));
    verifyResolution('matrix_3x3_mul', MatrixSolver.multiply(m3a, m3b));

    final scdRows = [
      [2, 4, 2, 3],
      [4, -4, 2, 10],
      [2, 8, -2, -10],
    ];
    final sciRows = [
      [1, 1, 1, 6],
      [2, 2, 2, 12],
      [1, 2, 3, 14],
    ];
    final siRows = [
      [1, 1, 1, 6],
      [2, 2, 2, 10],
      [1, -1, 1, 2],
    ];
    verifyResolution(
      'sys3_scd_gauss',
      System3x3Solver.solveFromInts(augmentedRows: scdRows, method: System3x3Method.gauss),
    );
    verifyResolution(
      'sys3_scd_cramer',
      System3x3Solver.solveFromInts(augmentedRows: scdRows, method: System3x3Method.cramer),
    );
    verifyResolution(
      'sys3_sci_gauss',
      System3x3Solver.solveFromInts(augmentedRows: sciRows, method: System3x3Method.gauss),
    );
    verifyResolution(
      'sys3_sci_cramer',
      System3x3Solver.solveFromInts(augmentedRows: sciRows, method: System3x3Method.cramer),
    );
    verifyResolution(
      'sys3_si_gauss',
      System3x3Solver.solveFromInts(augmentedRows: siRows, method: System3x3Method.gauss),
    );
    verifyResolution(
      'sys3_si_cramer',
      System3x3Solver.solveFromInts(augmentedRows: siRows, method: System3x3Method.cramer),
    );

    // Fase 8B: Vectores 2D/3D, Complejos y Cálculo
    final vecU = RationalVector.d3(Rational(1), Rational(2), Rational(3));
    final vecV = RationalVector.d3(Rational(4), Rational(5), Rational(6));
    verifyResolution('vec_mod_sqrt18', VectorSolver.modulus(RationalVector.fromInts([3, 3])));
    verifyResolution('vec_mod_zero', VectorSolver.modulus(RationalVector.fromInts([0, 0, 0])));
    verifyResolution('vec_dot_ortho', VectorSolver.dotProductAndAngle(RationalVector.fromInts([1, 2, -1]), RationalVector.fromInts([2, 0, 2])));
    verifyResolution('vec_dot_angle', VectorSolver.dotProductAndAngle(vecU, vecV));
    verifyResolution('vec_cross_3d', VectorSolver.crossProductAndArea(vecU, vecV));
    verifyResolution('vec_add', VectorSolver.add(vecU, vecV));
    verifyResolution('vec_sub', VectorSolver.subtract(vecU, vecV));

    final c1 = RationalComplex.fromInts(2, 1);
    final c2 = RationalComplex.fromInts(1, -1);
    verifyResolution('cplx_add', ComplexSolver.add(c1, c2));
    verifyResolution('cplx_sub', ComplexSolver.subtract(c1, c2));
    verifyResolution('cplx_mul', ComplexSolver.multiply(RationalComplex.fromInts(3, 2), RationalComplex.fromInts(1, -4)));
    verifyResolution('cplx_div', ComplexSolver.divide(c1, c2));
    verifyResolution('cplx_div_imag', ComplexSolver.divide(RationalComplex.fromInts(0, 3), RationalComplex.fromInts(1, 2)));
    verifyResolution('cplx_polar_q1', ComplexSolver.toPolar(RationalComplex.fromInts(1, 1)));
    verifyResolution('cplx_polar_q2', ComplexSolver.toPolar(RationalComplex.fromInts(-3, 3)));
    verifyResolution('cplx_polar_q3', ComplexSolver.toPolar(RationalComplex.fromInts(-1, -1)));
    verifyResolution('cplx_polar_q4', ComplexSolver.toPolar(RationalComplex.fromInts(0, -5)));
    verifyResolution('cplx_from_polar', ComplexSolver.fromPolar(modulus: Rational(2), angleDegrees: 60));

    verifyResolution('calc_deriv', CalculusSolver.derivative(RationalPolynomial.parseExpression('x^3 - 3x^2 + 2')));
    verifyResolution('calc_deriv_const', CalculusSolver.derivative(RationalPolynomial.parseExpression('7')));
    verifyResolution('calc_tangent', CalculusSolver.tangentLine(RationalPolynomial.parseExpression('x^2 - 4x + 5'), Rational(3)));
    verifyResolution('calc_int_indef', CalculusSolver.indefiniteIntegral(RationalPolynomial.parseExpression('3x^2 - 2x + 1')));
    verifyResolution('calc_int_barrow', CalculusSolver.definiteIntegralBarrow(RationalPolynomial.parseExpression('3x^2'), Rational(0), Rational(2)));

    if (allFailures.isNotEmpty) {
      fail('${allFailures.length} LaTeX expressions failed:\n${allFailures.join("\n\n")}');
    }
  });
}
