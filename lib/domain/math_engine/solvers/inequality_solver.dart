import 'dart:math' as math;

import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import 'linear_equation_solver.dart';

/// Sentido de una desigualdad matemática.
enum InequalitySign {
  less('<'),
  lessOrEqual(r'\le'),
  greater('>'),
  greaterOrEqual(r'\ge');

  final String latex;
  const InequalitySign(this.latex);

  /// Símbolo legible en botones y vistas rápidas.
  String get symbol => switch (this) {
        InequalitySign.less => '<',
        InequalitySign.lessOrEqual => '≤',
        InequalitySign.greater => '>',
        InequalitySign.greaterOrEqual => '≥',
      };

  /// Indica si la desigualdad es estricta (extremos abiertos con paréntesis).
  bool get isStrict => switch (this) {
        InequalitySign.less || InequalitySign.greater => true,
        InequalitySign.lessOrEqual || InequalitySign.greaterOrEqual => false,
      };

  /// Devuelve el sentido opuesto al multiplicar o dividir por un número negativo.
  InequalitySign flipped() => switch (this) {
        InequalitySign.less => InequalitySign.greater,
        InequalitySign.lessOrEqual => InequalitySign.greaterOrEqual,
        InequalitySign.greater => InequalitySign.less,
        InequalitySign.greaterOrEqual => InequalitySign.lessOrEqual,
      };

  /// Comprueba si un signo (`-1`, `0`, `+1`) respecto a `0` satisface la desigualdad.
  bool matchesSign(int sign) => switch (this) {
        InequalitySign.less => sign < 0,
        InequalitySign.lessOrEqual => sign <= 0,
        InequalitySign.greater => sign > 0,
        InequalitySign.greaterOrEqual => sign >= 0,
      };

  /// Compara dos racionales `lhs` y `rhs` según el sentido de la desigualdad.
  bool compareRationals(Rational lhs, Rational rhs) {
    final diff = lhs - rhs;
    return matchesSign(diff.numerator.sign);
  }

  /// Parsea un operador de desigualdad (`<`, `<=`, `≤`, `\le`, `>`, `>=`, `≥`, `\ge`).
  static InequalitySign? tryParse(String token) => switch (token.trim()) {
        '<' => InequalitySign.less,
        '<=' || '≤' || r'\le' || r'\leq' => InequalitySign.lessOrEqual,
        '>' => InequalitySign.greater,
        '>=' || '≥' || r'\ge' || r'\geq' => InequalitySign.greaterOrEqual,
        _ => null,
      };
}

class InequalitySolver {
  /// Resuelve una inecuación escrita como cadena de texto (de 1.º o 2.º grado).
  ///
  /// Ejemplos admitidos:
  /// - `-2x + 4 < 10`
  /// - `(x - 2)/3 - (x + 1)/4 <= 2`
  /// - `x^2 - 4x + 3 <= 0`
  static StepByStepResolution solveString(
    String rawInput, {
    InequalitySign? fallbackSign,
  }) {
    final cleaned = rawInput
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('\u2212', '-')
        .replaceAll(r'\cdot', '*')
        .replaceAll('·', '*')
        .replaceAll('×', '*')
        .replaceAll(r'\left(', '(')
        .replaceAll(r'\right)', ')')
        .replaceAll('²', '^2')
        .replaceAll('X', 'x');

    if (cleaned.isEmpty || cleaned == '0') {
      throw const FormatException('Escribe una inecuación válida.');
    }

    final split = _splitByInequalitySign(cleaned, fallbackSign: fallbackSign);
    final lhs = split.lhs;
    final rhs = split.rhs;
    final sign = split.sign;

    // Detectar si contiene grado 2 (x^2)
    if (lhs.contains('x^2') || rhs.contains('x^2')) {
      final leftPoly = _parseQuadraticSide(lhs);
      final rightPoly = _parseQuadraticSide(rhs);
      final a = leftPoly.a - rightPoly.a;
      final b = leftPoly.b - rightPoly.b;
      final c = leftPoly.c - rightPoly.c;
      final customOrig = '${_formatSideFromRawPolyOrFallback(lhs)} ${sign.latex} ${_formatSideFromRawPolyOrFallback(rhs)}';
      if (a == 0) {
        return solveLinearTerms(
          leftTerms: [LinearTerm(xCoeff: b, constant: c)],
          rightTerms: const [LinearTerm(xCoeff: 0, constant: 0)],
          sign: sign,
          customOriginalLatex: customOrig,
        );
      }
      return solveQuadratic(
        a: a,
        b: b,
        c: c,
        sign: sign,
        customOriginalLatex: customOrig,
      );
    }

    // Inecuación lineal con posibles fracciones o paréntesis
    final leftTerms = _parseLinearSide(lhs);
    final rightTerms = rhs == '0'
        ? <LinearTerm>[const LinearTerm(xCoeff: 0, constant: 0)]
        : _parseLinearSide(rhs);

    final effectiveLeft = leftTerms.isEmpty
        ? [const LinearTerm(xCoeff: 0, constant: 0)]
        : leftTerms;
    final effectiveRight = rightTerms.isEmpty
        ? [const LinearTerm(xCoeff: 0, constant: 0)]
        : rightTerms;

    return solveLinearTerms(
      leftTerms: effectiveLeft,
      rightTerms: effectiveRight,
      sign: sign,
      customOriginalLatex:
          '${_formatLinearSideLatex(effectiveLeft)} ${sign.latex} ${_formatLinearSideLatex(effectiveRight)}',
    );
  }

