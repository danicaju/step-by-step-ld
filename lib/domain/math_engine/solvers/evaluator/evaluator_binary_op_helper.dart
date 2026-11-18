import '../../ast/ast_nodes.dart';
import '../../core/algebraic_latex_formatter.dart';
import '../../core/rational.dart';
import '../exact/exact_number.dart' show ExMathError;
import '../trig_and_angles_solver.dart';

class EvaluatorBinaryOpHelper {
  static ResolvedRationalNode evaluateBinaryRational({
    required ResolvedRationalNode leftNode,
    required BinaryOperator op,
    required ResolvedRationalNode rightNode,
    required void Function({
      required String title,
      required String latex,
      required String note,
      String? warning,
    }) addStep,
  }) {
    final a = leftNode.value;
    final b = rightNode.value;
    final isApprox = leftNode.isApproximateDecimal || rightNode.isApproximateDecimal;

    if (isApprox) {
      final result = switch (op) {
        BinaryOperator.add => a + b,
        BinaryOperator.subtract => a - b,
        BinaryOperator.multiply => a * b,
        BinaryOperator.divide => b.isZero
            ? throw const FormatException('División por cero.')
            : a / b,
      };

      final signSymbol = op == BinaryOperator.add
          ? '+'
          : (op == BinaryOperator.subtract
              ? '-'
              : (op == BinaryOperator.multiply ? r'\cdot' : ':'));

      final aLatex = leftNode.isApproximateDecimal ? a.toDecimalLatex() : a.toLatex();
      final bLatex = rightNode.isApproximateDecimal ? b.toDecimalLatex() : b.toLatex();
      final rightStr = b.isNegative ? '($bLatex)' : bLatex;
      final resDec = result.toDecimalLatex();

      addStep(
        title: 'Operar aproximaciones decimales',
        latex: '$aLatex $signSymbol $rightStr \\approx $resDec',
        note: 'Operamos numéricamente manteniendo la precisión decimal.',
      );

      return ResolvedRationalNode(result, isApproximateDecimal: true);
    }

    switch (op) {
      case BinaryOperator.add:
      case BinaryOperator.subtract:
        final signSymbol = op == BinaryOperator.add ? '+' : '-';
        final isApprox = leftNode.isApproximateDecimal || rightNode.isApproximateDecimal;

        if (!isApprox && a.denominator != b.denominator) {
          final commonDen = Rational.lcm(a.denominator, b.denominator);
          final factorA = commonDen ~/ a.denominator;
          final factorB = commonDen ~/ b.denominator;

          final factALatex = Rational.primeFactorizationLatex(a.denominator);
          final factBLatex = Rational.primeFactorizationLatex(b.denominator);

          addStep(
            title: 'Denominador común (m.c.m.)',
            latex:
                '\\text{m.c.m.}(${a.denominator}, ${b.denominator}) = $commonDen \\quad \\left(${a.denominator} = $factALatex, \\; ${b.denominator} = $factBLatex\\right)',
            note:
                'Factorizamos los denominadores y tomamos los factores comunes y no comunes elevados al mayor exponente.',
          );

          final newNumA = a.numerator * factorA;
          final newNumB = b.numerator * factorB;

          addStep(
            title: 'Amplificar fracciones al denominador $commonDen',
            latex:
                '\\frac{\\textcolor{#2563EB}{$factorA} \\cdot ${AlgebraicLatexFormatter.parenIfNegative(a.numerator)}}{$commonDen} $signSymbol \\frac{\\textcolor{#2563EB}{$factorB} \\cdot ${AlgebraicLatexFormatter.parenIfNegative(b.numerator)}}{$commonDen} = \\frac{$newNumA}{$commonDen} $signSymbol \\frac{$newNumB}{$commonDen}',
            note:
                'Dividimos el m.c.m. ($commonDen) entre cada denominador antiguo y multiplicamos por su numerador.',
          );

          final combinedNum =
              op == BinaryOperator.add ? newNumA + newNumB : newNumA - newNumB;
          final unreduced = Rational.raw(combinedNum, commonDen);
          final simplified = unreduced.simplify();
          final numExprLatex = '$newNumA $signSymbol ${AlgebraicLatexFormatter.parenIfNegative(newNumB)}';

          if (unreduced.isReducible) {
            final gcd = Rational.gcd(combinedNum, commonDen);
            addStep(
              title: 'Operar numeradores y simplificar a fracción irreducible',
              latex:
                  '\\frac{$numExprLatex}{$commonDen} = \\frac{$combinedNum : $gcd}{$commonDen : $gcd} = ${simplified.toLatex()}',
              note:
                  'Operamos los numeradores y simplificamos dividiendo entre el M.C.D. ($gcd).',
            );
          } else {
            addStep(
              title: 'Operar numeradores',
              latex: '\\frac{$numExprLatex}{$commonDen} = ${simplified.toLatex()}',
              note: 'La fracción resultante ya es irreducible.',
            );
          }
          return ResolvedRationalNode(simplified);
        }

        Rational result;
        bool resultIsApprox = isApprox;
        if (isApprox) {
          final double dVal = op == BinaryOperator.add
              ? (a.toDouble() + b.toDouble())
              : (a.toDouble() - b.toDouble());
          final rounded = dVal.round();
          if ((dVal - rounded).abs() < 1e-5) {
            result = Rational(rounded);
            resultIsApprox = false;
          } else {
            result = Rational.fromDouble(dVal, 1000000);
          }
        } else {
          result = op == BinaryOperator.add ? a + b : a - b;
        }

        final rightStr = b.numerator < 0 ? '(${b.toLatex()})' : b.toLatex();
        final addLatex = isApprox
            ? '${a.toDecimalLatex()} $signSymbol ${b.toDecimalLatex()} \\approx ${result.toDecimalLatex()}'
            : '${a.toLatex()} $signSymbol $rightStr = ${result.toLatex()}';
        addStep(
          title: isApprox
              ? 'Operación con valores aproximados'
              : (a.isInteger && b.isInteger
                  ? 'Operar números enteros'
                  : 'Fracciones con igual denominador'),
          latex: addLatex,
          note: isApprox
              ? 'Realizamos la operación con los valores numéricos respetando la regla de los signos.'
              : (a.isInteger && b.isInteger
                  ? 'Resolvemos la operación entera respetando la regla de los signos.'
                  : 'Mantenemos el denominador común (${a.denominator}) y operamos los numeradores.'),
        );
        return ResolvedRationalNode(result, isApproximateDecimal: resultIsApprox);

      case BinaryOperator.multiply:
        final isApprox = leftNode.isApproximateDecimal || rightNode.isApproximateDecimal;
        Rational result;
        bool resultIsApprox = isApprox;
        if (isApprox) {
          final double dVal = a.toDouble() * b.toDouble();
          final rounded = dVal.round();
          if ((dVal - rounded).abs() < 1e-5) {
            result = Rational(rounded);
            resultIsApprox = false;
          } else {
            result = Rational.fromDouble(dVal, 1000000);
          }
        } else {
          result = a * b;
        }

        final rightStr = b.numerator < 0 ? '(${b.toLatex()})' : b.toLatex();
        final mulLatex = isApprox
            ? '${a.toDecimalLatex()} \\cdot ${b.toDecimalLatex()} \\approx ${result.toDecimalLatex()}'
            : ((a.isInteger && b.isInteger)
                ? '${a.toLatex()} \\cdot $rightStr = ${result.toLatex()}'
                : '${a.toLatex()} \\cdot $rightStr = \\frac{${a.numerator} \\cdot ${AlgebraicLatexFormatter.parenIfNegative(b.numerator)}}{${a.denominator} \\cdot ${b.denominator}} = ${result.toLatex()}');
        addStep(
          title: isApprox
              ? 'Multiplicación de valores aproximados'
              : ((a.isInteger && b.isInteger) ? 'Multiplicar enteros' : 'Multiplicación en línea'),
          latex: mulLatex,
          note: isApprox
              ? 'Calculamos el producto numérico respetando la regla de los signos.'
              : ((a.isInteger && b.isInteger)
                  ? 'Calculamos el producto respetando la regla de los signos.'
                  : 'Multiplicamos en línea: numerador por numerador y denominador por denominador.'),
        );
        return ResolvedRationalNode(result, isApproximateDecimal: resultIsApprox);

      case BinaryOperator.divide:
        final isApprox = leftNode.isApproximateDecimal || rightNode.isApproximateDecimal;
        Rational result;
        bool resultIsApprox = isApprox;
        if (isApprox) {
          final double dVal = a.toDouble() / b.toDouble();
          final rounded = dVal.round();
          if ((dVal - rounded).abs() < 1e-5) {
            result = Rational(rounded);
            resultIsApprox = false;
          } else {
            result = Rational.fromDouble(dVal, 1000000);
          }
        } else {
          if (b.isZero) throw const ExMathError(ExMathError.divByZero);
          result = a / b;
        }

        final rightStr = b.numerator < 0 ? '(${b.toLatex()})' : b.toLatex();
        final divLatex = isApprox
            ? '${a.toDecimalLatex()} : ${b.toDecimalLatex()} \\approx ${result.toDecimalLatex()}'
            : ((a.isInteger && b.isInteger)
                ? '${a.toLatex()} : $rightStr = ${result.toLatex()}'
                : '${a.toLatex()} : $rightStr = \\frac{${a.numerator} \\cdot ${b.denominator}}{${a.denominator} \\cdot ${AlgebraicLatexFormatter.parenIfNegative(b.numerator)}} = ${result.toLatex()}');
        addStep(
          title: isApprox
              ? 'División de valores aproximados'
              : ((a.isInteger && b.isInteger)
                  ? 'División exacta o en forma de fracción'
                  : 'División de fracciones (productos cruzados)'),
          latex: divLatex,
          note: isApprox
              ? 'Efectuamos el cociente numérico respetando la regla de los signos.'
              : ((a.isInteger && b.isInteger)
                  ? 'Dividimos los dos números y simplificamos si es fracción irreducible.'
                  : 'Multiplicamos en cruz (o multiplicamos la primera fracción por la inversa de la segunda).'),
        );
        return ResolvedRationalNode(result, isApproximateDecimal: resultIsApprox);
    }
  }

  static List<({DmsValue value, bool isSubtract})>? tryCollectDmsTerms(ExprNode node) {
    if (node is DmsNode) {
      return [
        (
          value: DmsValue(
            degrees: node.degrees,
            minutes: node.minutes,
            seconds: node.seconds,
            isNegative: node.isNegative,
          ),
          isSubtract: false,
        )
      ];
    }
    if (node is BinaryOpNode &&
        (node.op == BinaryOperator.add || node.op == BinaryOperator.subtract)) {
      final leftList = tryCollectDmsTerms(node.left);
      final rightList = tryCollectDmsTerms(node.right);
      if (leftList != null && rightList != null) {
        final isSub = node.op == BinaryOperator.subtract;
        final combined = [...leftList];
        for (final item in rightList) {
          combined.add((
            value: item.value,
            isSubtract: isSub ? !item.isSubtract : item.isSubtract,
          ));
        }
        return combined;
      }
    }
    return null;
  }
}
