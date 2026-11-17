import 'dart:math' as math;
import '../../ast/ast_nodes.dart';
import '../../core/rational.dart';
import '../trig_and_angles_solver.dart';

class EvaluatorQuickEval {
  static ({Rational rational, bool isApproximateDecimal}) rationalFromResultLatexOrDouble(
    String latex,
    double fallback,
  ) {
    final trimmed = latex.trim();
    final intParsed = int.tryParse(trimmed);
    if (intParsed != null) {
      return (rational: Rational(intParsed), isApproximateDecimal: false);
    }
    final fracM = RegExp(r'^(-?)\\frac\{(\d+)\}\{(\d+)\}$').firstMatch(trimmed);
    if (fracM != null) {
      final sign = fracM[1] == '-' ? -1 : 1;
      return (
        rational: Rational(sign * int.parse(fracM[2]!), int.parse(fracM[3]!)),
        isApproximateDecimal: false,
      );
    }
    final decParsed = double.tryParse(trimmed.replaceAll(',', '.'));
    if (decParsed != null && !decParsed.isNaN && !decParsed.isInfinite) {
      return (
        rational: Rational.fromDouble(decParsed, 1000000),
        isApproximateDecimal: true,
      );
    }
    if (!fallback.isNaN && !fallback.isInfinite) {
      return (
        rational: Rational.fromDouble(fallback, 1000000),
        isApproximateDecimal: true,
      );
    }
    return (rational: Rational(0), isApproximateDecimal: false);
  }

  static Rational? extractPiMultiple(ExprNode node) {
    if (node is PiNode) return Rational(1);
    if (node is BinaryOpNode && node.op == BinaryOperator.multiply) {
      final lPi = extractPiMultiple(node.left);
      final rRat = evalToRationalQuick(node.right);
      if (lPi != null && rRat != null) return lPi * rRat;
      final rPi = extractPiMultiple(node.right);
      final lRat = evalToRationalQuick(node.left);
      if (rPi != null && lRat != null) return rPi * lRat;
    }
    if (node is BinaryOpNode && node.op == BinaryOperator.divide) {
      final lPi = extractPiMultiple(node.left);
      final rRat = evalToRationalQuick(node.right);
      if (lPi != null && rRat != null && !rRat.isZero) return lPi / rRat;
    }
    return null;
  }

  static Rational? evalToRationalQuick(
    ExprNode node, [
    Map<String, Rational>? memoryVariables,
  ]) {
    return switch (node) {
      IntNode(:final value) => Rational(value),
      DecimalNode() => node.toRational(),
      FractionNode(:final numerator, :final denominator) =>
        denominator == 0 ? null : Rational(numerator, denominator),
      ResolvedRationalNode(:final value) => value,
      VariableNode(:final name) => memoryVariables?[name.toUpperCase()] ?? Rational(0),
      PercentNode(:final operand) => () {
          final v = evalToRationalQuick(operand, memoryVariables);
          return v == null ? null : v / Rational(100);
        }(),
      UnaryMinusNode(:final operand) => () {
          final v = evalToRationalQuick(operand, memoryVariables);
          return v == null ? null : -v;
        }(),
      PowerNode(:final base, :final exponent) => () {
          final v = evalToRationalQuick(base, memoryVariables);
          if (v == null || (exponent < 0 && v.isZero)) return null;
          return v.pow(exponent);
        }(),
      BinaryOpNode(:final left, :final op, :final right) => () {
          final l = evalToRationalQuick(left, memoryVariables);
          final r = evalToRationalQuick(right, memoryVariables);
          if (l == null || r == null) return null;
          return switch (op) {
            BinaryOperator.add => l + r,
            BinaryOperator.subtract => l - r,
            BinaryOperator.multiply => l * r,
            BinaryOperator.divide => r.isZero ? null : l / r,
          };
        }(),
      _ => null,
    };
  }

  static double? evalToDoubleQuick(
    ExprNode node, {
    AngleUnit angleUnit = AngleUnit.deg,
    Map<String, Rational>? memoryVariables,
  }) {
    final rat = evalToRationalQuick(node, memoryVariables);
    if (rat != null) return rat.toDouble();
    return switch (node) {
      PiNode() => math.pi,
      DmsNode(:final degrees, :final minutes, :final seconds, :final isNegative) =>
        DmsValue(
          degrees: degrees,
          minutes: minutes,
          seconds: seconds,
          isNegative: isNegative,
        ).toDecimalDegrees(),
      SqrtNode(:final radicand) => () {
          final v = evalToDoubleQuick(radicand, angleUnit: angleUnit, memoryVariables: memoryVariables);
          return (v == null || v < 0) ? null : math.sqrt(v);
        }(),
      TrigNode(:final function, :final arg) => () {
          final a = evalToDoubleQuick(arg, angleUnit: angleUnit, memoryVariables: memoryVariables);
          if (a == null) return null;
          final rad = switch (angleUnit) {
            AngleUnit.deg => a * math.pi / 180.0,
            AngleUnit.grad => a * math.pi / 200.0,
            AngleUnit.rad => a,
          };
          final back = switch (angleUnit) {
            AngleUnit.deg => 180.0 / math.pi,
            AngleUnit.grad => 200.0 / math.pi,
            AngleUnit.rad => 1.0,
          };
          return switch (function) {
            TrigFunction.sin => math.sin(rad),
            TrigFunction.cos => math.cos(rad),
            TrigFunction.tan => math.tan(rad),
            TrigFunction.asin => math.asin(a.clamp(-1.0, 1.0)) * back,
            TrigFunction.acos => math.acos(a.clamp(-1.0, 1.0)) * back,
            TrigFunction.atan => math.atan(a) * back,
          };
        }(),
      LogNode(:final base, :final arg, :final isNaturalLn) => () {
          final a = evalToDoubleQuick(arg, angleUnit: angleUnit, memoryVariables: memoryVariables);
          if (a == null || a <= 0) return null;
          if (isNaturalLn) return math.log(a);
          final b = base != null
              ? evalToDoubleQuick(base, angleUnit: angleUnit, memoryVariables: memoryVariables)
              : 10.0;
          if (b == null || b <= 0 || (b - 1.0).abs() < 1e-12) return null;
          return math.log(a) / math.log(b);
        }(),
      UnaryMinusNode(:final operand) => () {
          final v = evalToDoubleQuick(operand, angleUnit: angleUnit, memoryVariables: memoryVariables);
          return v == null ? null : -v;
        }(),
      PowerNode(:final base, :final exponent) => () {
          final b = evalToDoubleQuick(base, angleUnit: angleUnit, memoryVariables: memoryVariables);
          if (b == null) return null;
          return math.pow(b, exponent).toDouble();
        }(),
      BinaryOpNode(:final left, :final op, :final right) => () {
          final l = evalToDoubleQuick(left, angleUnit: angleUnit, memoryVariables: memoryVariables);
          final r = evalToDoubleQuick(right, angleUnit: angleUnit, memoryVariables: memoryVariables);
          if (l == null || r == null) return null;
          return switch (op) {
            BinaryOperator.add => l + r,
            BinaryOperator.subtract => l - r,
            BinaryOperator.multiply => l * r,
            BinaryOperator.divide => r == 0 ? null : l / r,
          };
        }(),
      _ => null,
    };
  }
}
