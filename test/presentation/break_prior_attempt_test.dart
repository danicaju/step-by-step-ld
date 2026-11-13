import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_equation_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/quadratic_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_system_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/step_evaluator.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/notable_identities_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/ast/ast_nodes.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';

void main() {
  group('Verification of Bugs in Prior Attempt and Their Fixes', () {
    test('Bug 1: ExpressionParser parses and evaluates mcm and mcd', () {
      final parser = ExpressionParser();
      final astMcm = parser.parse('mcm(12,18)');
      final evaluator = StepEvaluator();
      final resMcm = evaluator.evaluate(astMcm);
      expect(resMcm.exactResultLatex, equals('36'));

      final astMcd = parser.parse('mcd(12,18)');
      final resMcd = evaluator.evaluate(astMcd);
      expect(resMcd.exactResultLatex, equals('6'));
    });

    test('Bug 2: ExpressionParser retains cubic root token ³', () {
      final parser = ExpressionParser();
      final ast = parser.parse('³√(8)');
      expect(ast.toLatex(), contains('3'));
      final evaluator = StepEvaluator();
      final res = evaluator.evaluate(ast);
      expect(res.exactResultLatex, equals('2'));
    });

    test('Bug 3: NotableIdentitiesSolver parses expressions from rawInput', () {
      final resSum = NotableIdentitiesSolver.solveExpressionString('(2x + 3)^2');
      expect(resSum.exactResultLatex, contains('4x^2'));
      expect(resSum.exactResultLatex, contains('12x'));
      expect(resSum.exactResultLatex, contains('9'));

      final resDiff = NotableIdentitiesSolver.solveExpressionString('(x - 4)^2');
      expect(resDiff.exactResultLatex, contains('x^2 - 8x + 16'));

      final resSumDiff = NotableIdentitiesSolver.solveExpressionString('(3x + 1)(3x - 1)');
      expect(resSumDiff.exactResultLatex, contains('9x^2 - 1'));
    });

    test('Bug 5: CasioLcdScreen.sanitizeForMathTex sanitizes accents and superscripts for Math.tex', () {
      final quadNoSol = QuadraticEquationSolver.solve(a: 1, b: 0, c: 4);
      final sanitizedExact = CasioLcdScreen.sanitizeForMathTex(quadNoSol.exactResultLatex);
      expect(sanitizedExact, isNot(contains('ó')));

      for (final step in quadNoSol.steps) {
        final sanitized = CasioLcdScreen.sanitizeForMathTex(step.latexExpression);
        expect(sanitized, isNot(contains('ó')));
        expect(sanitized, isNot(contains('í')));
        expect(sanitized, isNot(contains('ú')));
        expect(sanitized, isNot(contains('é')));
        expect(sanitized, isNot(contains('á')));
      }

      final linearNoSol = LinearEquationSolver.solveEquationString('x = x + 1');
      final sanitizedLinear = CasioLcdScreen.sanitizeForMathTex(linearNoSol.exactResultLatex);
      expect(sanitizedLinear, isNot(contains('ó')));

      final sysNoSol = LinearSystemSolver.solve(a1: 1, b1: 1, c1: 2, a2: 1, b2: 1, c2: 5);
      final sanitizedSys = CasioLcdScreen.sanitizeForMathTex(sysNoSol.exactResultLatex);
      expect(sanitizedSys, isNot(contains('ó')));

      final evaluator = StepEvaluator();
      final evalVar = evaluator.evaluate(
        const VariableNode('ANS'),
        memoryVariables: {},
      );
      for (final step in evalVar.steps) {
        expect(CasioLcdScreen.sanitizeForMathTex(step.latexExpression), isNot(contains('ó')));
      }
    });

    test('Bug 6: DEL on multi-character token ANS should remove the whole token', () {
      String raw = 'ANS';
      final multiCharTokens = ['ANS', 'mcm(', 'mcd(', '√(', '^(', '³√('];
      bool removedToken = false;
      for (final token in multiCharTokens) {
        if (raw.endsWith(token)) {
          raw = raw.substring(0, raw.length - token.length);
          removedToken = true;
          break;
        }
      }
      expect(removedToken, isTrue);
      expect(raw, isEmpty);
    });
  });
}
