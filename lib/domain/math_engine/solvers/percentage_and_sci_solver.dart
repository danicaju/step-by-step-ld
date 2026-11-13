import '../ast/ast_nodes.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';

class SciTerm {
  final Rational mantissa;
  final int exponent;

  const SciTerm(this.mantissa, this.exponent);
}

class PercentageAndSciSolver {
  /// Tanto por ciento directo: A% = A/100
  static StepByStepResolution solveStandalonePercent(Rational percent) {
    final orig = '${_formatScalarLatex(percent)}\\%';
    final ratio = percent / Rational(100);
    final exact = ratio.toLatex();
    final decimal = ratio.toDecimalLatex();

    return StepByStepResolution(
      originalInputLatex: orig,
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Conversión de porcentaje a fracción',
          latexExpression:
              '$orig = \\frac{${_formatScalarLatex(percent)}}{100} = $exact',
          pedagogicalNote:
              'Un porcentaje representa una razón entre 100 partes iguales; simplificamos la fracción resultante.',
        ),
      ],
      exactResultLatex: exact,
      decimalApproxLatex: decimal,
    );
  }

  /// Cálculo directo de porcentaje sobre una cantidad: B · A%
  static StepByStepResolution solvePercentOf({
    required Rational baseValue,
    required Rational percentValue,
    String? originalLatex,
  }) {
    final orig = originalLatex ??
        '${_formatScalarLatex(baseValue)} \\cdot ${_formatScalarLatex(percentValue)}\\%';
    final ratio = percentValue / Rational(100);
    final result = baseValue * ratio;
    final exact = result.toLatex();
    final decimal = result.toDecimalLatex();

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Conversión del porcentaje a fracción',
        latexExpression:
            '$orig = ${_formatScalarLatex(baseValue)} \\cdot \\frac{${_formatScalarLatex(percentValue)}}{100} = ${_formatScalarLatex(baseValue)} \\cdot ${ratio.toLatex()}',
        pedagogicalNote:
            'Sustituimos el símbolo % por dividir entre 100 y multiplicamos por la cantidad base.',
      ),
      MathStep(
        index: 2,
        shortTitle: 'Resultado final',
        latexExpression:
            '${_formatScalarLatex(baseValue)} \\cdot ${ratio.toLatex()} = $exact',
        pedagogicalNote: 'Efectuamos el producto y simplificamos el resultado.',
      ),
    ];

    return StepByStepResolution(
      originalInputLatex: orig,
      steps: steps,
      exactResultLatex: exact,
      decimalApproxLatex: decimal,
    );
  }

  /// Aumento o descuento porcentual mediante Índice de Variación: B + A% o B - A%
  static StepByStepResolution solvePercentageVariation({
    required Rational baseValue,
    required Rational percentValue,
    required bool isDiscount,
    String? originalLatex,
  }) {
    final opSym = isDiscount ? '-' : '+';
    final orig = originalLatex ??
        '${_formatScalarLatex(baseValue)} $opSym ${_formatScalarLatex(percentValue)}\\%';
    final deltaRatio = percentValue / Rational(100);
    final variationIndex =
        isDiscount ? Rational(1) - deltaRatio : Rational(1) + deltaRatio;
    final effectivePercent =
        Rational(100) + (isDiscount ? -percentValue : percentValue);
    final result = baseValue * variationIndex;

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Índice de variación porcentual',
        latexExpression:
            '\\text{I.V.} = 1 $opSym \\frac{${_formatScalarLatex(percentValue)}}{100} = ${variationIndex.toDecimalLatex()} = ${variationIndex.toLatex()}',
        pedagogicalNote:
            '${isDiscount ? "Descontar" : "Aumentar"} un ${percentValue.toDecimalLatex()}% equivale a calcular el ${effectivePercent.toDecimalLatex()}% de la cantidad inicial.',
        warningTrick:
            'Usar el índice de variación permite resolver aumentos y descuentos en un solo producto (también si se encadenan varios).',
      ),
      MathStep(
        index: 2,
        shortTitle: 'Multiplicar cantidad por índice de variación',
        latexExpression:
            '${_formatScalarLatex(baseValue)} \\cdot ${variationIndex.toLatex()} = ${result.toLatex()}',
        pedagogicalNote:
            'Multiplicamos la cantidad inicial por ${variationIndex.toDecimalLatex()} para obtener el valor final directo.',
      ),
    ];

    return StepByStepResolution(
      originalInputLatex: orig,
      steps: steps,
      exactResultLatex: result.toLatex(),
      decimalApproxLatex: result.toDecimalLatex(),
    );
  }

  /// Normaliza un único término en notación científica (ej: 3.2 · 10^-5 o 32 · 10^-5)
  static StepByStepResolution solveScientificSingle(
    SciTerm term, {
    String? originalLatex,
  }) {
    final orig = originalLatex ?? _sciLatex(term.mantissa, term.exponent);
    final normalized = normalizeSci(term.mantissa, term.exponent);
    final sciResultLatex = _sciLatex(normalized.mantissa, normalized.exponent);
    final decimalApprox =
        _sciToDecimalString(normalized.mantissa, normalized.exponent);

    final bool wasAlreadyNormalized =
        term.mantissa == normalized.mantissa &&
            term.exponent == normalized.exponent;

    final steps = <MathStep>[];
    if (!wasAlreadyNormalized) {
      steps.add(
        MathStep(
          index: 1,
          shortTitle: 'Normalizar mantisa en [1, 10)',
          latexExpression: '$orig = $sciResultLatex',
          pedagogicalNote:
              'Desplazamos la coma decimal hasta dejar una única cifra entera distinta de 0 (entre 1 y 9) y ajustamos el exponente de base 10.',
          warningTrick:
              'Si la mantisa se hace más pequeña, el exponente crece; si se hace más grande, el exponente disminuye.',
        ),
      );
    } else {
      steps.add(
        MathStep(
          index: 1,
          shortTitle: 'Lectura en notación científica',
          latexExpression: '$sciResultLatex = $decimalApprox',
          pedagogicalNote:
              'La mantisa (${normalized.mantissa.toDecimalLatex()}) ya está comprendida entre 1 y 10. El exponente (${normalized.exponent}) indica el desplazamiento de la coma.',
        ),
      );
    }

    return StepByStepResolution(
      originalInputLatex: orig,
      steps: steps,
      exactResultLatex: sciResultLatex,
      decimalApproxLatex: decimalApprox,
    );
  }

  /// Opera dos términos en notación científica: (m1 · 10^e1) · / : (m2 · 10^e2)
  static StepByStepResolution solveScientificBinary({
    required SciTerm left,
    required BinaryOperator op,
    required SciTerm right,
    String? originalLatex,
  }) {
    final orig = originalLatex ??
        '\\left(${_sciLatex(left.mantissa, left.exponent)}\\right) ${op.latexSymbol} \\left(${_sciLatex(right.mantissa, right.exponent)}\\right)';

    if (op == BinaryOperator.divide && right.mantissa.isZero) {
      return StepByStepResolution(
        originalInputLatex: orig,
        steps: [
          MathStep(
            index: 1,
            shortTitle: 'División entre cero',
            latexExpression: '$orig \\implies \\text{No definido}',
            pedagogicalNote: 'No se puede dividir entre 0.',
          ),
        ],
        exactResultLatex: r'\text{No definido}',
        decimalApproxLatex: r'\text{No definido}',
      );
    }

    final bool isMul = op == BinaryOperator.multiply;
    final Rational rawMantissa =
        isMul ? left.mantissa * right.mantissa : left.mantissa / right.mantissa;
    final int rawExponent =
        isMul ? left.exponent + right.exponent : left.exponent - right.exponent;

    final m1 = _formatMantissaLatex(left.mantissa);
    final m2 = _formatMantissaLatex(right.mantissa);
    final e2Wrapped =
        right.exponent < 0 ? '(${right.exponent})' : '${right.exponent}';
    final expOp = isMul ? '+' : '-';

    final mantGroupLatex =
        isMul ? '\\left($m1 \\cdot $m2\\right)' : '\\frac{$m1}{$m2}';
    final expGroupLatex = '10^{${left.exponent} $expOp $e2Wrapped}';

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Agrupar mantisas y potencias de 10',
        latexExpression: '$orig = $mantGroupLatex \\cdot $expGroupLatex',
        pedagogicalNote: isMul
            ? 'Multiplicamos los números decimales por un lado y sumamos los exponentes de base 10 por otro.'
            : 'Dividimos los números decimales por un lado y restamos los exponentes de base 10 por otro.',
        warningTrick: (!isMul && right.exponent < 0)
            ? 'Cuidado con la doble negación al restar un exponente negativo: a - (-b) = a + b.'
            : null,
      ),
      MathStep(
        index: 2,
        shortTitle: 'Operar mantisa y exponente',
        latexExpression:
            '$mantGroupLatex \\cdot $expGroupLatex = ${_sciLatex(rawMantissa, rawExponent)}',
        pedagogicalNote:
            'Obtenemos la mantisa resultante (${rawMantissa.toDecimalLatex()}) multiplicada por 10 elevado a $rawExponent.',
      ),
    ];

    final normalized = normalizeSci(rawMantissa, rawExponent);
    final sciResultLatex = _sciLatex(normalized.mantissa, normalized.exponent);

    if (normalized.mantissa != rawMantissa ||
        normalized.exponent != rawExponent) {
      final shift = normalized.exponent - rawExponent;
      final shiftFactor = '10^{$shift}';
      steps.add(
        MathStep(
          index: 3,
          shortTitle: 'Ajuste final a notación científica [1, 10)',
          latexExpression:
              '${_sciLatex(rawMantissa, rawExponent)} = ${_formatMantissaLatex(normalized.mantissa)} \\cdot $shiftFactor \\cdot 10^{$rawExponent} = $sciResultLatex',
          pedagogicalNote:
              'Como |${rawMantissa.toDecimalLatex()}| no está en [1, 10), movemos la coma decimal para normalizar la mantisa y sumamos $shift al exponente.',
          warningTrick:
              'En notación científica estándar, la parte entera de la mantisa solo puede ir de 1 a 9.',
        ),
      );
    }

    final decimalStr =
        _sciToDecimalString(normalized.mantissa, normalized.exponent);

    return StepByStepResolution(
      originalInputLatex: orig,
      steps: steps,
      exactResultLatex: sciResultLatex,
      decimalApproxLatex: decimalStr,
    );
  }

  /// Extrae un `SciTerm` si un nodo tiene la forma `m * 10^k` o `10^k`.
  static SciTerm? tryExtractSciTerm(ExprNode node) {
    if (node is BinaryOpNode && node.op == BinaryOperator.multiply) {
      final mant = _evalPureRational(node.left);
      final pow10 = _extractTenPower(node.right);
      if (mant != null && pow10 != null) {
        return SciTerm(mant, pow10);
      }
    }
    if (node is PowerNode) {
      final exp = _extractTenPower(node);
      if (exp != null) return SciTerm(Rational(1), exp);
    }
    return null;
  }

  static int? _extractTenPower(ExprNode node) {
    if (node is PowerNode &&
        node.base is IntNode &&
        (node.base as IntNode).value == 10) {
      return node.exponent;
    }
    return null;
  }

  static Rational? _evalPureRational(ExprNode node) {
    return switch (node) {
      IntNode(:final value) => Rational(value),
      DecimalNode() => node.toRational(),
      FractionNode(:final numerator, :final denominator) =>
        Rational(numerator, denominator),
      ResolvedRationalNode(:final value) => value,
      UnaryMinusNode(:final operand) => () {
          final r = _evalPureRational(operand);
          return r == null ? null : -r;
        }(),
      _ => null,
    };
  }

  static SciTerm normalizeSci(Rational mantissa, int exponent) {
    if (mantissa.isZero) return SciTerm(Rational(0), 0);
    final neg = mantissa.isNegative;
    Rational m = mantissa.abs();
    int e = exponent;
    int guard = 0;
    while (m.numerator >= 10 * m.denominator && guard < 100) {
      m = m / Rational(10);
      e++;
      guard++;
    }
    guard = 0;
    while (m.numerator < m.denominator && guard < 100) {
      m = m * Rational(10);
      e--;
      guard++;
    }
    return SciTerm(neg ? -m : m, e);
  }

  static Rational? _sciToRational(Rational mantissa, int exponent) {
    if (exponent.abs() > 8) return null;
    return mantissa * Rational(10).pow(exponent);
  }

  static String _sciToDecimalString(Rational mantissa, int exponent) {
    final exact = _sciToRational(mantissa, exponent);
    if (exact != null) {
      return exact.toDecimalLatex(maxDecimals: 10);
    }
    return _sciLatex(mantissa, exponent);
  }

  static String _sciLatex(Rational mantissa, int exponent) {
    return '${_formatMantissaLatex(mantissa)} \\cdot 10^{$exponent}';
  }

  static String _formatMantissaLatex(Rational m) {
    // Si tiene representación decimal exacta corta, mostrar con coma española (ej: 1,2 o 3,2)
    return m.toDecimalLatex(maxDecimals: 6);
  }

  static String _formatScalarLatex(Rational r) {
    if (r.isInteger) return '${r.numerator}';
    // Si viene de decimal exacto (ej. 12.5%), mostrar decimal o fracción según contexto
    if (r.denominator == 2 ||
        r.denominator == 4 ||
        r.denominator == 5 ||
        r.denominator == 10 ||
        r.denominator == 20 ||
        r.denominator == 25 ||
        r.denominator == 50 ||
        r.denominator == 100) {
      return r.toDecimalLatex();
    }
    return r.toLatex();
  }
}
