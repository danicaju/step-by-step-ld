import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/calculus_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/exact/extended_calc_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/polynomial_equation_solver.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';

void _render(String label, String latex) {
  final sanitized = CasioLcdScreen.sanitizeForMathTex(latex);
  expect(
    RegExp(r'[áéíóúÁÉÍÓÚñÑ¿¡]').hasMatch(
      RegExp(r'\\(?:text|mathrm)\{([^}]+)\}')
          .allMatches(sanitized)
          .map((m) => m.group(1)!)
          .join(),
    ),
    isFalse,
    reason: 'tildes en \text [$label]',
  );
  expect(latex.contains('\r'), isFalse, reason: 'CR en [$label]');
  try {
    final ast = SyntaxTree(
      greenRoot: TexParser(sanitized, const TexParserSettings()).parse(),
    );
    ast.buildWidget(MathOptions(style: MathStyle.display, fontSize: 18));
  } catch (e) {
    fail('LaTeX invalido en [$label]: $latex\n$e');
  }
}

void _all(String label, StepByStepResolution r) {
  _render('$label.original', r.originalInputLatex);
  _render('$label.exact', r.exactResultLatex);
  if (r.decimalApproxLatex.isNotEmpty) _render('$label.decimal', r.decimalApproxLatex);
  for (var i = 0; i < r.steps.length; i++) {
    _render('$label.step$i', r.steps[i].latexExpression);
  }
}

void main() {
  test('M1 extendido renderiza en flutter_math_fork', () {
    for (final e in [
      '6/√(3)', '|3-7|+|2-5|', '5!', '5nCr2', '5nPr2', 'log_2(8)', 'ln(e)', 'asin(0.5)',
      '2^(1/2)', '8^(2/3)', '(2+√(3))^2', '1/(√(2)-1)', 'e^2', '2π', 'sin(30)+cos(60)', '2^(1/3)',
    ]) {
      _all('M1 $e', ExtendedCalcSolver.solve(e));
    }
  });

  test('M2 solvers renderizan en flutter_math_fork', () {
    for (final e in [
      '(x+1)/(x-1)=2', '1/x+1/(x-1)=3/2', '(x^2-1)/(x-1)=2', 'sqrt(x+3)=x-3', 'sqrt(x)+sqrt(x+5)=5',
      'sqrt(x)=-3', '2^(2x-1)=32', '3^(x+1)+3^x=36', '5^x=12', 'e^x=5', 'log(x)+log(x-3)=1', 'ln(x)=2',
      'log_2(x)+log_2(x-2)=3', 'sin(x)=1/2', 'cos(x)=0.5', 'tan(x)=1', 'sin(x)=2', '2sin(x)^2-sin(x)-1=0',
    ]) {
      _all('M2 $e', PolynomialEquationSolver.solveEquationString(e));
    }
  });

  test('M12 simbolico renderiza en flutter_math_fork', () {
    for (final f in [
      'sin(3x^2)', 'x*e^x', 'sin(x)/x', 'ln(x^2+1)', '1/x^3', 'atan(x)', 'sqrt(x)', 'x^x',
    ]) {
      _all('D $f', CalculusSolver.solve(operation: CalculusOperation.derivative, expressionRaw: f));
      _all(
        'T $f',
        CalculusSolver.solve(
          operation: CalculusOperation.tangentLine,
          expressionRaw: f,
          tangentX0: Rational(1),
        ),
      );
    }
    for (final f in [
      'x*e^x', 'x*sin(x)', 'ln(x)', '2x*e^(x^2)', '2x/(x^2+1)', 'cos(x)*sin(x)', 'tan(x)',
      'x*ln(x)', 'atan(x)', 'e^x*sin(x)', '1/(x*ln(x))', '(2x+3)(x^2+3x)^5', 'sin(x)^2', '1/x',
    ]) {
      _all('I $f', CalculusSolver.solve(operation: CalculusOperation.indefiniteIntegral, expressionRaw: f));
      try {
        _all(
          'B $f',
          CalculusSolver.solve(
            operation: CalculusOperation.definiteIntegral,
            expressionRaw: f,
            integralLowerA: Rational(1),
            integralUpperB: Rational(2),
          ),
        );
      } on ExMathError {
        // integral impropia en el intervalo (p. ej. 1/(x ln x) en x = 1)
      }
    }
  });
}
