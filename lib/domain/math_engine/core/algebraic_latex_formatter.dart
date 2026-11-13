import 'rational.dart';

/// Formateador algebraico centralizado estilo humano (ESO / Bachillerato).
///
/// Reglas de oro:
/// - Omite coeficientes `0` (nunca `0x` ni `+ 0`, salvo cuando toda la expresión es `0`).
/// - Omite coeficientes `1` y `-1` delante de variables (`x`, `-x`, `x^2`, `-x^2`).
/// - Evita dobles signos (`+ -5x` -> `- 5x`, `- -3` -> `+ 3`, `(x - -2)` -> `(x + 2)`).
/// - Extrae el signo negativo fuera de `\frac{...}{...}` y suprime denominadores `1` o `-1`.
/// - Formatea radicales sin `1\sqrt{a}`, `a\sqrt{1}` ni `\sqrt{0}`.
class AlgebraicLatexFormatter {
  const AlgebraicLatexFormatter._();

  /// Formatea un monomio entero `coeff * variable^power`.
  ///
  /// Devuelve `''` si [coeff] es `0`. Si [isFirst] es `false`, antepone
  /// `' + '` o `' - '` según el signo del coeficiente.
  static String monomialTerm(
    int coeff,
    String variable, {
    bool isFirst = true,
    int power = 1,
  }) {
    if (coeff == 0) return '';
    if (power == 0 || variable.isEmpty) {
      return constantTerm(coeff, isFirst: isFirst);
    }

    final varPart = power == 1 ? variable : '$variable^{$power}';
    final absVal = coeff.abs();
    final coeffStr = absVal == 1 ? '' : '$absVal';
    final core = '$coeffStr$varPart';

    if (isFirst) {
      return coeff < 0 ? '-$core' : core;
    }
    return coeff < 0 ? ' - $core' : ' + $core';
  }

  /// Formatea un término independiente entero [value].
  ///
  /// Devuelve `''` si [value] es `0`.
  static String constantTerm(int value, {bool isFirst = true}) {
    if (value == 0) return '';
    if (isFirst) return '$value';
    return value < 0 ? ' - ${value.abs()}' : ' + $value';
  }

  /// Formatea una expresión lineal `coeff * variable + constant`.
  ///
  /// Si ambos son `0`, devuelve `'0'`.
  static String linearExpression(
    int coeff,
    int constant, {
    String variable = 'x',
  }) {
    return polynomialExpression([coeff, constant], variable: variable);
  }

  /// Formatea una expresión cuadrática `a*x^2 + b*x + c`.
  static String quadraticExpression(
    int a,
    int b,
    int c, {
    String variable = 'x',
  }) {
    return polynomialExpression([a, b, c], variable: variable);
  }

  /// Formatea un polinomio con coeficientes ordenados de mayor a menor grado.
  static String polynomialExpression(
    List<int> coeffs, {
    String variable = 'x',
  }) {
    final buffer = StringBuffer();
    bool hasWritten = false;
    final degree = coeffs.length - 1;

    for (int i = 0; i < coeffs.length; i++) {
      final coeff = coeffs[i];
      if (coeff == 0) continue;

      final deg = degree - i;
      final piece = deg == 0
          ? constantTerm(coeff, isFirst: !hasWritten)
          : monomialTerm(coeff, variable, isFirst: !hasWritten, power: deg);
      if (piece.isNotEmpty) {
        buffer.write(piece);
        hasWritten = true;
      }
    }

    return hasWritten ? buffer.toString() : '0';
  }

  /// Formatea una ecuación lineal con dos incógnitas `a*x + b*y = c`.
  static String twoVarEquation(
    int a,
    int b,
    int c, {
    String xVar = 'x',
    String yVar = 'y',
  }) {
    final buffer = StringBuffer();
    if (a != 0) {
      buffer.write(monomialTerm(a, xVar, isFirst: true));
    }
    if (b != 0) {
      buffer.write(monomialTerm(b, yVar, isFirst: a == 0));
    }
    final lhs = buffer.isEmpty ? '0' : buffer.toString();
    return '$lhs = $c';
  }

  /// Formatea el factor lineal correspondiente a una raíz entera [root]:
  /// `0` -> `x`, `2` -> `(x - 2)`, `-3` -> `(x + 3)`.
  static String linearFactor(int root, {String variable = 'x'}) {
    if (root == 0) return variable;
    if (root > 0) return '($variable - $root)';
    return '($variable + ${root.abs()})';
  }

  /// Formatea `coeff * variable` con signo explícito cuando se suma a otra expresión
  /// que ya tiene términos previos (p. ej. trasponer `+ 3x` o `- 3x`).
  static String signedMonomialAddition(int value, {String variable = 'x'}) {
    if (value == 0) return '';
    return monomialTerm(value, variable, isFirst: false);
  }

  /// Formatea la adición/sustracción de una constante con respecto a un miembro ya escrito.
  static String signedConstantAddition(int value) {
    return constantTerm(value, isFirst: false);
  }

