import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/exact/extended_calc_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/step_evaluator.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_error_text.dart';

void main() {
  const neg = '√((16)/(9))-√((20)/(9))*√((-16)/(9))';
  const pos = '√((16)/(9))-√((20)/(9))*√((16)/(9))';

  test('motor exacto: raiz par de fraccion negativa lanza ExMathError con mensaje claro', () {
    expect(
      () => ExtendedCalcSolver.solve(neg),
      throwsA(isA<ExMathError>().having((e) => e.message, 'message', contains('Raíz de índice par'))),
    );
  });

  test('motor clasico: raiz par de negativo y division por cero lanzan ExMathError', () {
    for (final raw in ['√(-16)', '√(-16/9)', '2÷(1-1)', '1÷(3-3)']) {
      expect(
        () => StepEvaluator().evaluate(ExpressionParser().parse(raw)),
        throwsA(isA<ExMathError>()),
        reason: raw,
      );
    }
  });

  test('raices de fracciones positivas dan resultado exacto', () {
    final r = ExtendedCalcSolver.solve(pos);
    expect(r.exactResultLatex, r'\frac{4}{3} - \frac{8\sqrt{5}}{9}');
    expect(r.steps, isNotEmpty);
  });

  test('el mensaje de error nunca muestra texto crudo de Dart', () {
    for (final raw in [
      'Error al evaluar: Invalid argument(s): No se puede dividir entre una fracción nula.',
      'Error al resolver: Exception: algo',
      'Error en Estadística: FormatException: algo',
    ]) {
      final c = LcdErrorText.clean(raw);
      expect(c, isNot(contains('Invalid argument')));
      expect(c, isNot(contains('Exception')));
      expect(c, isNot(contains('Error al')));
    }
    final i = LcdErrorText.info('Math ERROR: Raíz de índice par de un número negativo (no existe en ℝ).', syntax: false);
    expect(i.hint, contains('Modo Complejos (M11)'));
  });
}
