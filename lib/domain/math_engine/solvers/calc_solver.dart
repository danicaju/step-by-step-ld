import '../ast/ast_nodes.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';

class CalcSolver {
  /// Evalúa una expresión algebraica en `x` (tecla `CALC` de la Casio ClassWiz)
  /// mostrando la sustitución entre paréntesis, las potencias y la jerarquía final.
  static StepByStepResolution evaluateCalc({
    required ExprNode expr,
    required Rational xValue,
    String targetVariable = 'X',
    Map<String, Rational> memoryVars = const {},
    String? originalExprLatex,
  }) {
    final varLatex = xValue.toLatex();
    final exprOrig = originalExprLatex ?? expr.toLatex();
    final headerOrig = 'P($varLatex) \\text{ en } $exprOrig';

    final substitutedAst = _substituteVar(
      expr,
      targetVariable: targetVariable.toUpperCase(),
      xValue: xValue,
      memoryVars: memoryVars,
      isPowerBase: false,
    );
    final substitutedLatex = substitutedAst.toLatex();

    final steps = <MathStep>[];
    int stepIdx = 1;

    final bool hasNegSquareTrap = _containsNegatedVarPower(expr, targetVariable.toUpperCase()) &&
        xValue.isNegative;

    steps.add(
      MathStep(
        index: stepIdx++,
        shortTitle: 'Sustitución de $targetVariable entre paréntesis',
        latexExpression: 'P($varLatex) = $substitutedLatex',
        pedagogicalNote:
            'Reemplazamos cada aparición de la incógnita $targetVariable por su valor ($varLatex) protegido entre paréntesis.',
        warningTrick: xValue.isNegative
            ? (hasNegSquareTrap
                ? 'Con -x^2 cuando x es negativo, el exponente afecta solo a (-a) y el signo menos exterior se mantiene: -($varLatex)^2 = -(${(-xValue).toLatex()}^2) < 0.'
                : 'Al sustituir un número negativo, mantén siempre los paréntesis para no confundir signos en potencias ni productos.')
            : null,
      ),
    );

    // Fase 2: Resolver potencias manteniendo signos exteriores intactos
    ExprNode currentAst = substitutedAst;
    final afterPowers = _reducePowersPass(currentAst);
    final bool powersChanged = afterPowers.changed;
    currentAst = afterPowers.node;

    if (powersChanged) {
      steps.add(
        MathStep(
          index: stepIdx++,
          shortTitle: 'Calcular las potencias',
          latexExpression: '= ${currentAst.toLatex()}',
          pedagogicalNote:
              'Resolvemos primero las potencias según la jerarquía de operaciones (siempre antes que productos y sumas).',
        ),
      );
    }

    // Fase 3: Resolver multiplicaciones y divisiones
    final afterProducts = _reduceMulDivPass(currentAst);
    final bool mulChanged = afterProducts.changed;
    currentAst = afterProducts.node;

    if (mulChanged) {
      steps.add(
        MathStep(
          index: stepIdx++,
          shortTitle: 'Efectuar productos y cocientes',
          latexExpression: '= ${currentAst.toLatex()}',
          pedagogicalNote:
              'Multiplicamos y dividimos de izquierda a derecha aplicando la regla de los signos.',
        ),
      );
    }

    // Fase 4: Suma y resta final exacta
    final finalRational = _evalRationalExact(currentAst);
    if (finalRational == null) {
      return StepByStepResolution(
        originalInputLatex: headerOrig,
        steps: [
          ...steps,
          MathStep(
            index: stepIdx,
            shortTitle: 'No evaluable exactamente como polinomio',
            latexExpression: '${currentAst.toLatex()} \\implies \\text{Error}',
            pedagogicalNote:
                'Asegúrate de no dividir entre cero ni usar operadores no definidos en este valor.',
          ),
        ],
        exactResultLatex: r'\text{Error}',
        decimalApproxLatex: r'\text{Error}',
      );
    }

    final exactLatex = finalRational.toLatex();
    final decimalApprox = finalRational.toDecimalLatex();

    steps.add(
      MathStep(
        index: stepIdx,
        shortTitle: 'Valor numérico final',
        latexExpression: 'P($varLatex) = $exactLatex',
        pedagogicalNote:
            'Sumamos y restamos todos los términos ya simplificados para obtener P($varLatex).',
      ),
    );

    return StepByStepResolution(
      originalInputLatex: headerOrig,
      steps: steps,
      exactResultLatex: exactLatex,
      decimalApproxLatex: decimalApprox,
    );
  }