  /// Formatea `coeff \cdot (exprLatex)` omitiendo coeficientes `0`, `1` y `-1`.
  static String signedCoeffTimesParenthesized(
    int coeff,
    String exprLatex, {
    bool isFirst = true,
  }) {
    if (coeff == 0) return '';
    final absVal = coeff.abs();
    final prefix = isFirst
        ? (coeff < 0 ? '-' : '')
        : (coeff < 0 ? ' - ' : ' + ');
    if (absVal == 1) {
      return '$prefix($exprLatex)';
    }
    return '$prefix$absVal \\cdot ($exprLatex)';
  }

  /// Formatea una resta `base - term` sin dobles signos ni `+ -`.
  static String differenceTerm(int term) {
    if (term == 0) return '';
    return term > 0 ? ' - $term' : ' + ${term.abs()}';
  }

  /// Envuelve un entero negativo entre paréntesis para sustituciones: `-4` -> `(-4)`.
  static String parenIfNegative(int value) {
    return value < 0 ? '($value)' : '$value';
  }

  /// Formatea la fracción `numerator / denominator` sin denominador negativo ni `1`/`-1`,
  /// manteniendo los valores sin reducir (útil antes del paso de simplificación).
  static String signedFraction(int numerator, int denominator) {
    if (denominator == 0) {
      throw ArgumentError('El denominador no puede ser 0.');
    }
    if (numerator == 0) return '0';

    final isNegative = (numerator < 0) ^ (denominator < 0);
    final absNum = numerator.abs();
    final absDen = denominator.abs();

    if (absDen == 1) {
      return isNegative ? '-$absNum' : '$absNum';
    }
    return isNegative ? '-\\frac{$absNum}{$absDen}' : '\\frac{$absNum}{$absDen}';
  }

  /// Formatea y simplifica al máximo la fracción `numerator / denominator`.
  static String simplifiedFraction(int numerator, int denominator) {
    return Rational.raw(numerator, denominator).simplify().toLatex();
  }

  /// Formatea un radical `multiplier * \sqrt{radicand}` limpio:
  /// sin `1\sqrt{...}`, sin `a\sqrt{1}` y devolviendo `'0'` si el radicando o multiplicador es `0`.
  static String radical(int multiplier, int radicand) {
    if (multiplier == 0 || radicand == 0) return '0';
    if (radicand == 1) return '$multiplier';
    if (multiplier == 1) return '\\sqrt{$radicand}';
    if (multiplier == -1) return '-\\sqrt{$radicand}';
    return '$multiplier\\sqrt{$radicand}';
  }

  /// Extrae cuadrados perfectos de la raíz cuadrada de un entero [n] >= 0:
  /// `18` -> `(outside: 3, inside: 2, isExactSquare: false, groupedLatex: '3^{2} \\cdot 2')`.
  static ({int outside, int inside, bool isExactSquare, String groupedLatex})
      decomposeIntSqrt(int n) {
    if (n < 0) {
      throw ArgumentError('Raíz cuadrada real requiere entero >= 0 ($n).');
    }
    if (n == 0 || n == 1) {
      return (outside: n, inside: 1, isExactSquare: true, groupedLatex: '$n');
    }
    final factors = Rational.primeFactorsMap(n);
    final keys = factors.keys.toList()..sort();
    int outside = 1;
    int inside = 1;
    final groupedParts = <String>[];
    for (final prime in keys) {
      final exp = factors[prime]!;
      final pairs = exp ~/ 2;
      final rem = exp % 2;
      for (int i = 0; i < pairs; i++) {
        outside *= prime;
        groupedParts.add('$prime^{2}');
      }
      if (rem == 1) {
        inside *= prime;
        groupedParts.add('$prime');
      }
    }
    return (
      outside: outside,
      inside: inside,
      isExactSquare: inside == 1,
      groupedLatex: groupedParts.join(r' \cdot '),
    );
  }

  /// Simplifica la raíz cuadrada de un [Rational] no negativo (`\sqrt{p/q}` -> radical o fracción racionalizada).
  static String rationalSqrtLatex(Rational radicand) {
    if (radicand.isNegative) {
      throw ArgumentError(
        'No existe raíz cuadrada real de un racional negativo: $radicand',
      );
    }
    if (radicand.isZero) return '0';

    final p = radicand.numerator;
    final q = radicand.denominator;
    final prod = p * q;
    final decomp = decomposeIntSqrt(prod);
    final coeff = Rational(decomp.outside, q);

    if (decomp.inside == 1) {
      return coeff.toLatex();
    }
    if (coeff.denominator == 1) {
      return radical(coeff.numerator, decomp.inside);
    }
    final numStr = coeff.numerator == 1 ? '' : '${coeff.numerator}';
    return '\\frac{$numStr\\sqrt{${decomp.inside}}}{${coeff.denominator}}';
  }

  /// Normaliza una cadena para usarla dentro de `\text{...}` en `flutter_math_fork`
  /// eliminando tildes y eñes que rompen KaTeX/math_fork.
  static String asciiText(String text) {
    return text
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('ñ', 'n')
        .replaceAll('Ñ', 'N');
  }
}
