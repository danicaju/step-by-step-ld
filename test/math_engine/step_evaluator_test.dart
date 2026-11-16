import 'package:casio_tutor_calc/domain/math_engine/ast/ast_nodes.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
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

  test('Operaciones con logaritmos decimales aproximados: log_5(2) * 6 no es 0 sino ~2.584062', () {
    const ast = BinaryOpNode(
      LogNode(base: IntNode(5), arg: IntNode(2)),
      BinaryOperator.multiply,
      IntNode(6),
    );

    final resolution = evaluator.evaluate(ast);

    expect(resolution.exactResultLatex, isNot(equals('0')));
    expect(resolution.exactResultLatex, contains('2,584'));
    expect(resolution.decimalApproxLatex, contains('2,584'));
    expect(resolution.steps.length, greaterThanOrEqualTo(2));
  });

  test('Operaciones con logaritmos exactos: log_2(8) * 6 = 18 exacto', () {
    const ast = BinaryOpNode(
      LogNode(base: IntNode(2), arg: IntNode(8)),
      BinaryOperator.multiply,
      IntNode(6),
    );

    final resolution = evaluator.evaluate(ast);

    expect(resolution.exactResultLatex, equals('18'));
    expect(resolution.decimalApproxLatex, equals('18'));
  });

  test('Parser + Evaluator: log_(5,2)*6 de la interfaz Casio produce ~2,584062 y nunca 0', () {
    final parser = ExpressionParser();
    final ast = parser.parse('log_(5,2)*6');
    final res = evaluator.evaluate(ast);

    expect(res.exactResultLatex, isNot(equals('0')));
    expect(res.exactResultLatex, contains('2,584'));
    expect(res.decimalApproxLatex, contains('2,584'));

    final astDiv = parser.parse('6/log_(5,2)');
    final resDiv = evaluator.evaluate(astDiv);
    expect(resDiv.exactResultLatex, contains('13,93'));

    final astMulComm = parser.parse('6*log_(5,2)');
    final resMulComm = evaluator.evaluate(astMulComm);
    expect(resMulComm.exactResultLatex, contains('2,584'));
  });
}
