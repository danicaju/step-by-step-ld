import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/symbolic/m1_symbolic_solver.dart';
import 'package:casio_tutor_calc/presentation/widgets/calculator_bezel_widgets.dart';

import 'support/e2e_helpers.dart';

Future<void> _alpha(WidgetTester t, String label) async {
  await tapF(t, find.text('ALPHA'));
  await key(t, label);
}

void main() {
  String? r(String raw, {Map<String, Rational> mem = const {}}) =>
      M1SymbolicSolver.solve(raw, memory: mem)?.exactResultLatex;

  group('M1SymbolicSolver (dominio)', () {
    test('2x+3x = 5x', () => expect(r('2x+3x'), '5x'));
    test('2x+3 conserva x', () => expect(r('2x+3'), '2x + 3'));
    test('(x+1)^2 se desarrolla', () => expect(r('(x+1)^2'), 'x^{2} + 2x + 1'));
    test('2x^2/x = 2x', () => expect(r('2x^2/x'), '2x'));
    test('(x^2-1)/(x-1) = x+1', () => expect(r('(x^2-1)/(x-1)'), 'x + 1'));
    test('y minuscula tambien es variable', () => expect(r('2y+3y'), '5y'));
    test('sin variables devuelve null', () => expect(M1SymbolicSolver.solve('2+3'), isNull));
    test('las memorias en mayuscula se sustituyen', () {
      expect(r('X+x', mem: {'X': Rational(4)}), 'x + 4');
    });
    test('x e y a la vez no se admite', () {
      expect(() => M1SymbolicSolver.solve('x+y'), throwsFormatException);
    });
    test('funciones no polinomicas se dejan indicadas', () {
      expect(r('sin(x)'), isNotNull);
    });
  });

  group('M1 en la calculadora', () {
    testWidgets('2x + 3x = da 5x (sin sustituir x por 0)', (t) async {
      await boot(t);
      await key(t, '2');
      await _alpha(t, ')');
      await key(t, '+');
      await key(t, '3');
      await _alpha(t, ')');
      await key(t, '=');
      expect(result(t), '5x');
    });

    testWidgets('2x + 3 conserva la x', (t) async {
      await boot(t);
      await key(t, '2');
      await _alpha(t, ')');
      await key(t, '+');
      await key(t, '3');
      await key(t, '=');
      expect(result(t), '2x + 3');
    });

    testWidgets('CALC con x pide x? y evalua', (t) async {
      await boot(t);
      await key(t, '2');
      await _alpha(t, ')');
      await key(t, '+');
      await key(t, '3');
      await tapF(
        t,
        find.byWidgetPredicate((w) => w is CompactControlKey && w.label == 'CALC'),
      );
      expect(find.text('x? '), findsOneWidget);
      await keys(t, ['4', '=']);
      expect(result(t), '11');
    });

    testWidgets('X mayuscula (memoria) no activa el modo algebraico', (t) async {
      await boot(t);
      await _alpha(t, '1'); // X
      await key(t, '+');
      await key(t, '3');
      await key(t, '=');
      expect(result(t), '3');
    });
  });
}
