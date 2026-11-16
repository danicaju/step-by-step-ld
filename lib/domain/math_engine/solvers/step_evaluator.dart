import 'dart:math' as math;

import '../ast/ast_nodes.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import 'trig_and_angles_solver.dart';
import 'evaluator/evaluator_quick_eval.dart';
import 'evaluator/evaluator_binary_op_helper.dart';
import 'evaluator/evaluator_special_nodes_helper.dart';
import 'evaluator/evaluator_roots_helper.dart';

export 'evaluator/evaluator_quick_eval.dart';
export 'evaluator/evaluator_binary_op_helper.dart';
export 'evaluator/evaluator_special_nodes_helper.dart';
export 'evaluator/evaluator_roots_helper.dart';

class StepEvaluator {
  final List<MathStep> _steps = [];
  Map<String, Rational> _memoryVariables;
  AngleUnit _angleUnit;
  Rational? _lastEvaluatedRational;

  Rational? get lastEvaluatedRational => _lastEvaluatedRational;

  StepEvaluator({
    Map<String, Rational>? memoryVariables,
    AngleUnit angleUnit = AngleUnit.deg,
  })  : _memoryVariables = memoryVariables ?? const {},
        _angleUnit = angleUnit;

  StepByStepResolution evaluate(
    ExprNode root, {
    Map<String, Rational>? memoryVariables,
    AngleUnit angleUnit = AngleUnit.deg,
    String? rawInput,
    bool isEquationSide = false,
  }) {
    _steps.clear();
    if (memoryVariables != null) _memoryVariables = memoryVariables;
    _angleUnit = angleUnit;

    final topLevelRes = EvaluatorSpecialNodesHelper.tryEvaluateTopLevel(
      root,
      angleUnit: _angleUnit,
      rawInput: rawInput,
      setLastEvaluatedRational: (r) => _lastEvaluatedRational = r,
    );
    if (topLevelRes != null) return topLevelRes;

    final origLatex = (rawInput != null && rawInput.trim().isNotEmpty)
        ? rawInput.trim()
        : root.toLatex();

    ExprNode current = root;
    int iteration = 0;
    const maxSteps = 40;

    while (current is! ResolvedRationalNode &&
        current is! ExactRadicalNode &&
        iteration < maxSteps) {
      iteration++;
      final next = _reduceNextStep(current, fullRoot: root);
      if (next == current) break;
      current = next;
    }

    final String exact;
    final String decimal;

    if (current is ResolvedRationalNode) {
      final resNode = current;
      _lastEvaluatedRational = resNode.value;
      exact = resNode.isApproximateDecimal
          ? resNode.value.toDecimalLatex()
          : resNode.value.toLatex();
      decimal = resNode.value.toDecimalLatex();
    } else if (current is ExactRadicalNode) {
      final approx = current.multiplier * math.sqrt(current.radicand);
      _lastEvaluatedRational = Rational.fromDouble(approx, 100000);
      exact = current.toLatex();
      decimal = Rational.fromDouble(approx, 100000).toDecimalLatex();
    } else {
      final approxD = EvaluatorQuickEval.evalToDoubleQuick(
            current,
            angleUnit: _angleUnit,
            memoryVariables: _memoryVariables,
          ) ??
          EvaluatorQuickEval.evalToDoubleQuick(
            root,
            angleUnit: _angleUnit,
            memoryVariables: _memoryVariables,
          );
      if (approxD != null && !approxD.isNaN && !approxD.isInfinite) {
        _lastEvaluatedRational = Rational.fromDouble(approxD, 100000);
        exact = current.toLatex();
        decimal = Rational.fromDouble(approxD, 100000).toDecimalLatex();
      } else {
        _lastEvaluatedRational = Rational(0);
        exact = current.toLatex();
        decimal = '';
      }
    }

    final res = StepByStepResolution(
      originalInputLatex: origLatex,
      steps: List.unmodifiable(_steps),
      exactResultLatex: exact,
      decimalApproxLatex: decimal,
    );

    if (_steps.isEmpty && current is ResolvedRationalNode) {
      _steps.add(
        MathStep(
          index: 1,
          shortTitle: 'Resultado directo',
          latexExpression: '$origLatex = $exact',
          pedagogicalNote: 'La expresión ya es irreducible.',
        ),
      );
      return StepByStepResolution(
        originalInputLatex: origLatex,
        steps: List.unmodifiable(_steps),
        exactResultLatex: exact,
        decimalApproxLatex: decimal,
      );
    }
    return res;
  }

  void _addStep({
    required String title,
    required String latex,
    required String note,
    String? warning,
  }) {
    _steps.add(
      MathStep(
        index: _steps.length + 1,
        shortTitle: '${_steps.length + 1}. $title',
        latexExpression: latex,
        pedagogicalNote: note,
        warningTrick: warning,
      ),
    );
  }

