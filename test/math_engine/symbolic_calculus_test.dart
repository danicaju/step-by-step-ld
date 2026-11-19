import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/calculus_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/exact/extended_calc_solver.dart';

String _d(String f) => CalculusSolver.solve(
      operation: CalculusOperation.derivative,
      expressionRaw: f,
    ).exactResultLatex;

String _i(String f) => CalculusSolver.solve(
      operation: CalculusOperation.indefiniteIntegral,
      expressionRaw: f,
    ).exactResultLatex;

void main() {
  group('M12 derivadas simbolicas', () {
    final cases = {
      'sin(x)': r"f'(x) = \cos\left(x\right)",
      'sqrt(x)': r"f'(x) = \frac{1}{2\sqrt{x}}",
      '1/x': r"f'(x) = -\frac{1}{x^{2}}",
      '1/x^3': r"f'(x) = -\frac{3}{x^{4}}",
      'x*e^x': r"f'(x) = \left(x + 1\right)e^{x}",
      'sin(x)/x': r"f'(x) = \frac{x\cos\left(x\right) - \sin\left(x\right)}{x^{2}}",
      'sin(3x^2)': r"f'(x) = 6x\cos\left(3x^{2}\right)",
      'e^(2x)': r"f'(x) = 2e^{2x}",
      'ln(x^2+1)': r"f'(x) = \frac{2x}{x^{2} + 1}",
      'atan(x)': r"f'(x) = \frac{1}{1 + x^{2}}",
      'tan(x)': r"f'(x) = \frac{1}{\cos^{2}\left(x\right)}",
      '2^x': r"f'(x) = 2^{x}\ln\left(2\right)",
    };
    cases.forEach((f, expected) => test(f, () => expect(_d(f), expected)));

    test('regla del producto, cociente y cadena aparecen en los pasos', () {
      final prod = CalculusSolver.solve(
        operation: CalculusOperation.derivative,
        expressionRaw: 'x*sin(x)',
      );
      expect(prod.steps.any((s) => s.shortTitle.contains('producto')), isTrue);
      final quo = CalculusSolver.solve(
        operation: CalculusOperation.derivative,
        expressionRaw: 'sin(x)/x',
      );
      expect(quo.steps.any((s) => s.shortTitle.contains('cociente')), isTrue);
      final chain = CalculusSolver.solve(
        operation: CalculusOperation.derivative,
        expressionRaw: 'sin(3x^2)',
      );
      expect(chain.steps.any((s) => s.shortTitle.contains('cadena')), isTrue);
    });

    test('recta tangente no polinomica', () {
      final r = CalculusSolver.solve(
        operation: CalculusOperation.tangentLine,
        expressionRaw: 'x^2*e^x',
        tangentX0: Rational(1),
      );
      expect(r.exactResultLatex, r'y = 3ex - 2e');
      final l = CalculusSolver.solve(
        operation: CalculusOperation.tangentLine,
        expressionRaw: 'ln(x)',
        tangentX0: Rational(1),
      );
      expect(l.exactResultLatex, 'y = x - 1');
    });
  });

  group('M12 integrales simbolicas', () {
    final cases = {
      'sin(x)': r'-\cos\left(x\right) + C',
      'cos(2x)': r'\frac{\sin\left(2x\right)}{2} + C',
      '1/x': r'\ln\left|x\right| + C',
      '1/sqrt(x)': r'2\sqrt{x} + C',
      '1/x^2': r'-\frac{1}{x} + C',
      '1/(1+x^2)': r'\arctan\left(x\right) + C',
      'e^(3x)': r'\frac{e^{3x}}{3} + C',
      'x*e^x': r'xe^{x} - e^{x} + C',
      'x*sin(x)': r'-x\cos\left(x\right) + \sin\left(x\right) + C',
      'ln(x)': r'x\ln\left(x\right) - x + C',
      '2x*e^(x^2)': r'e^{x^{2}} + C',
      '2x/(x^2+1)': r'\ln\left|x^{2} + 1\right| + C',
      'cos(x)*sin(x)': r'-\frac{\cos^{2}\left(x\right)}{2} + C',
      '(2x+3)(x^2+3x)^5': r'\frac{\left(x^{2} + 3x\right)^{6}}{6} + C',
      'tan(x)': r'-\ln\left|\cos\left(x\right)\right| + C',
      'x^2*e^x': r'x^{2}e^{x} - 2xe^{x} + 2e^{x} + C',
      '1/cos(x)^2': r'\tan\left(x\right) + C',
    };
    cases.forEach((f, expected) => test(f, () => expect(_i(f), expected)));

    test('metodo de partes y sustitucion se explican', () {
      final p = CalculusSolver.solve(
        operation: CalculusOperation.indefiniteIntegral,
        expressionRaw: 'x*e^x',
      );
      expect(p.steps.any((s) => s.shortTitle.contains('partes')), isTrue);
      final s = CalculusSolver.solve(
        operation: CalculusOperation.indefiniteIntegral,
        expressionRaw: '2x*e^(x^2)',
      );
      expect(s.steps.any((e) => e.shortTitle.contains('Cambio de variable')), isTrue);
    });

    test('Regla de Barrow con F(b) - F(a)', () {
      final r = CalculusSolver.solve(
        operation: CalculusOperation.definiteIntegral,
        expressionRaw: 'x*e^x',
        integralLowerA: Rational(1),
        integralUpperB: Rational(2),
      );
      expect(r.exactResultLatex, r'e^{2}');
      expect(r.steps.any((s) => s.shortTitle.contains('Barrow')), isTrue);
      final l = CalculusSolver.solve(
        operation: CalculusOperation.definiteIntegral,
        expressionRaw: 'ln(x)',
        integralLowerA: Rational(1),
        integralUpperB: Rational(2),
      );
      expect(l.exactResultLatex, r'2\ln\left(2\right) - 1');
    });

    test('integral impropia en [-1, 1] de 1/x lanza error', () {
      expect(
        () => CalculusSolver.solve(
          operation: CalculusOperation.definiteIntegral,
          expressionRaw: '1/x',
          integralLowerA: Rational(-1),
          integralUpperB: Rational(1),
        ),
        throwsA(isA<ExMathError>()),
      );
    });

    test('Regla de oro: sin tildes en text de los pasos', () {
      for (final f in ['x*e^x', '2x/(x^2+1)', 'sin(x)/x']) {
        for (final op in CalculusOperation.values) {
          StepByStepResolution r;
          try {
            r = CalculusSolver.solve(
              operation: op,
              expressionRaw: f,
              tangentX0: Rational(1),
              integralLowerA: Rational(1),
              integralUpperB: Rational(2),
            );
          } on ExtUnsupported {
            continue; // sin primitiva elemental (p. ej. sin(x)/x)
          }
          for (final s in r.steps) {
            for (final m in RegExp(r'\text\{([^}]+)\}').allMatches(s.latexExpression)) {
              expect(RegExp(r'[áéíóúñ¿¡]').hasMatch(m.group(1)!), isFalse);
            }
            expect(s.latexExpression.contains('\r'), isFalse);
          }
        }
      }
    });
  });
}
