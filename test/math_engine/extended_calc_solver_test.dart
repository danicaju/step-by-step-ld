import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/exact/extended_calc_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/trig_and_angles_solver.dart';

String _exact(String e, {AngleUnit u = AngleUnit.deg}) =>
    ExtendedCalcSolver.solve(e, angle: u).exactResultLatex;

void main() {
  group('M1 extendido: exactos', () {
    final cases = {
      '6/√(3)': r'2\sqrt{3}',
      '√(12)+√(3)': r'3\sqrt{3}',
      '1/(√(2)-1)': r'1 + \sqrt{2}',
      '3/(2+√(3))': r'6 - 3\sqrt{3}',
      '(2+√(3))^2': r'7 + 4\sqrt{3}',
      '√(18)/√(2)': '3',
      '2^(1/2)': r'\sqrt{2}',
      '8^(2/3)': '4',
      '2^(-3)': r'\frac{1}{8}',
      '|-5|': '5',
      '|3-7|+|2-5|': '7',
      '5!': '120',
      '5nCr2': '10',
      '5nPr2': '20',
      '6!/(4!*2!)': '15',
      'log_2(8)': '3',
      'log_3(1/9)': '-2',
      'log(100)': '2',
      'ln(e)': '1',
      'e^2': r'e^{2}',
      '2π': r'2\pi',
      'sin(30)+cos(60)': '1',
      'acos(-0.5)': r'120^\circ',
      'sin(asin(0.5))': r'\frac{1}{2}',
      '(-8)^(1/3)': '-2',
    };
    cases.forEach((input, expected) {
      test(input, () => expect(_exact(input), expected));
    });
  });

  test('RAD y GRA en trigonometria', () {
    expect(_exact('cos(π/3)', u: AngleUnit.rad), r'\frac{1}{2}');
    expect(_exact('sin(π/2)', u: AngleUnit.rad), '1');
    expect(_exact('sin(50)', u: AngleUnit.grad), r'\frac{\sqrt{2}}{2}');
    expect(_exact('asin(1)', u: AngleUnit.rad), r'\frac{\pi}{2}');
  });

  test('errores matematicos', () {
    expect(() => ExtendedCalcSolver.solve('√(-4)'), throwsA(isA<ExMathError>()));
    expect(() => ExtendedCalcSolver.solve('1/0'), throwsA(isA<ExMathError>()));
    expect(() => ExtendedCalcSolver.solve('ln(0)'), throwsA(isA<ExMathError>()));
  });

  test('racionalizar muestra su paso y LaTeX sin tildes en text', () {
    final r = ExtendedCalcSolver.solve('6/√(3)');
    expect(r.steps.any((s) => s.shortTitle.contains('Racionalizar')), isTrue);
    for (final s in r.steps) {
      expect(RegExp(r'\text\{[^}]*[áéíóúñ¿¡]').hasMatch(s.latexExpression), isFalse);
      expect(s.latexExpression.contains('\r'), isFalse);
    }
  });

  test('needsExtended', () {
    expect(ExtendedCalcSolver.needsExtended('2+3'), isFalse);
    expect(ExtendedCalcSolver.needsExtended('√(8)'), isFalse);
    expect(ExtendedCalcSolver.needsExtended('6/√(3)'), isTrue);
    expect(ExtendedCalcSolver.needsExtended('|2-5|'), isTrue);
    expect(ExtendedCalcSolver.needsExtended('4^(1/2)'), isTrue);
  });
}