  ExprNode _reduceNextStep(ExprNode node, {required ExprNode fullRoot}) {
    switch (node) {
      case ResolvedRationalNode():
        return node;

      case ExactRadicalNode():
        return node;

      case VariableNode(:final name):
        final upper = name.toUpperCase();
        final val = _memoryVariables[upper] ?? Rational(0);
        final varLatex = upper == 'ANS' ? r'\text{ANS}' : upper;
        _addStep(
          title: 'Sustitución de variable o memoria $upper',
          latex:
              '\\text{Sustituimos } $varLatex = ${val.toLatex()} \\text{ en la expresion}',
          note:
              'Reemplazamos el valor numérico guardado en la memoria de la calculadora.',
        );
        return ResolvedRationalNode(val);

      case CbrtNode():
        return EvaluatorRootsHelper.reduceCbrt(
          node,
          fullRoot: fullRoot,
          reduceNextStep: _reduceNextStep,
          addStep: _addStep,
        );

      case NthRootNode():
        return EvaluatorRootsHelper.reduceNthRoot(
          node,
          fullRoot: fullRoot,
          reduceNextStep: _reduceNextStep,
          addStep: _addStep,
        );

      case McmNode(:final args):
        return EvaluatorSpecialNodesHelper.reduceMcmOrMcd(
          args,
          isMcm: true,
          fullRoot: fullRoot,
          reduceNextStep: _reduceNextStep,
          addStep: _addStep,
        );

      case McdNode(:final args):
        return EvaluatorSpecialNodesHelper.reduceMcmOrMcd(
          args,
          isMcm: false,
          fullRoot: fullRoot,
          reduceNextStep: _reduceNextStep,
          addStep: _addStep,
        );

      case SqrtNode():
        return EvaluatorRootsHelper.reduceSqrt(
          node,
          fullRoot: fullRoot,
          reduceNextStep: _reduceNextStep,
          addStep: _addStep,
          steps: _steps,
        );

      case IntNode(:final value):
        return ResolvedRationalNode(Rational(value));

      case DecimalNode():
        return ResolvedRationalNode(node.toRational());

      case PiNode():
        return ResolvedRationalNode(
          Rational.fromDouble(math.pi, 1000000),
          isApproximateDecimal: true,
        );

      case TrigNode():
        final res = EvaluatorSpecialNodesHelper.evaluateTopLevelTrig(
          node,
          angleUnit: _angleUnit,
          setLastEvaluatedRational: (r) => _lastEvaluatedRational = r,
        );
        for (final s in res.steps) {
          _steps.add(s);
        }
        final parsedDec = double.tryParse(res.decimalApproxLatex
                .replaceAll('°', '')
                .replaceAll('^\\circ', '')
                .replaceAll(',', '.')) ??
            double.tryParse(res.exactResultLatex.replaceAll(',', '.'));
        final approxD = EvaluatorQuickEval.evalToDoubleQuick(node, angleUnit: _angleUnit) ?? parsedDec ?? 0.0;
        final info = EvaluatorQuickEval.rationalFromResultLatexOrDouble(res.exactResultLatex, approxD);
        return ResolvedRationalNode(
          info.rational,
          isApproximateDecimal: info.isApproximateDecimal,
        );

      case LogNode():
        final res = EvaluatorSpecialNodesHelper.evaluateTopLevelLog(
          node,
          setLastEvaluatedRational: (r) => _lastEvaluatedRational = r,
        );
        for (final s in res.steps) {
          _steps.add(s);
        }
        final parsedDec = double.tryParse(res.decimalApproxLatex.replaceAll(',', '.')) ??
            double.tryParse(res.exactResultLatex.replaceAll(',', '.'));
        final approxD = EvaluatorQuickEval.evalToDoubleQuick(node) ?? parsedDec ?? 0.0;
        final info = EvaluatorQuickEval.rationalFromResultLatexOrDouble(res.exactResultLatex, approxD);
        return ResolvedRationalNode(
          info.rational,
          isApproximateDecimal: info.isApproximateDecimal,
        );

      case PercentNode(:final operand):
        if (operand is! ResolvedRationalNode) {
          return PercentNode(_reduceNextStep(operand, fullRoot: fullRoot));
        }
        final ratio = operand.value / Rational(100);
        _addStep(
          title: 'Conversión de porcentaje',
          latex: '${operand.value.toLatex()}\\% = ${ratio.toLatex()}',
          note: 'Dividimos entre 100 para operar el porcentaje en forma exacta.',
        );
        return ResolvedRationalNode(ratio);

      case DmsNode(:final degrees, :final minutes, :final seconds, :final isNegative):
        final dms = DmsValue(
          degrees: degrees,
          minutes: minutes,
          seconds: seconds,
          isNegative: isNegative,
        );
        final decDeg = dms.toDecimalDegrees();
        final decStr = Rational.fromDouble(decDeg, 1000000).toDecimalLatex();
        _addStep(
          title: 'Conversión sexagesimal a grados decimales',
          latex: '${dms.toLatex()} = $decStr°',
          note:
              'Convertimos grados, minutos y segundos a forma decimal: D + M/60 + S/3600.',
        );
        return ResolvedRationalNode(
          Rational.fromDouble(decDeg, 1000000),
          isApproximateDecimal: true,
        );

      case FractionNode(:final numerator, :final denominator):
        final raw = Rational(numerator, denominator);
        final simplified = raw.simplify();
        if (raw.isReducible) {
          final gcd = Rational.gcd(numerator, denominator);
          _addStep(
            title: 'Simplificación de fracción',
            latex:
                '\\frac{$numerator : $gcd}{$denominator : $gcd} = ${simplified.toLatex()}',
            note:
                'Dividimos numerador y denominador entre su M.C.D. ($gcd) para obtener la fracción irreducible.',
          );
          return ResolvedRationalNode(simplified);
        }
        return ResolvedRationalNode(raw);

      // TRAMPA CLÁSICA DE EXAMEN: -a^n (el signo menos está fuera de la potencia)
      case UnaryMinusNode(operand: PowerNode(:final base, :final exponent)):
        if (base is IntNode) {
          final baseVal = base.value;
          final powVal = Rational(baseVal).pow(exponent);
          final finalVal = Rational(-powVal.numerator, powVal.denominator);
          final isEven = exponent % 2 == 0;
          final expansion = exponent > 0 && exponent <= 6
              ? '-\\left(${List.filled(exponent, baseVal).join(r' \cdot ')}\\right) = '
              : '';

          _addStep(
            title: 'Potencia sin paréntesis en el signo',
            latex: '-$baseVal^{$exponent} = $expansion${finalVal.toLatex()}',
            note:
                'Calculamos la potencia de $baseVal y mantenemos el signo menos delante.',
            warning: isEven
                ? 'El exponente $exponent solo afecta al $baseVal porque no hay paréntesis: el resultado es negativo (-${powVal.denominator == 1 ? '${powVal.numerator}' : '${powVal.numerator}/${powVal.denominator}'}).'
                : null,
          );
          return ResolvedRationalNode(finalVal);
        }
        final reducedOperand = _reduceNextStep(node.operand, fullRoot: fullRoot);
        return UnaryMinusNode(reducedOperand);

      case UnaryMinusNode(:final operand):
        if (operand is IntNode) {
          return ResolvedRationalNode(Rational(-operand.value));
        }
        if (operand is! ResolvedRationalNode) {
          return UnaryMinusNode(_reduceNextStep(operand, fullRoot: fullRoot));
        }
        final val = operand.value;
        final neg = Rational(-val.numerator, val.denominator);
        _addStep(
          title: 'Signo negativo',
          latex: '-(${val.toLatex()}) = ${neg.toLatex()}',
          note: 'Cambiamos el signo del valor numérico.',
        );
        return ResolvedRationalNode(neg);

      // CASO CON PARÉNTESIS: (-a)^n
      case PowerNode(:final base, :final exponent):
        if (base is UnaryMinusNode && base.operand is IntNode) {
          final baseVal = -(base.operand as IntNode).value;
          final result = Rational(baseVal).pow(exponent);
          final isEven = exponent % 2 == 0;
          final expansion = exponent > 0 && exponent <= 6
              ? '${List.filled(exponent, '($baseVal)').join(r' \cdot ')} = '
              : '';

          _addStep(
            title: 'Potencia de base negativa entre paréntesis',
            latex: '\\left($baseVal\\right)^{$exponent} = $expansion${result.toLatex()}',
            note: isEven
                ? 'Base negativa entre paréntesis elevada a exponente par ($exponent) da resultado positivo.'
                : 'Base negativa elevada a exponente impar ($exponent) conserva el signo negativo.',
          );
          return ResolvedRationalNode(result);
        }

        if (base is! ResolvedRationalNode) {
          return PowerNode(_reduceNextStep(base, fullRoot: fullRoot), exponent);
        }
        final baseVal = base.value;
        if (exponent < 0) {
          final inverted = Rational(baseVal.denominator, baseVal.numerator);
          final posExp = -exponent;
          _addStep(
            title: 'Exponente negativo',
            latex:
                '\\left(${baseVal.toLatex()}\\right)^{$exponent} = \\left(${inverted.toLatex()}\\right)^{$posExp}',
            note:
                'Invertimos la base para transformar el exponente en positivo: (a/b)⁻ⁿ = (b/a)ⁿ.',
          );
          return PowerNode(ResolvedRationalNode(inverted), posExp);
        }
        final finalVal = baseVal.pow(exponent);
        _addStep(
          title: 'Cálculo de potencia',
          latex:
              '\\left(${baseVal.toLatex()}\\right)^{$exponent} = ${finalVal.toLatex()}',
          note:
              'Elevamos tanto el numerador como el denominador al exponente $exponent.',
        );
        return ResolvedRationalNode(finalVal);

      case BinaryOpNode(:final left, :final op, :final right):
        if (left is! ResolvedRationalNode) {
          return BinaryOpNode(
            _reduceNextStep(left, fullRoot: fullRoot),
            op,
            right,
          );
        }
        if (right is! ResolvedRationalNode) {
          return BinaryOpNode(
            left,
            op,
            _reduceNextStep(right, fullRoot: fullRoot),
          );
        }
        return EvaluatorBinaryOpHelper.evaluateBinaryRational(
          leftNode: left,
          op: op,
          rightNode: right,
          addStep: _addStep,
        );
    }
  }
}
