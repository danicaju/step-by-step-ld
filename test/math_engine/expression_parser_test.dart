import 'package:casio_tutor_calc/domain/math_engine/ast/ast_nodes.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/step_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ExpressionParser parser;
  late StepEvaluator evaluator;

  setUp(() {
    parser = ExpressionParser();
    evaluator = StepEvaluator();
  });

  group('ExpressionParser AST Parsing', () {
    test('Parsea -3^2 con prioridad de potencia sobre signo menos', () {
      final ast = parser.parse('-3^2');
      expect(ast, isA<UnaryMinusNode>());
      final unary = ast as UnaryMinusNode;
      expect(unary.operand, isA<PowerNode>());
      final power = unary.operand as PowerNode;
      expect((power.base as IntNode).value, 3);
      expect(power.exponent, 2);

      final resolution = evaluator.evaluate(ast);
      expect(resolution.exactResultLatex, '-9');
      expect(resolution.steps.first.warningTrick, isNotNull);
    });

    test('Parsea (-3)^2 agrupando el signo negativo dentro de la base', () {
      final ast = parser.parse('(-3)^2');
      expect(ast, isA<PowerNode>());
      final power = ast as PowerNode;
      expect(power.base, isA<UnaryMinusNode>());
      expect((power.base as UnaryMinusNode).hasExplicitParentheses, isTrue);
      expect(power.exponent, 2);

      final resolution = evaluator.evaluate(ast);
      expect(resolution.exactResultLatex, '9');
    });

    test('Parsea fracciones y sumas combinadas: -3^2+4/6+5/4', () {
      final ast = parser.parse('-3^2+4/6+5/4');
      final resolution = evaluator.evaluate(ast);

      expect(resolution.exactResultLatex, r'-\frac{85}{12}');
      expect(resolution.decimalApproxLatex, '-7,083333');
    });

    test('Parsea multiplicación y división de izquierda a derecha', () {
      final ast = parser.parse('12:3*2');
      expect(ast, isA<BinaryOpNode>());
      final root = ast as BinaryOpNode;
      expect(root.op, BinaryOperator.multiply);
      expect(root.left, isA<BinaryOpNode>());
      expect((root.left as BinaryOpNode).op, BinaryOperator.divide);

      final resolution = evaluator.evaluate(ast);
      expect(resolution.exactResultLatex, '8');
    });

    test('Evaluación decimal de log_(5, 2) * 6 no trunca a 0 y aproxima con decimales', () {
      final ast = parser.parse('log_(5, 2) * 6');
      final resolution = evaluator.evaluate(ast);
      expect(resolution.exactResultLatex, contains('2,584062'));
      expect(resolution.exactResultLatex, isNot(equals('0')));
      expect(resolution.steps.last.latexExpression, contains(r'\approx'));
    });
  });

  group('rawToLiveLatex', () {
    test('Formatea fracciones completas e incompletas', () {
      expect(ExpressionParser.rawToLiveLatex('4/6'), r'\frac{4}{6}');
      expect(ExpressionParser.rawToLiveLatex('4/'), r'\frac{4}{\square}');
    });

    test('Formatea potencias completas e incompletas sin hueco extra', () {
      expect(ExpressionParser.rawToLiveLatex('3^2'), '3^{2}');
      expect(ExpressionParser.rawToLiveLatex('3^'), r'3^{\square}');
      expect(ExpressionParser.rawToLiveLatex('5^(3'), '5^{3}');
      expect(ExpressionParser.rawToLiveLatex('5^('), r'5^{\square}');
    });

    test('Parentesis de usuario normal no se autocierran al pulsar flecha derecha', () {
      // (2x + 1 no tiene prefijo estructurado de función ni potencia: no debe autocerrar
      final result = ExpressionParser.handleStructuredBlockRightArrow('(2x + 1', 7);
      expect(result, isNull);
    });

    test('handleFractionRightArrow permite salir de la fracción añadiendo espacio', () {
      final result = ExpressionParser.handleFractionRightArrow('1/2', 3);
      expect(result, isNotNull);
      expect(result!.$1, '1/2 ');
      expect(result.$2, 4);
    });

    test('handlePowerRightArrow permite salir de la potencia o cerrar exponente con flecha derecha', () {
      // Exponente simple 5^3 -> añade espacio para salir a línea base
      final resSimple = ExpressionParser.handlePowerRightArrow('5^3', 3);
      expect(resSimple, isNotNull);
      expect(resSimple!.$1, '5^3 ');
      expect(resSimple.$2, 4);

      // Exponente con paréntesis abierto no cerrado 5^(3 -> cierra con )
      final resParen = ExpressionParser.handlePowerRightArrow('5^(3', 4);
      expect(resParen, isNotNull);
      expect(resParen!.$1, '5^(3)');
      expect(resParen.$2, 5);
    });

    test('Llamadas a funciones sin cerrar no inyectan prematuramente parentesis de cierre', () {
      final liveSin = ExpressionParser.rawToLiveLatex('sin(30');
      expect(liveSin, contains(r'\sin(30'));
      expect(liveSin, isNot(contains(r'\right)')));
    });
  });
}