  static ExprNode _substituteVar(
    ExprNode node, {
    required String targetVariable,
    required Rational xValue,
    required Map<String, Rational> memoryVars,
    required bool isPowerBase,
  }) {
    return switch (node) {
      VariableNode(:final name) => () {
          final upper = name.toUpperCase();
          final Rational? val = upper == targetVariable
              ? xValue
              : memoryVars[upper];
          if (val == null) return node;
          if (val.isNegative) {
            // Si es base de potencia, PowerNode ya añade \left( \right) alrededor de UnaryMinusNode
            return UnaryMinusNode(
              ResolvedRationalNode(val.abs()),
              hasExplicitParentheses: !isPowerBase,
            );
          }
          return ResolvedRationalNode(val);
        }(),
      UnaryMinusNode(:final operand, :final hasExplicitParentheses) =>
        UnaryMinusNode(
          _substituteVar(
            operand,
            targetVariable: targetVariable,
            xValue: xValue,
            memoryVars: memoryVars,
            isPowerBase: isPowerBase,
          ),
          hasExplicitParentheses: hasExplicitParentheses,
        ),
      PowerNode(:final base, :final exponent) => PowerNode(
          _substituteVar(
            base,
            targetVariable: targetVariable,
            xValue: xValue,
            memoryVars: memoryVars,
            isPowerBase: true,
          ),
          exponent,
        ),
      BinaryOpNode(:final left, :final op, :final right, :final parenthesized) =>
        BinaryOpNode(
          _substituteVar(
            left,
            targetVariable: targetVariable,
            xValue: xValue,
            memoryVars: memoryVars,
            isPowerBase: false,
          ),
          op,
          _substituteVar(
            right,
            targetVariable: targetVariable,
            xValue: xValue,
            memoryVars: memoryVars,
            isPowerBase: false,
          ),
          parenthesized: parenthesized,
        ),
      _ => node,
    };
  }

  static bool _containsNegatedVarPower(ExprNode node, String targetVar) {
    return switch (node) {
      UnaryMinusNode(:final operand) =>
        (operand is PowerNode && operand.base is VariableNode && (operand.base as VariableNode).name.toUpperCase() == targetVar) ||
            _containsNegatedVarPower(operand, targetVar),
      BinaryOpNode(:final left, :final op, :final right) =>
        (op == BinaryOperator.subtract &&
                right is PowerNode &&
                right.base is VariableNode &&
                (right.base as VariableNode).name.toUpperCase() == targetVar) ||
            _containsNegatedVarPower(left, targetVar) ||
            _containsNegatedVarPower(right, targetVar),
      _ => false,
    };
  }

  static ({ExprNode node, bool changed}) _reducePowersPass(ExprNode node) {
    return switch (node) {
      PowerNode(:final base, :final exponent) => () {
          final inner = _reducePowersPass(base);
          final val = _evalRationalExact(inner.node);
          if (val != null) {
            return (node: _rationalToDisplayNode(val.pow(exponent)), changed: true);
          }
          return (node: PowerNode(inner.node, exponent), changed: inner.changed);
        }(),
      UnaryMinusNode(:final operand, :final hasExplicitParentheses) => () {
          final sub = _reducePowersPass(operand);
          return (
            node: UnaryMinusNode(sub.node, hasExplicitParentheses: hasExplicitParentheses),
            changed: sub.changed,
          );
        }(),
      BinaryOpNode(:final left, :final op, :final right, :final parenthesized) =>
        () {
          final l = _reducePowersPass(left);
          final r = _reducePowersPass(right);
          return (
            node: BinaryOpNode(l.node, op, r.node, parenthesized: parenthesized),
            changed: l.changed || r.changed,
          );
        }(),
      _ => (node: node, changed: false),
    };
  }

  static ({ExprNode node, bool changed}) _reduceMulDivPass(ExprNode node) {
    return switch (node) {
      BinaryOpNode(:final left, :final op, :final right, :final parenthesized) =>
        () {
          final l = _reduceMulDivPass(left);
          final r = _reduceMulDivPass(right);
          if (op == BinaryOperator.multiply || op == BinaryOperator.divide) {
            final lv = _evalRationalExact(l.node);
            final rv = _evalRationalExact(r.node);
            if (lv != null && rv != null) {
              if (op == BinaryOperator.divide && rv.isZero) {
                return (
                  node: BinaryOpNode(l.node, op, r.node, parenthesized: parenthesized),
                  changed: l.changed || r.changed,
                );
              }
              final res = op == BinaryOperator.multiply ? lv * rv : lv / rv;
              return (node: _rationalToDisplayNode(res), changed: true);
            }
          }
          return (
            node: BinaryOpNode(l.node, op, r.node, parenthesized: parenthesized),
            changed: l.changed || r.changed,
          );
        }(),
      UnaryMinusNode(:final operand, :final hasExplicitParentheses) => () {
          final sub = _reduceMulDivPass(operand);
          final val = _evalRationalExact(sub.node);
          if (sub.changed && val != null) {
            return (node: _rationalToDisplayNode(-val), changed: true);
          }
          return (
            node: UnaryMinusNode(sub.node, hasExplicitParentheses: hasExplicitParentheses),
            changed: sub.changed,
          );
        }(),
      _ => (node: node, changed: false),
    };
  }

  static ExprNode _rationalToDisplayNode(Rational r) {
    if (r.isNegative) {
      return UnaryMinusNode(
        ResolvedRationalNode(r.abs()),
        hasExplicitParentheses: true,
      );
    }
    return ResolvedRationalNode(r);
  }

  static Rational? _evalRationalExact(ExprNode node) {
    return switch (node) {
      IntNode(:final value) => Rational(value),
      DecimalNode() => node.toRational(),
      FractionNode(:final numerator, :final denominator) =>
        denominator == 0 ? null : Rational(numerator, denominator),
      ResolvedRationalNode(:final value) => value,
      UnaryMinusNode(:final operand) => () {
          final v = _evalRationalExact(operand);
          return v == null ? null : -v;
        }(),
      PowerNode(:final base, :final exponent) => () {
          final v = _evalRationalExact(base);
          if (v == null || (exponent < 0 && v.isZero)) return null;
          return v.pow(exponent);
        }(),
      BinaryOpNode(:final left, :final op, :final right) => () {
          final l = _evalRationalExact(left);
          final r = _evalRationalExact(right);
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
}
