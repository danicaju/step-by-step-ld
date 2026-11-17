import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/polynomial_equation_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/trig_and_angles_solver.dart';

String _x(String eq, {AngleUnit u = AngleUnit.deg}) =>
    PolynomialEquationSolver.solveEquationString(eq, angle: u).exactResultLatex;

void main() {
  group('M2 racionales', () {
    test('descarta raiz prohibida', () {
      expect(_x('(x^2-1)/(x-1)=2'), contains('Sin solucion real'));
      expect(_x('1/(x-1)=2/(x^2-1)'), contains('Sin solucion real'));
    });
    test('resuelve y valida', () {
      expect(_x('(x+1)/(x-1)=2'), 'x = 3');
      expect(_x('1/x+1/(x-1)=3/2'), r'x = \frac{1}{3}, \quad x = 2');
    });
    test('dominio en el primer paso', () {
      final r = PolynomialEquationSolver.solveEquationString('(x+1)/(x-1)=2');
      expect(r.steps.first.shortTitle, contains('valores prohibidos'));
      expect(r.steps.any((s) => s.shortTitle.contains('m.c.m.')), isTrue);
    });
  });

  group('M2 irracionales', () {
    test('una raiz con comprobacion', () {
      expect(_x('sqrt(x+3)=x-3'), 'x = 6');
      expect(_x(r'\sqrt{2x+3}=x'), 'x = 3');
      expect(_x('sqrt(x)=-3'), contains('Sin solucion real'));
    });
    test('dos radicales', () {
      expect(_x('sqrt(2x+1)=sqrt(x+4)'), 'x = 3');
      expect(_x('sqrt(x)+sqrt(x+5)=5'), 'x = 4');
    });
  });

  group('M2 exponenciales', () {
    test('igualar bases y cambio de variable', () {
      expect(_x('2^(2x-1)=32'), 'x = 3');
      expect(_x('3^(x+1)+3^x=36'), 'x = 2');
      expect(_x('4^x-5*2^x+4=0'), r'x = 0, \quad x = 2');
    });
    test('logaritmos', () {
      expect(_x('5^x=12'), contains(r'\frac{\ln(12)}{\ln(5)}'));
    });
  });

  group('M2 logaritmicas', () {
    test('propiedades y descarte', () {
      expect(_x('log(x)+log(x-3)=1'), 'x = 5');
      expect(_x('log_2(x)+log_2(x-2)=3'), 'x = 4');
      expect(_x('ln(x)=2'), r'x = e^{2}');
      final r = PolynomialEquationSolver.solveEquationString('log(x)+log(x-3)=1');
      expect(r.steps.last.latexExpression, contains('Descartada'));
    });
  });

  group('M2 trigonometricas', () {
    test('DEG', () {
      expect(_x('sin(x)=1/2'), contains(r'30^\circ'));
      expect(_x('sin(x)=1/2'), contains(r'150^\circ'));
      expect(_x('cos(x)=0.5'), contains(r'60^\circ'));
      expect(_x('sin(x)=2'), contains('Sin solucion real'));
    });
    test('RAD', () {
      final r = _x('sin(x)=1/2', u: AngleUnit.rad);
      expect(r, contains(r'\frac{\pi}{6}'));
      expect(r, contains(r'\frac{5\pi}{6}'));
    });
  });

  test('Regla de oro: sin tildes en \text de los pasos', () {
    for (final e in ['sqrt(x+3)=x-3', '(x+1)/(x-1)=2', '3^(x+1)+3^x=36', 'log(x)+log(x-3)=1', 'sin(x)=1/2']) {
      final r = PolynomialEquationSolver.solveEquationString(e);
      for (final s in r.steps) {
        for (final m in RegExp(r'\\text\{([^}]+)\}').allMatches(s.latexExpression)) {
          expect(RegExp(r'[áéíóúñ¿¡]').hasMatch(m.group(1)!), isFalse);
        }
      }
    }
  });
}
