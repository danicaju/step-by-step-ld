import 'package:casio_tutor_calc/domain/math_engine/ast/ast_nodes.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/step_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StepEvaluator evaluator;

  setUp(() {
    evaluator = StepEvaluator();
  });

  test('Distingue entre -3^2 (-9) y (-3)^2 (+9) generando alerta pedagógica', () {
    // Caso 1: -3^2
    const trapAst = UnaryMinusNode(PowerNode(IntNode(3), 2));
    final trapRes = evaluator.evaluate(trapAst);

    expect(trapRes.exactResultLatex, '-9');
    expect(trapRes.steps.first.warningTrick, isNotNull);
    expect(trapRes.steps.first.warningTrick, contains('no hay paréntesis'));

    // Caso 2: (-3)^2
    const parenAst = PowerNode(
      UnaryMinusNode(IntNode(3), hasExplicitParentheses: true),
      2,
    );
    final parenRes = evaluator.evaluate(parenAst);

    expect(parenRes.exactResultLatex, '9');
    expect(parenRes.steps.first.pedagogicalNote.toLowerCase(), contains('positivo'));
  });

  test('Resuelve -3^2 + 4/6 + 5/4 paso a paso con m.c.m. y simplificación', () {
    // Árbol: (-3^2) + (4/6 + 5/4)
    const ast = BinaryOpNode(
      UnaryMinusNode(PowerNode(IntNode(3), 2)),
      BinaryOperator.add,
      BinaryOpNode(
        FractionNode(4, 6),
        BinaryOperator.add,
        FractionNode(5, 4),
      ),
    );

    final resolution = evaluator.evaluate(ast);

    // -9 + 2/3 + 5/4 = -9 + 23/12 = -85/12
    expect(resolution.exactResultLatex, r'-\frac{85}{12}');
    expect(resolution.decimalApproxLatex, '-7,083333');

    // Imprime todos los pasos en consola para inspeccionar el LaTeX generado
    for (final step in resolution.steps) {
      // ignore: avoid_print
      print(step);
    }
  });
}
