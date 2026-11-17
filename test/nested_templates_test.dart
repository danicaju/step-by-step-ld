import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/step_evaluator.dart';

String live(String raw) => ExpressionParser.rawToLiveLatex(raw);

void evalOk(String expr) {
  final ast = ExpressionParser().parse(ExpressionParser.finalizeForEvaluation(expr));
  StepEvaluator().evaluate(ast);
}

void main() {
  group('Anidamiento en vivo', () {
    test('trig y raices anidadas', () {
      expect(live('sin(cos(30))'), contains(r'\sin\left(\cos\left(30\right)\right)'));
      expect(live('sin(√(cos(x)))'), contains(r'\sin\left(\sqrt{\cos\left(x\right)}\right)'));
      expect(live('√(sin(90))'), contains(r'\sqrt{\sin\left(90\right)}'));
      expect(live('cos(arcsin(0.5))'), contains(r'\cos\left(\sin^{-1}\left(0.5\right)\right)'));
      expect(live('√(√(4))'), contains(r'\sqrt{\sqrt{4}}'));
    });

    test('funciones dentro de log_, root y mcm', () {
      expect(live('log_(2,sin(30))'), contains(r'\log_{2}\left(\sin\left(30\right)\right)'));
      expect(live('root(3,cos(x))'), contains(r'\sqrt[3]{\cos\left(x\right)}'));
      expect(live('mcm(sin(30),12)'), isNot(contains('sin(')));
    });

    test('argumento negativo no es plantilla binomio', () {
      expect(live('sin(-30)'), isNot(contains('color{gray}')));
      expect(live('√(-4)'), isNot(contains('color{gray}')));
    });

    test('evaluacion anidada', () {
      evalOk('sin(cos(30))');
      evalOk('√(sin(90))');
      evalOk('cos(arcsin(0.5))');
      evalOk(r'\sqrt{\sin(90)}');
      evalOk(r'\sin(\cos(30))');
    });
  });

  group('D-Pad en logaritmos', () {
    (String, int) right(String raw, int pos) {
      final r = ExpressionParser.handleFractionRightArrow(raw, pos) ??
          ExpressionParser.handlePowerRightArrow(raw, pos) ??
          ExpressionParser.handleMcmMcdRightArrow(raw, pos) ??
          ExpressionParser.handleTwoSlotRightArrow(raw, pos) ??
          ExpressionParser.handleStructuredBlockRightArrow(raw, pos);
      return r ?? (raw, ExpressionParser.stepCursorRight(raw, pos));
    }

    test('log_ base -> argumento -> fuera', () {
      var (raw, pos) = ('log_(2', 6);
      (raw, pos) = right(raw, pos);
      expect(raw, 'log_(2,');
      raw = '$raw' 'x';
      pos = raw.length;
      (raw, pos) = right(raw, pos);
      expect(raw, 'log_(2,x)');
      expect(pos, raw.length);
    });

    test('no se intercepta por fraccion previa', () {
      final (raw, _) = right('1/2+log_(3', 10);
      expect(raw, '1/2+log_(3,');
    });

    test('no se intercepta por potencia dentro de log_', () {
      final (raw, _) = right('log_(2^3', 8);
      expect(raw, 'log_(2^3,');
    });
  });
}
