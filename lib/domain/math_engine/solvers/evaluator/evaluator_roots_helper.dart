import 'dart:math' as math;
import '../../ast/ast_nodes.dart';
import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../exact/exact_number.dart' show ExMathError;
import '../radical_and_factor_solver.dart';

class EvaluatorRootsHelper {
  static ExprNode reduceCbrt(
    CbrtNode node, {
    required ExprNode fullRoot,
    required ExprNode Function(ExprNode, {required ExprNode fullRoot}) reduceNextStep,
    required void Function({
      required String title,
      required String latex,
      required String note,
      String? warning,
    }) addStep,
  }) {
    final radicand = node.radicand;
    if (radicand is! ResolvedRationalNode) {
      return CbrtNode(reduceNextStep(radicand, fullRoot: fullRoot));
    }
    final val = radicand.value;
    if (val.isInteger) {
      final n = val.numerator;
      final sign = n < 0 ? -1 : 1;
      final absN = n.abs();
      final cbrtApprox = math.pow(absN, 1 / 3).round();
      if (cbrtApprox * cbrtApprox * cbrtApprox == absN) {
        final resVal = sign * cbrtApprox;
        addStep(
          title: 'Raíz cúbica exacta',
          latex: '\\sqrt[3]{$n} = $resVal',
          note: '$n es un cubo perfecto ($resVal · $resVal · $resVal = $n).',
        );
        return ResolvedRationalNode(Rational(resVal));
      }
    }
    final doubleVal = (math.pow(val.toDouble().abs(), 1 / 3) * (val.toDouble() < 0 ? -1 : 1)).toDouble();
    addStep(
      title: 'Raíz cúbica',
      latex: '\\sqrt[3]{${val.toLatex()}} \\approx ${doubleVal.toStringAsFixed(4)}',
      note: 'Calculamos la raíz cúbica decimal aproximada.',
    );
    return ResolvedRationalNode(Rational.fromDouble(doubleVal), isApproximateDecimal: true);
  }

  static ExprNode reduceNthRoot(
    NthRootNode node, {
    required ExprNode fullRoot,
    required ExprNode Function(ExprNode, {required ExprNode fullRoot}) reduceNextStep,
    required void Function({
      required String title,
      required String latex,
      required String note,
      String? warning,
    }) addStep,
  }) {
    final n = node.n;
    final radicand = node.radicand;
    if (radicand is! ResolvedRationalNode) {
      return NthRootNode(n, reduceNextStep(radicand, fullRoot: fullRoot));
    }
    final val = radicand.value;
    final doubleVal = math.pow(val.toDouble(), 1 / n).toDouble();
    addStep(
      title: 'Raíz de índice $n',
      latex: '\\sqrt[$n]{${val.toLatex()}} \\approx ${doubleVal.toStringAsFixed(4)}',
      note: 'Calculamos la raíz de índice $n.',
    );
    return ResolvedRationalNode(Rational.fromDouble(doubleVal), isApproximateDecimal: true);
  }

  static ExprNode reduceSqrt(
    SqrtNode node, {
    required ExprNode fullRoot,
    required ExprNode Function(ExprNode, {required ExprNode fullRoot}) reduceNextStep,
    required void Function({
      required String title,
      required String latex,
      required String note,
      String? warning,
    }) addStep,
    required List<MathStep> steps,
  }) {
    final radicand = node.radicand;
    if (radicand is IntNode) {
      final n = radicand.value;
      if (n < 0) throw const ExMathError(ExMathError.evenRootNegative);
      final sqrtInt = math.sqrt(n).toInt();
      if (sqrtInt * sqrtInt == n) {
        addStep(
          title: 'Raíz cuadrada exacta',
          latex: '\\sqrt{$n} = $sqrtInt',
          note: '$n es un cuadrado perfecto ($sqrtInt · $sqrtInt = $n).',
        );
        return ResolvedRationalNode(Rational(sqrtInt));
      }
      final res = RadicalAndFactorSolver.simplifySquareRoot(n);
      for (final s in res.steps) {
        steps.add(s);
      }
      return ExactRadicalNode(1, n);
    }
    if (radicand is! ResolvedRationalNode) {
      return SqrtNode(reduceNextStep(radicand, fullRoot: fullRoot));
    }
    final val = radicand.value;
    if (val.numerator < 0) throw const ExMathError(ExMathError.evenRootNegative);
    if (val.isInteger) {
      final n = val.numerator;
      final sqrtInt = math.sqrt(n).toInt();
      if (sqrtInt * sqrtInt == n) {
        addStep(
          title: 'Raíz cuadrada exacta',
          latex: '\\sqrt{$n} = $sqrtInt',
          note: '$n es un cuadrado perfecto ($sqrtInt · $sqrtInt = $n).',
        );
        return ResolvedRationalNode(Rational(sqrtInt));
      }
      return ExactRadicalNode(1, n);
    }
    final doubleVal = math.sqrt(val.toDouble());
    addStep(
      title: 'Raíz cuadrada aproximada',
      latex: '\\sqrt{${val.toLatex()}} \\approx ${doubleVal.toStringAsFixed(4)}',
      note: 'Calculamos el valor decimal aproximado de la raíz.',
    );
    return ResolvedRationalNode(
      Rational.fromDouble(doubleVal, 1000000),
      isApproximateDecimal: true,
    );
  }
}