  /// Resuelve una inecuación de 1.º grado en forma `ax + b ≶ cx + d`.
  static StepByStepResolution solveLinearCoeffs({
    required int a,
    int b = 0,
    int c = 0,
    int d = 0,
    required InequalitySign sign,
  }) {
    return solveLinearTerms(
      leftTerms: [LinearTerm(xCoeff: a, constant: b)],
      rightTerms: [LinearTerm(xCoeff: c, constant: d)],
      sign: sign,
    );
  }

  /// Resuelve una inecuación de 1.º grado con fracciones paso a paso.
  static StepByStepResolution solveLinearTerms({
    required List<LinearTerm> leftTerms,
    required List<LinearTerm> rightTerms,
    required InequalitySign sign,
    String? customOriginalLatex,
  }) {
    final originalLatex = customOriginalLatex ??
        '${_formatLinearSideLatex(leftTerms)} ${sign.latex} ${_formatLinearSideLatex(rightTerms)}';
    final List<MathStep> steps = [];

    final allDenoms = <int>{
      ...leftTerms.map((t) => t.denominator),
      ...rightTerms.map((t) => t.denominator),
    }..remove(1);

    final int commonDen =
        allDenoms.isEmpty ? 1 : allDenoms.fold<int>(1, _lcm);

    int lhsX = 0;
    int lhsConst = 0;
    for (final t in leftTerms) {
      final mult = (commonDen ~/ t.denominator) * (t.isSubtract ? -1 : 1);
      lhsX += t.xCoeff * mult;
      lhsConst += t.constant * mult;
    }

    int rhsX = 0;
    int rhsConst = 0;
    for (final t in rightTerms) {
      final mult = (commonDen ~/ t.denominator) * (t.isSubtract ? -1 : 1);
      rhsX += t.xCoeff * mult;
      rhsConst += t.constant * mult;
    }

    // Paso opcional si hay denominadores
    if (commonDen > 1) {
      final leftLhs = AlgebraicLatexFormatter.linearExpression(lhsX, lhsConst);
      final rightRhs = AlgebraicLatexFormatter.linearExpression(rhsX, rhsConst);
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Quitar denominadores (m.c.m. = $commonDen)',
          latexExpression: '$leftLhs ${sign.latex} $rightRhs',
          pedagogicalNote:
              'Multiplicamos toda la inecuación por m.c.m. = $commonDen. '
              'Como $commonDen es positivo, el sentido de la desigualdad (${sign.symbol}) se mantiene.',
        ),
      );
    }

    final int netX = lhsX - rhsX;
    final int netNum = rhsConst - lhsConst;

    // Paso: transposición de términos si hay x en el lado derecho o constante en el izquierdo
    if (lhsConst != 0 || rhsX != 0) {
      final leftPart =
          '${AlgebraicLatexFormatter.monomialTerm(lhsX, 'x', isFirst: true)}'
          '${AlgebraicLatexFormatter.signedMonomialAddition(-rhsX)}'
          .trim();
      final rightPart =
          '${AlgebraicLatexFormatter.constantTerm(rhsConst, isFirst: true)}'
          '${AlgebraicLatexFormatter.signedConstantAddition(-lhsConst)}'
          .trim();

      final groupedLeft = leftPart.isEmpty ? '0' : leftPart;
      final groupedRight = rightPart.isEmpty ? '0' : rightPart;
      final simplifiedLhs = AlgebraicLatexFormatter.monomialTerm(netX, 'x');
      final dispLhs = simplifiedLhs.isEmpty ? '0' : simplifiedLhs;

      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Agrupar términos con x y números',
          latexExpression:
              '$groupedLeft ${sign.latex} $groupedRight \\implies $dispLhs ${sign.latex} $netNum',
          pedagogicalNote:
              'Pasamos los términos con x al primer miembro y los términos independientes al segundo cambiando su signo. Después reducimos términos semejantes.',
        ),
      );
    } else if (steps.isEmpty) {
      final dispLhs = AlgebraicLatexFormatter.monomialTerm(netX, 'x');
      steps.add(
        MathStep(
          index: 1,
          shortTitle: 'Inecuación ya agrupada',
          latexExpression: '${dispLhs.isEmpty ? '0' : dispLhs} ${sign.latex} $netNum',
          pedagogicalNote:
              'Las incógnitas ya están agrupadas a la izquierda y los números a la derecha.',
        ),
      );
    }

    // Caso degenerado netX == 0
    if (netX == 0) {
      final bool holds = sign.compareRationals(Rational(0), Rational(netNum));
      final intervalLatex = holds ? r'(-\infty, +\infty)' : r'\emptyset';
      final resultText = holds
          ? r'\text{Todos los reales } \mathbb{R}'
          : r'\text{Sin solucion}';

      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: holds
              ? 'Desigualdad siempre cierta (Identidad)'
              : 'Desigualdad imposible (Sin solución)',
          latexExpression: '0 ${sign.latex} $netNum \\implies $resultText \\quad ($intervalLatex)',
          pedagogicalNote: holds
              ? 'La incógnita desaparece y queda una desigualdad verdadera para cualquier x real: solución (-∞, +∞).'
              : 'La incógnita desaparece y queda una desigualdad falsa: el conjunto solución es vacío (∅).',
          warningTrick: holds
              ? null
              : 'Cuando las incógnitas se anulan y queda una desigualdad falsa (como 0 < -3), no existe solución real (∅).',
        ),
      );

      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: intervalLatex,
        decimalApproxLatex: intervalLatex,
      );
    }

    // Despeje de x con regla crítica del signo negativo
    final Rational solution = Rational.raw(netNum, netX).simplify();
    final InequalitySign finalSign;
    final String intervalLatex = _formatHalfLineInterval(
      boundaryLatex: solution.toLatex(),
      sign: netX < 0 ? sign.flipped() : sign,
    );

    if (netX < 0) {
      finalSign = sign.flipped();
      final solLatex = solution.toLatex();
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Dividir por número negativo e invertir el signo',
          latexExpression:
              'x ${finalSign.latex} \\frac{$netNum}{$netX} \\implies x ${finalSign.latex} $solLatex',
          pedagogicalNote:
              'Al despejar x dividiendo entre $netX (negativo), la desigualdad invierte su sentido de ${sign.symbol} a ${finalSign.symbol}.',
          warningTrick:
              'Al dividir o multiplicar ambos lados de una inecuación por un número negativo, el signo de la desigualdad se invierte (${sign.symbol} → ${finalSign.symbol}).',
        ),
      );
    } else {
      finalSign = sign;
      if (netX != 1) {
        final solLatex = solution.toLatex();
        steps.add(
          MathStep(
            index: steps.length + 1,
            shortTitle: 'Despejar x dividiendo entre $netX',
            latexExpression:
                'x ${finalSign.latex} \\frac{$netNum}{$netX} \\implies x ${finalSign.latex} $solLatex',
            pedagogicalNote:
                'Dividimos ambos lados entre $netX (positivo), por lo que el signo ${finalSign.symbol} se mantiene igual.',
          ),
        );
      }
    }

    final solLatex = solution.toLatex();
    final solDecLatex = solution.toDecimalLatex();
    final ineqResultLatex = 'x ${finalSign.latex} $solLatex';
    final bracketExplain = finalSign.isStrict
        ? 'Como el signo es estricto (${finalSign.symbol}), el extremo no se incluye y lleva paréntesis abierto ( ). El infinito siempre lleva paréntesis.'
        : 'Como el signo incluye el igual (${finalSign.symbol}), el extremo sí se incluye y lleva corchete cerrado [ ]. El infinito siempre lleva paréntesis.';

    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Resultado en desigualdad e intervalo',
        latexExpression: '$ineqResultLatex \\implies x \\in $intervalLatex',
        pedagogicalNote: bracketExplain,
      ),
    );

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: '$ineqResultLatex, \\; $intervalLatex',
      decimalApproxLatex: 'x ${finalSign.latex} $solDecLatex, \\; $intervalLatex',
    );
  }

  /// Resuelve una inecuación de 2.º grado `ax² + bx + c ≶ 0` con tabla de signos.
  static StepByStepResolution solveQuadratic({
    required int a,
    required int b,
    required int c,
    required InequalitySign sign,
    String? customOriginalLatex,
  }) {
    if (a == 0) {
      return solveLinearTerms(
        leftTerms: [LinearTerm(xCoeff: b, constant: c)],
        rightTerms: const [LinearTerm(xCoeff: 0, constant: 0)],
        sign: sign,
        customOriginalLatex: customOriginalLatex,
      );
    }

    final originalLatex = customOriginalLatex ??
        '${AlgebraicLatexFormatter.quadraticExpression(a, b, c)} ${sign.latex} 0';
    final List<MathStep> steps = [];
    final int discriminant = b * b - 4 * a * c;

    // -----------------------------------------------------------------
    // CASO 1: Dos raíces reales distintas (Δ > 0)
    // -----------------------------------------------------------------
    if (discriminant > 0) {
      final roots = _computeOrderedQuadraticRoots(a, b, discriminant);
      final r1 = roots.$1;
      final r2 = roots.$2;

      final eqLatex = '${AlgebraicLatexFormatter.quadraticExpression(a, b, c)} = 0';
      steps.add(
        MathStep(
          index: 1,
          shortTitle: 'Resolver la ecuación asociada (= 0)',
          latexExpression:
              '$eqLatex \\implies \\Delta = $discriminant > 0 \\implies x_1 = ${r1.latex}, \\; x_2 = ${r2.latex}',
          pedagogicalNote:
              'Igualamos a cero para localizar los puntos críticos que dividen la recta real en tres intervalos: (-∞, x₁), (x₁, x₂) y (x₂, +∞).',
        ),
      );

      // Valores de prueba limpios en cada uno de los 3 tramos
      final t0 = _pickTestPoint(low: null, high: r1.approx);
      final t1 = _pickTestPoint(low: r1.approx, high: r2.approx);
      final t2 = _pickTestPoint(low: r2.approx, high: null);

      final v0 = _evalPolyAt(a, b, c, t0);
      final v1 = _evalPolyAt(a, b, c, t1);
      final v2 = _evalPolyAt(a, b, c, t2);

      final s0 = v0.numerator >= 0 ? '+' : '-';
      final s1 = v1.numerator >= 0 ? '+' : '-';
      final s2 = v2.numerator >= 0 ? '+' : '-';

      final signTableLatex =
          '\\begin{array}{c|ccc}\n'
          '\\text{Intervalo} & (-\\infty, ${r1.latex}) & (${r1.latex}, ${r2.latex}) & (${r2.latex}, +\\infty) \\\\\n'
          '\\hline\n'
          '\\text{Prueba } x & ${t0.toLatex()} & ${t1.toLatex()} & ${t2.toLatex()} \\\\\n'
          '\\text{Valor } P(x) & ${v0.toLatex()} & ${v1.toLatex()} & ${v2.toLatex()} \\\\\n'
          '\\text{Signo} & $s0 & $s1 & $s2\n'
          '\\end{array}';

      steps.add(
        MathStep(
          index: 2,
          shortTitle: 'Tabla de signos en la recta real',
          latexExpression: signTableLatex,
          pedagogicalNote:
              'Elegimos un valor de prueba en cada tramo, lo sustituimos en P(x) y anotamos si el resultado es positivo (+) o negativo (-).',
        ),
      );

      final bool wantOuter = sign.matchesSign(a > 0 ? 1 : -1);
      final String solInterval;
      if (wantOuter) {
        final leftBracket = sign.isStrict ? ')' : ']';
        final rightBracket = sign.isStrict ? '(' : '[';
        solInterval =
            '(-\\infty, ${r1.latex}$leftBracket \\cup $rightBracket${r2.latex}, +\\infty)';
      } else {
        final leftBracket = sign.isStrict ? '(' : '[';
        final rightBracket = sign.isStrict ? ')' : ']';
        solInterval = '$leftBracket${r1.latex}, ${r2.latex}$rightBracket';
      }

      final wantedSymbol =
          (sign == InequalitySign.greater || sign == InequalitySign.greaterOrEqual)
              ? 'positivos (+)'
              : 'negativos (-)';
      final boundExplain = sign.isStrict
          ? 'Como la desigualdad es estricta (${sign.symbol}), los extremos quedan abiertos con paréntesis ( ).'
          : 'Como incluye el igual (${sign.symbol}), las raíces donde P(x)=0 se incluyen con corchetes [ ].';

      steps.add(
        MathStep(
          index: 3,
          shortTitle: 'Solución en notación de intervalos',
          latexExpression: 'x \\in $solInterval',
          pedagogicalNote:
              'Seleccionamos los tramos $wantedSymbol de la tabla. $boundExplain',
        ),
      );

      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: solInterval,
        decimalApproxLatex: solInterval,
      );
    }

    // -----------------------------------------------------------------
    // CASO 2: Raíz real doble (Δ = 0)
    // -----------------------------------------------------------------
    if (discriminant == 0) {
      final root = Rational.raw(-b, 2 * a).simplify();
      final rLatex = root.toLatex();

      steps.add(
        MathStep(
          index: 1,
          shortTitle: 'Resolver la ecuación asociada (Δ = 0)',
          latexExpression:
              '${AlgebraicLatexFormatter.quadraticExpression(a, b, c)} = 0 \\implies \\Delta = 0 \\implies x_0 = $rLatex',
          pedagogicalNote:
              'El discriminante es nulo: existe una única raíz doble x₀ = $rLatex donde la parábola toca el eje X sin cambiar de signo a los lados.',
        ),
      );

      final t0 = _pickTestPoint(low: null, high: root.toDouble());
      final t1 = _pickTestPoint(low: root.toDouble(), high: null);
      final v0 = _evalPolyAt(a, b, c, t0);
      final v1 = _evalPolyAt(a, b, c, t1);
      final s0 = v0.numerator >= 0 ? '+' : '-';
      final s1 = v1.numerator >= 0 ? '+' : '-';

      final signTableLatex =
          '\\begin{array}{c|cc}\n'
          '\\text{Intervalo} & (-\\infty, $rLatex) & ($rLatex, +\\infty) \\\\\n'
          '\\hline\n'
          '\\text{Prueba } x & ${t0.toLatex()} & ${t1.toLatex()} \\\\\n'
          '\\text{Signo} & $s0 & $s1\n'
          '\\end{array}';

      steps.add(
        MathStep(
          index: 2,
          shortTitle: 'Tabla de signos alrededor de la raíz doble',
          latexExpression: signTableLatex,
          pedagogicalNote:
              'A ambos lados de una raíz doble el signo es constante e igual al del coeficiente a = $a.',
        ),
      );

      final bool outerSatisfies = sign.matchesSign(a > 0 ? 1 : -1);
      final bool rootSatisfies = sign.matchesSign(0);
      final String solInterval;
      if (outerSatisfies && rootSatisfies) {
        solInterval = r'(-\infty, +\infty)';
      } else if (outerSatisfies && !rootSatisfies) {
        solInterval = '(-\\infty, $rLatex) \\cup ($rLatex, +\\infty)';
      } else if (!outerSatisfies && rootSatisfies) {
        solInterval = '\\left\\{$rLatex\\right\\}';
      } else {
        solInterval = r'\emptyset';
      }

      steps.add(
        MathStep(
          index: 3,
          shortTitle: 'Solución en intervalos',
          latexExpression: 'x \\in $solInterval',
          pedagogicalNote:
              'Combinamos los tramos válidos con la comprobación de si la raíz x₀ = $rLatex cumple la desigualdad en el punto exacto.',
          warningTrick: solInterval == r'\emptyset'
              ? 'Un cuadrado real nunca puede ser estrictamente negativo.'
              : null,
        ),
      );

      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: solInterval,
        decimalApproxLatex: solInterval,
      );
    }

    // -----------------------------------------------------------------
    // CASO 3: Sin raíces reales (Δ < 0)
    // -----------------------------------------------------------------
    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Ecuación asociada sin raíces reales (Δ < 0)',
        latexExpression:
            '\\Delta = $discriminant < 0 \\implies \\text{Sin raices reales}',
        pedagogicalNote:
            'Al no cortar al eje X, el polinomio mantiene siempre el mismo signo en toda la recta real (-∞, +∞).',
      ),
    );

    final vTest = _evalPolyAt(a, b, c, Rational(0));
    final signStr = a > 0 ? '+' : '-';
    final tableLatex =
        '\\begin{array}{c|c}\n'
        '\\text{Intervalo} & (-\\infty, +\\infty) \\\\\n'
        '\\hline\n'
        '\\text{Prueba } x & 0 \\\\\n'
        '\\text{Valor } P(0) & ${vTest.toLatex()} \\\\\n'
        '\\text{Signo} & $signStr\n'
        '\\end{array}';

    steps.add(
      MathStep(
        index: 2,
        shortTitle: 'Tabla de signo único en toda la recta',
        latexExpression: tableLatex,
        pedagogicalNote:
            'Evaluando en cualquier punto (por ejemplo x = 0), vemos que P(x) siempre tiene signo $signStr.',
      ),
    );

    final bool alwaysTrue = sign.matchesSign(a > 0 ? 1 : -1);
    final String solInterval = alwaysTrue ? r'(-\infty, +\infty)' : r'\emptyset';

    steps.add(
      MathStep(
        index: 3,
        shortTitle: 'Solución final',
        latexExpression: alwaysTrue
            ? r'x \in (-\infty, +\infty) = \mathbb{R}'
            : r'\text{Solucion: } \emptyset',
        pedagogicalNote: alwaysTrue
            ? 'El signo del polinomio cumple la desigualdad en cualquier x real: solución (-∞, +∞).'
            : 'Ningún número real hace que el signo cumpla la desigualdad: el conjunto solución es vacío (∅).',
      ),
    );

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: solInterval,
      decimalApproxLatex: solInterval,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers privados de parseo y formato
  // ---------------------------------------------------------------------------

  static ({String lhs, String rhs, InequalitySign sign}) _splitByInequalitySign(
    String cleaned, {
    InequalitySign? fallbackSign,
  }) {
    const patterns = [
      '<=',
      '>=',
      '≤',
      '≥',
      r'\leq',
      r'\geq',
      r'\le',
      r'\ge',
      '<',
      '>',
    ];
    for (final pat in patterns) {
      final idx = cleaned.indexOf(pat);
      if (idx != -1) {
        // Evitar detectar '>' como si fuera '>=' si ya buscamos patrones más largos antes
        final sign = InequalitySign.tryParse(pat)!;
        final lhs = cleaned.substring(0, idx);
        final rhs = cleaned.substring(idx + pat.length);
        if (lhs.isEmpty) {
          throw const FormatException('Falta el primer miembro de la inecuación.');
        }
        return (
          lhs: lhs,
          rhs: rhs.isEmpty ? '0' : rhs,
          sign: sign,
        );
      }
    }
    if (fallbackSign != null) {
      return (lhs: cleaned, rhs: '0', sign: fallbackSign);
    }
    throw const FormatException('Falta el signo de desigualdad (<, ≤, > o ≥).');
  }

  static List<LinearTerm> _parseLinearSide(String raw) {
    final s = _replaceLatexFractions(raw);
    if (s.isEmpty) return const [];
    final terms = <LinearTerm>[];

    for (final (:isSubtract, :body) in _splitTopLevelAdditive(s)) {
      int depth = 0;
      int slashIndex = -1;
      for (int i = 0; i < body.length; i++) {
        if (body[i] == '(') {
          depth++;
        } else if (body[i] == ')') {
          depth--;
        } else if (depth == 0 && body[i] == '/') {
          if (slashIndex != -1) {
            throw FormatException('División múltiple no soportada: $body');
          }
          slashIndex = i;
        }
      }

      int den = 1;
      String numStr = body;
      if (slashIndex != -1) {
        numStr = body.substring(0, slashIndex);
        final rawDen = _unwrapOuterParens(body.substring(slashIndex + 1));
        final parsedDen = int.tryParse(rawDen);
        if (parsedDen == null || parsedDen <= 0) {
          throw FormatException('El denominador debe ser entero positivo: $rawDen');
        }
        den = parsedDen;
      }

      final parsed = _parseLinearExpr(numStr);
      terms.add(
        LinearTerm(
          xCoeff: parsed.xCoeff,
          constant: parsed.constant,
          denominator: den,
          isSubtract: isSubtract,
        ),
      );
    }
    return terms;
  }

  static ({int a, int b, int c}) _parseQuadraticSide(String raw) {
    final normalized = raw.replaceAll('*x', 'x');
    final unwrapped = _unwrapOuterParens(normalized);
    if (unwrapped.isEmpty || unwrapped == '0') {
      return (a: 0, b: 0, c: 0);
    }
    int a = 0;
    int b = 0;
    int c = 0;
    for (final (:isSubtract, :body) in _splitTopLevelAdditive(unwrapped)) {
      final sign = isSubtract ? -1 : 1;
      if (body == 'x^2') {
        a += sign;
      } else if (RegExp(r'^(-?\d+)x\^2$').hasMatch(body)) {
        a += sign * int.parse(body.substring(0, body.length - 3));
      } else if (body == 'x') {
        b += sign;
      } else if (RegExp(r'^(-?\d+)x$').hasMatch(body)) {
        b += sign * int.parse(body.substring(0, body.length - 1));
      } else {
        final numVal = int.tryParse(body);
        if (numVal == null) {
          throw FormatException('Término no reconocido en inecuación de 2.º grado: $body');
        }
        c += sign * numVal;
      }
    }
    return (a: a, b: b, c: c);
  }

  static String _formatSideFromRawPolyOrFallback(String raw) {
    try {
      final p = _parseQuadraticSide(raw);
      return AlgebraicLatexFormatter.quadraticExpression(p.a, p.b, p.c);
    } catch (_) {
      return raw;
    }
  }

  static ({int xCoeff, int constant}) _parseLinearExpr(String expr) {
    final unwrapped = _unwrapOuterParens(expr);
    if (unwrapped.isEmpty) {
      throw const FormatException('Expresión vacía en inecuación.');
    }
    final addTerms = _splitTopLevelAdditive(unwrapped);
    int totalX = 0;
    int totalConst = 0;
    for (final (:isSubtract, :body) in addTerms) {
      final sub = _parseLinearProduct(body);
      final sign = isSubtract ? -1 : 1;
      totalX += sign * sub.xCoeff;
      totalConst += sign * sub.constant;
    }
    return (xCoeff: totalX, constant: totalConst);
  }

  static ({int xCoeff, int constant}) _parseLinearProduct(String term) {
    final withImplicit = term
        .replaceAllMapped(RegExp(r'(\d)\('), (m) => '${m[1]}*(')
        .replaceAll(')(', ')*(')
        .replaceAllMapped(RegExp(r'\)(\d|x)'), (m) => ')*${m[1]}');

    final factors = <String>[];
    int depth = 0;
    int start = 0;
    for (int i = 0; i < withImplicit.length; i++) {
      final ch = withImplicit[i];
      if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
      } else if (depth == 0 && ch == '*') {
        final part = withImplicit.substring(start, i);
        if (part.isEmpty) throw FormatException('Producto inválido: $term');
        factors.add(part);
        start = i + 1;
      }
    }
    final tail = withImplicit.substring(start);
    if (tail.isEmpty) throw FormatException('Producto incompleto: $term');
    factors.add(tail);

    var acc = (xCoeff: 0, constant: 1);
    for (final f in factors) {
      final parsed = f.startsWith('(')
          ? _parseLinearExpr(f)
          : _parseSingleMonomial(f);
      if (acc.xCoeff != 0 && parsed.xCoeff != 0) {
        throw const FormatException('Producto de x detectado fuera de modo 2.º grado.');
      }
      acc = (
        xCoeff: acc.xCoeff * parsed.constant + acc.constant * parsed.xCoeff,
        constant: acc.constant * parsed.constant,
      );
    }
    return acc;
  }

  static ({int xCoeff, int constant}) _parseSingleMonomial(String token) {
    if (token == 'x') return (xCoeff: 1, constant: 0);
    if (token == '-x') return (xCoeff: -1, constant: 0);
    final xMatch = RegExp(r'^(-?\d+)x$').firstMatch(token);
    if (xMatch != null) {
      return (xCoeff: int.parse(xMatch.group(1)!), constant: 0);
    }
    final numVal = int.tryParse(token);
    if (numVal != null) {
      return (xCoeff: 0, constant: numVal);
    }
    throw FormatException('Término no reconocido en inecuación: $token');
  }

  static List<({bool isSubtract, String body})> _splitTopLevelAdditive(String s) {
    final result = <({bool isSubtract, String body})>[];
    if (s.isEmpty) return result;
    int depth = 0;
    int start = 0;
    bool isSub = false;
    int scanStart = 0;
    if (s[0] == '+' || s[0] == '-') {
      isSub = s[0] == '-';
      start = 1;
      scanStart = 1;
    }
    for (int i = scanStart; i < s.length; i++) {
      final ch = s[i];
      if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
      } else if (depth == 0 &&
          (ch == '+' || ch == '-') &&
          i > start &&
          s[i - 1] != '*' &&
          s[i - 1] != '/') {
        final body = s.substring(start, i);
        if (body.isEmpty) {
          throw const FormatException('Operador consecutivo inválido.');
        }
        result.add((isSubtract: isSub, body: body));
        isSub = ch == '-';
        start = i + 1;
      }
    }
    final tail = s.substring(start);
    if (tail.isEmpty) {
      throw const FormatException('Falta término tras signo.');
    }
    result.add((isSubtract: isSub, body: tail));
    return result;
  }

  static String _replaceLatexFractions(String input) {
    var s = input;
    while (true) {
      final idx = s.indexOf(r'\frac{');
      if (idx == -1) break;
      final numEnd = _findMatchingBrace(s, idx + 5);
      if (numEnd == -1 || numEnd + 1 >= s.length || s[numEnd + 1] != '{') break;
      final denEnd = _findMatchingBrace(s, numEnd + 1);
      if (denEnd == -1) break;
      final n = s.substring(idx + 6, numEnd);
      final d = s.substring(numEnd + 2, denEnd);
      s = '${s.substring(0, idx)}($n)/($d)${s.substring(denEnd + 1)}';
    }
    return s;
  }

  static int _findMatchingBrace(String s, int openIdx) {
    int depth = 0;
    for (int i = openIdx; i < s.length; i++) {
      if (s[i] == '{') depth++;
      if (s[i] == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  static String _unwrapOuterParens(String s) {
    var cur = s;
    while (cur.length >= 2 && cur.startsWith('(') && cur.endsWith(')')) {
      int depth = 0;
      bool whole = true;
      for (int i = 0; i < cur.length; i++) {
        if (cur[i] == '(') depth++;
        if (cur[i] == ')') depth--;
        if (depth == 0 && i < cur.length - 1) {
          whole = false;
          break;
        }
      }
      if (!whole) break;
      cur = cur.substring(1, cur.length - 1);
    }
    return cur;
  }

  static String _formatLinearSideLatex(List<LinearTerm> terms) {
    if (terms.isEmpty) return '0';
    final buffer = StringBuffer();
    for (int i = 0; i < terms.length; i++) {
      String part = terms[i].toLatex().trim();
      if (i == 0) {
        if (part.startsWith('+ ')) part = part.substring(2).trimLeft();
        buffer.write(part);
      } else {
        if (!part.startsWith('+') && !part.startsWith('-')) {
          buffer.write(' + $part');
        } else if (part.startsWith('-') && !part.startsWith('- ')) {
          buffer.write(' - ${part.substring(1)}');
        } else {
          buffer.write(' $part');
        }
      }
    }
    return buffer.toString();
  }

  static String _formatHalfLineInterval({
    required String boundaryLatex,
    required InequalitySign sign,
  }) =>
      switch (sign) {
        InequalitySign.less => '(-\\infty, $boundaryLatex)',
        InequalitySign.lessOrEqual => '(-\\infty, $boundaryLatex]',
        InequalitySign.greater => '($boundaryLatex, +\\infty)',
        InequalitySign.greaterOrEqual => '[$boundaryLatex, +\\infty)',
      };

  static int _gcd(int a, int b) {
    a = a.abs();
    b = b.abs();
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a == 0 ? 1 : a;
  }

  static int _lcm(int a, int b) => (a.abs() ~/ _gcd(a, b)) * b.abs();

  static Rational _evalPolyAt(int a, int b, int c, Rational x) =>
      Rational(a) * x * x + Rational(b) * x + Rational(c);

  static Rational _pickTestPoint({double? low, double? high}) {
    if (low == null && high == null) return Rational(0);
    if (low == null) {
      // (-infty, high) -> elegir entero <= floor - 1, prefiriendo 0 o -1 si cabe
      if (0 < high!) return Rational(0);
      return Rational(high.ceil() - 1);
    }
    if (high == null) {
      // (low, +infty)
      if (0 > low) return Rational(0);
      return Rational(low.floor() + 1);
    }
    // Intervalo acotado (low, high): si 0 está dentro, usarlo; si hay otro entero, usarlo
    if (low < 0 && 0 < high) return Rational(0);
    final intFirst = low.floor() + 1;
    if (intFirst < high) {
      // Preferir el entero más cercano a 0 dentro de (low, high)
      final intLast = high.ceil() - 1;
      if (intLast >= intFirst) {
        int best = intFirst;
        for (int v = intFirst; v <= intLast; v++) {
          if (v.abs() < best.abs()) best = v;
        }
        return Rational(best);
      }
    }
    // Si no hay enteros entre medias, tomar punto medio con denominador potencia de 2
    final midDouble = (low + high) / 2.0;
    for (final den in [2, 4, 8, 10]) {
      final candidateNum = (midDouble * den).round();
      final candidateVal = candidateNum / den;
      if (candidateVal > low && candidateVal < high) {
        return Rational.raw(candidateNum, den).simplify();
      }
    }
    return Rational.fromDecimalString(midDouble.toStringAsFixed(2));
  }

  static (_QuadRoot, _QuadRoot) _computeOrderedQuadraticRoots(
    int a,
    int b,
    int discriminant,
  ) {
    final sqrtD = math.sqrt(discriminant);
    final sqrtInt = sqrtD.round();
    if (sqrtInt * sqrtInt == discriminant) {
      final q1 = Rational.raw(-b - sqrtInt, 2 * a).simplify();
      final q2 = Rational.raw(-b + sqrtInt, 2 * a).simplify();
      final list = [
        _QuadRoot(latex: q1.toLatex(), approx: q1.toDouble()),
        _QuadRoot(latex: q2.toLatex(), approx: q2.toDouble()),
      ]..sort((x, y) => x.approx.compareTo(y.approx));
      return (list[0], list[1]);
    }

    // Raíces irracionales exactas simplificadas: (-b ± k√rad) / (2a)
    int outFactor = 1;
    int rad = discriminant;
    for (int f = math.sqrt(discriminant).toInt(); f >= 2; f--) {
      if (discriminant % (f * f) == 0) {
        outFactor = f;
        rad = discriminant ~/ (f * f);
        break;
      }
    }

    final int common = _gcd(_gcd(b.abs(), outFactor), (2 * a).abs());
    final int numB = -b ~/ common;
    final int k = outFactor ~/ common;
    final int den = (2 * a) ~/ common;

    // Normalizar denominador positivo para la presentación LaTeX
    final int normB = den < 0 ? -numB : numB;
    final int normDen = den.abs();

    String formatRoot(int signSqrt) {
      final radicalTerm = k == 1 ? '\\sqrt{$rad}' : '$k\\sqrt{$rad}';
      final top = normB == 0
          ? (signSqrt < 0 ? '-$radicalTerm' : radicalTerm)
          : '$normB ${signSqrt > 0 ? '+' : '-'} $radicalTerm';
      return normDen == 1 ? top : '\\frac{$top}{$normDen}';
    }

    final v1 = (-b - sqrtD) / (2 * a);
    final v2 = (-b + sqrtD) / (2 * a);
    // Si 2*a < 0, v2 < v1
    if (2 * a > 0) {
      return (
        _QuadRoot(latex: formatRoot(-1), approx: v1),
        _QuadRoot(latex: formatRoot(1), approx: v2),
      );
    }
    return (
      _QuadRoot(latex: formatRoot(-1), approx: v2),
      _QuadRoot(latex: formatRoot(1), approx: v1),
    );
  }
}

class _QuadRoot {
  final String latex;
  final double approx;
  const _QuadRoot({required this.latex, required this.approx});
}
