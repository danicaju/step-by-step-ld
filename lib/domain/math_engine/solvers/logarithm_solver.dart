import 'dart:math' as math;
import '../core/rational.dart';
import '../models/step_resolution.dart';

class LogarithmSolver {
  /// Resuelve logaritmos decimales (`base == null`), en base arbitraria (`base != null`)
  /// o neperianos (`isNaturalLn == true`) con desglose didáctico de potencias de 4.º ESO / Bach.
  static StepByStepResolution solve({
    Rational? base,
    required Rational argument,
    bool isNaturalLn = false,
    String? customExprLatex,
  }) {
    final effectiveBase = base ?? Rational(10);
    final origLatex = customExprLatex ??
        _buildLogLatex(
          base: base,
          argument: argument,
          isNaturalLn: isNaturalLn,
        );

    // 1. Validación estricta de dominio logarítmico
    if (argument.numerator <= 0) {
      return StepByStepResolution(
        originalInputLatex: origLatex,
        steps: [
          MathStep(
            index: 1,
            shortTitle: 'Error de dominio logarítmico',
            latexExpression: '$origLatex \\implies \\text{No existe}',
            pedagogicalNote:
                'No existen logaritmos reales de 0 ni de números negativos.',
            warningTrick:
                'El argumento b de log_a(b) debe ser estrictamente positivo (b > 0).',
          ),
        ],
        exactResultLatex: r'\text{No existe}',
        decimalApproxLatex: r'\text{No existe}',
      );
    }

    if (!isNaturalLn &&
        (effectiveBase.numerator <= 0 || effectiveBase == Rational(1))) {
      return StepByStepResolution(
        originalInputLatex: origLatex,
        steps: [
          MathStep(
            index: 1,
            shortTitle: 'Base logarítmica no válida',
            latexExpression: '$origLatex \\implies \\text{No existe}',
            pedagogicalNote:
                'La base de un logaritmo real debe ser siempre mayor que 0 y distinta de 1.',
            warningTrick:
                'Condición de existencia: a > 0 y a != 1.',
          ),
        ],
        exactResultLatex: r'\text{No existe}',
        decimalApproxLatex: r'\text{No existe}',
      );
    }

    // 2. Caso neperiano ln(b)
    if (isNaturalLn) {
      if (argument == Rational(1)) {
        return StepByStepResolution(
          originalInputLatex: origLatex,
          steps: [
            MathStep(
              index: 1,
              shortTitle: 'Logaritmo de la unidad',
              latexExpression: '$origLatex = 0',
              pedagogicalNote: 'Todo número elevado a 0 vale 1 (e^{0} = 1).',
            ),
          ],
          exactResultLatex: '0',
          decimalApproxLatex: '0',
        );
      }

      final val = math.log(argument.toDouble());
      final approx = _formatDouble(val);
      return StepByStepResolution(
        originalInputLatex: origLatex,
        steps: [
          MathStep(
            index: 1,
            shortTitle: 'Logaritmo neperiano (base e)',
            latexExpression: '$origLatex \\approx $approx',
            pedagogicalNote:
                'Calculamos el exponente al que hay que elevar el número e para obtener ${argument.toLatex()}.',
          ),
        ],
        exactResultLatex: approx,
        decimalApproxLatex: approx,
      );
    }

    // 3. Caso universal log_a(1) = 0
    if (argument == Rational(1)) {
      return StepByStepResolution(
        originalInputLatex: origLatex,
        steps: [
          MathStep(
            index: 1,
            shortTitle: 'Logaritmo de la unidad',
            latexExpression: '$origLatex = 0',
            pedagogicalNote:
                'Por definición, ${effectiveBase.toLatex()}^{0} = 1, así que el logaritmo de 1 en cualquier base siempre vale 0.',
          ),
        ],
        exactResultLatex: '0',
        decimalApproxLatex: '0',
      );
    }

    // 4. Caso log_a(a) = 1
    if (argument == effectiveBase) {
      return StepByStepResolution(
        originalInputLatex: origLatex,
        steps: [
          MathStep(
            index: 1,
            shortTitle: 'Logaritmo de la propia base',
            latexExpression: '$origLatex = 1',
            pedagogicalNote:
                'Cuando base y argumento coinciden, el exponente es 1 (${effectiveBase.toLatex()}^{1} = ${argument.toLatex()}).',
          ),
        ],
        exactResultLatex: '1',
        decimalApproxLatex: '1',
      );
    }

    // 5. Resolución exacta por coincidencia de potencia (método 4.º ESO / 1.º Bachillerato)
    final baseDecomp = _canonicalPowerDecomposition(effectiveBase);
    final argDecomp = _canonicalPowerDecomposition(argument);

    if (baseDecomp != null &&
        argDecomp != null &&
        baseDecomp.rootBase == argDecomp.rootBase) {
      final rBase = baseDecomp.rootBase;
      final m = baseDecomp.exponent;
      final n = argDecomp.exponent;
      final exactResult = Rational(n, m);
      final decimalApprox = exactResult.toDecimalLatex();

      final steps = <MathStep>[];
      int stepIdx = 1;
      final logSymbol = base == null ? r'\log' : '\\log_{${effectiveBase.toLatex()}}';
      final rBaseLatex = rBase.isInteger
          ? '${rBase.numerator}'
          : '\\left(${rBase.toLatex()}\\right)';

      final String? negativeExpWarning = (argument.denominator > 1 && n < 0)
          ? 'Un argumento fraccionario 1/a^k equivale a una potencia de exponente negativo a^{-k}, por lo que el logaritmo sale negativo.'
          : null;

      // Paso 1: Reescribir argumento (y base si no es exponente 1) como potencia
      if (m == 1) {
        final String rewriteLatex;
        if (argument.numerator == 1 && argument.denominator > 1 && n < 0) {
          final posExp = n.abs();
          final posDenPower = posExp == 1 ? rBaseLatex : '$rBaseLatex^{$posExp}';
          rewriteLatex =
              '$origLatex = $logSymbol\\left(\\frac{1}{$posDenPower}\\right) = $logSymbol\\left($rBaseLatex^{$n}\\right)';
        } else {
          rewriteLatex = '$origLatex = $logSymbol\\left($rBaseLatex^{$n}\\right)';
        }

        steps.add(
          MathStep(
            index: stepIdx++,
            shortTitle: 'Expresar el argumento como potencia',
            latexExpression: rewriteLatex,
            pedagogicalNote:
                'Descomponemos ${argument.toLatex()} en potencia de la base ${rBase.toLatex()} para dejar explícito el exponente.',
            warningTrick: negativeExpWarning,
          ),
        );

        steps.add(
          MathStep(
            index: stepIdx++,
            shortTitle: 'Propiedad fundamental del logaritmo',
            latexExpression:
                '$logSymbol\\left($rBaseLatex^{$n}\\right) = ${exactResult.toLatex()}',
            pedagogicalNote:
                'Aplicamos que el logaritmo en base $rBaseLatex de $rBaseLatex^{$n} es directamente el exponente ($n).',
          ),
        );
      } else {
        // Caso base también compuesta (ej. log_4(32) -> 4 = 2^2, 32 = 2^5)
        steps.add(
          MathStep(
            index: stepIdx++,
            shortTitle: 'Misma base en ambos términos',
            latexExpression:
                '$origLatex = \\log_{$rBaseLatex^{$m}}\\left($rBaseLatex^{$n}\\right)',
            pedagogicalNote:
                'Expresamos tanto la base (${effectiveBase.toLatex()} = $rBaseLatex^{$m}) como el argumento (${argument.toLatex()} = $rBaseLatex^{$n}) en base común $rBaseLatex.',
            warningTrick: negativeExpWarning,
          ),
        );

        steps.add(
          MathStep(
            index: stepIdx++,
            shortTitle: 'Igualación de exponentes',
            latexExpression:
                '\\left($rBaseLatex^{$m}\\right)^{x} = $rBaseLatex^{$n} \\implies $m x = $n \\implies x = ${exactResult.toLatex()}',
            pedagogicalNote:
                'Por definición de logaritmo, igualamos los exponentes de la misma base y despejamos x.',
          ),
        );
      }

      return StepByStepResolution(
        originalInputLatex: origLatex,
        steps: steps,
        exactResultLatex: exactResult.toLatex(),
        decimalApproxLatex: decimalApprox,
      );
    }

    // 6. Aproximación numérica cuando no comparten base exacta (ej. log(5), log_2(7))
    final numericVal = math.log(argument.toDouble()) / math.log(effectiveBase.toDouble());
    final approx = _formatDouble(numericVal);
    final defEq = base == null
        ? '10^{x} = ${argument.toLatex()}'
        : '${effectiveBase.toLatex()}^{x} = ${argument.toLatex()}';

    return StepByStepResolution(
      originalInputLatex: origLatex,
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Definición y aproximación numérica',
          latexExpression: '$defEq \\implies $origLatex \\approx $approx',
          pedagogicalNote:
              'Como ${argument.toLatex()} no es una potencia racional exacta de ${effectiveBase.toLatex()}, evaluamos numéricamente el exponente.',
        ),
      ],
      exactResultLatex: approx,
      decimalApproxLatex: approx,
    );
  }

  /// Descompone un racional positivo `r != 1` en `(rootBase, exponent)` con `rootBase > 1`
  /// y `exponent != 0` entero máximo. Ej: `1/9 -> (3, -2)`, `32 -> (2, 5)`, `4 -> (2, 2)`.
  static ({Rational rootBase, int exponent})? _canonicalPowerDecomposition(Rational r) {
    if (r.numerator <= 0 || r == Rational(1)) return null;

    final bool inverted = r.numerator < r.denominator;
    final positiveGtOne = inverted ? Rational(r.denominator, r.numerator) : r;

    final numFactors = Rational.primeFactorsMap(positiveGtOne.numerator);
    final denFactors = Rational.primeFactorsMap(positiveGtOne.denominator);

    final allExps = [...numFactors.values, ...denFactors.values];
    if (allExps.isEmpty) return null;

    int g = allExps.first;
    for (int i = 1; i < allExps.length; i++) {
      g = Rational.gcd(g, allExps[i]);
    }

    int rootNum = 1;
    for (final e in numFactors.entries) {
      rootNum *= _intPow(e.key, e.value ~/ g);
    }
    int rootDen = 1;
    for (final e in denFactors.entries) {
      rootDen *= _intPow(e.key, e.value ~/ g);
    }

    return (
      rootBase: Rational(rootNum, rootDen),
      exponent: inverted ? -g : g,
    );
  }

  static int _intPow(int base, int exp) {
    int res = 1;
    for (int i = 0; i < exp; i++) {
      res *= base;
    }
    return res;
  }

  static String _buildLogLatex({
    required Rational? base,
    required Rational argument,
    required bool isNaturalLn,
  }) {
    if (isNaturalLn) return '\\ln\\left(${argument.toLatex()}\\right)';
    if (base == null) return '\\log\\left(${argument.toLatex()}\\right)';
    return '\\log_{${base.toLatex()}}\\left(${argument.toLatex()}\\right)';
  }

  static String _formatDouble(double v) {
    if ((v - v.roundToDouble()).abs() < 1e-9) {
      return '${v.round()}';
    }
    String s = v.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s.replaceAll('.', ',');
  }
}
