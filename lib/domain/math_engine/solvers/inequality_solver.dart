import 'dart:math' as math;

import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/inequality_models.dart';
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
  static final Expando<Inequality1DVisualData> _visualDataExpando =
      Expando<Inequality1DVisualData>();

  /// Obtiene los datos de renderizado visual asociados a una resolución de inecuación.
  static Inequality1DVisualData? getVisualData(StepByStepResolution res) =>
      _visualDataExpando[res];

  /// Resuelve una inecuación escrita como cadena de texto (de 1.º, 2.º grado o con valor absoluto).
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

    // Detectar si contiene valor absoluto: |...| o \left|...\right|
    if (cleaned.contains('|') || cleaned.contains(r'\left|')) {
      return _solveAbsoluteValue(cleaned, fallbackSign: fallbackSign);
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
      final customOrig =
          '${_formatSideFromRawPolyOrFallback(lhs)} ${sign.latex} ${_formatSideFromRawPolyOrFallback(rhs)}';
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

  /// Resuelve con datos visuales incluidos de forma directa.
  static ({StepByStepResolution resolution, Inequality1DVisualData visualData}) solveWithVisual(
    String rawInput, {
    InequalitySign? fallbackSign,
  }) {
    final res = solveString(rawInput, fallbackSign: fallbackSign);
    final visual = getVisualData(res) ??
        Inequality1DVisualData(
          criticalPoints: const [],
          primaryIntervals: const [],
          solutionLatex: res.exactResultLatex,
        );
    return (resolution: res, visualData: visual);
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

  /// Resuelve una inecuación de 1.º grado con fracciones y términos paso a paso.
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

      final res = StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: intervalLatex,
        decimalApproxLatex: intervalLatex,
      );

      final visualData = Inequality1DVisualData(
        criticalPoints: const [],
        primaryIntervals: holds
            ? const [InequalityInterval(start: double.negativeInfinity, end: double.infinity)]
            : const [],
        solutionLatex: intervalLatex,
      );
      _visualDataExpando[res] = visualData;
      return res;
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

    final res = StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: '$ineqResultLatex, \\; $intervalLatex',
      decimalApproxLatex: 'x ${finalSign.latex} $solDecLatex, \\; $intervalLatex',
    );

    // Generar datos visuales 1D
    final solDouble = solution.toDouble();
    final isLess = finalSign == InequalitySign.less || finalSign == InequalitySign.lessOrEqual;
    final isClosed = !finalSign.isStrict;

    final visualInterval = isLess
        ? InequalityInterval(
            start: double.negativeInfinity,
            end: solDouble,
            includeStart: false,
            includeEnd: isClosed,
            endLabel: solLatex,
          )
        : InequalityInterval(
            start: solDouble,
            end: double.infinity,
            includeStart: isClosed,
            includeEnd: false,
            startLabel: solLatex,
          );

    final visualData = Inequality1DVisualData(
      criticalPoints: [
        CriticalPoint(value: solDouble, label: solLatex, isClosed: isClosed),
      ],
      primaryIntervals: [visualInterval],
      solutionLatex: intervalLatex,
    );

    _visualDataExpando[res] = visualData;
    return res;
  }

  /// Resuelve una inecuación con valor absoluto `|ax + b| ≶ c`.
  static StepByStepResolution _solveAbsoluteValue(
    String raw, {
    InequalitySign? fallbackSign,
  }) {
    final cleaned = raw
        .replaceAll(r'\left|', '|')
        .replaceAll(r'\right|', '|');

    final split = _splitByInequalitySign(cleaned, fallbackSign: fallbackSign);
    final lhs = split.lhs;
    final rhs = split.rhs;
    final sign = split.sign;

    final firstBar = lhs.indexOf('|');
    final secondBar = lhs.indexOf('|', firstBar + 1);

    if (firstBar == -1 || secondBar == -1) {
      throw const FormatException('Falta cerrar la barra de valor absoluto |...|.');
    }

    final inside = lhs.substring(firstBar + 1, secondBar);
    final prefix = lhs.substring(0, firstBar);
    final suffix = lhs.substring(secondBar + 1);

    // Multiplicador k y constante d: k|A| + d
    double k = 1.0;
    if (prefix.isNotEmpty && prefix != '+') {
      if (prefix == '-') {
        k = -1.0;
      } else {
        k = double.tryParse(prefix.replaceAll('*', '')) ?? 1.0;
      }
    }

    double extraConst = 0.0;
    if (suffix.isNotEmpty) {
      extraConst = double.tryParse(suffix) ?? 0.0;
    }

    final rhsVal = double.tryParse(rhs) ?? 0.0;
    final isolatedC = (rhsVal - extraConst) / k;
    final effectiveSign = k < 0 ? sign.flipped() : sign;

    final parsedLinear = _parseLinearExpr(inside);
    final a = parsedLinear.xCoeff;
    final b = parsedLinear.constant;
    final insideLatex = AlgebraicLatexFormatter.linearExpression(a, b);

    final steps = <MathStep>[];
    final originalLatex = '$lhs ${sign.latex} $rhs';

    // Paso 1: Aislar el valor absoluto si había coeficientes fuera
    if (k != 1.0 || extraConst != 0.0) {
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Aislar el valor absoluto',
          latexExpression: '|$insideLatex| ${effectiveSign.latex} ${_fmt(isolatedC)}',
          pedagogicalNote:
              'Dejamos el valor absoluto solo en el primer miembro pasando las sumas restando y dividiendo entre $k. '
              '${k < 0 ? 'Al dividir por un número negativo ($k), el sentido de la desigualdad se invierte.' : ''}',
        ),
      );
    }

    // -------------------------------------------------------------------------
    // CASO 1: |A| < C o |A| <= C
    // -------------------------------------------------------------------------
    if (effectiveSign == InequalitySign.less || effectiveSign == InequalitySign.lessOrEqual) {
      if (isolatedC < 0) {
        steps.add(
          MathStep(
            index: steps.length + 1,
            shortTitle: 'Desigualdad imposible (Sin solución)',
            latexExpression: '|$insideLatex| ${effectiveSign.latex} ${_fmt(isolatedC)} \\implies \\text{Sin solucion} \\quad (\\emptyset)',
            pedagogicalNote:
                'El valor absoluto de cualquier número real es siempre mayor o igual a cero (|A| ≥ 0). Nunca puede ser estrictamente menor ni menor o igual que un número negativo ($isolatedC).',
            warningTrick: 'Un valor absoluto nunca puede ser menor que un número negativo. La solución es el conjunto vacío (∅).',
          ),
        );

        final res = StepByStepResolution(
          originalInputLatex: originalLatex,
          steps: steps,
          exactResultLatex: r'\emptyset',
          decimalApproxLatex: r'\emptyset',
        );
        _visualDataExpando[res] = Inequality1DVisualData(
          criticalPoints: const [],
          primaryIntervals: const [],
          solutionLatex: r'\emptyset',
        );
        return res;
      }

      final isStrict = effectiveSign.isStrict;
      final leftBracket = isStrict ? '(' : '[';
      final rightBracket = isStrict ? ')' : ']';

      // Propiedad: |A| <= C <=> -C <= A <= C
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Propiedad del valor absoluto (|A| ≤ C)',
          latexExpression: '|$insideLatex| ${effectiveSign.latex} ${_fmt(isolatedC)} \\iff -${_fmt(isolatedC)} ${effectiveSign.latex} $insideLatex ${effectiveSign.latex} ${_fmt(isolatedC)}',
          pedagogicalNote:
              'Para cualquier C ≥ 0, la desigualdad |A| ≤ C significa que la expresión A está a una distancia menor o igual que C del origen, es decir, comprendida entre -C y C.',
        ),
      );

      // Resolver las dos ramas:
      // Rama 1: A >= -C <=> ax + b >= -C => ax >= -C - b
      final r1 = (-isolatedC - b) / a;
      // Rama 2: A <= C <=> ax + b <= C => ax <= C - b
      final r2 = (isolatedC - b) / a;

      final minR = math.min(r1, r2);
      final maxR = math.max(r1, r2);
      final minRLatex = _fmt(minR);
      final maxRLatex = _fmt(maxR);

      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Despejar la incógnita x en la desigualdad doble',
          latexExpression:
              '-${_fmt(isolatedC)} - $b ${effectiveSign.latex} ${a}x ${effectiveSign.latex} ${_fmt(isolatedC)} - $b \\implies '
              '$minRLatex ${effectiveSign.latex} x ${effectiveSign.latex} $maxRLatex',
          pedagogicalNote:
              'Restamos $b en los tres miembros y luego dividimos entre $a para despejar la x.',
        ),
      );

      final solInterval = '$leftBracket$minRLatex, $maxRLatex$rightBracket';
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Solución en notación de intervalos',
          latexExpression: 'x \\in $solInterval',
          pedagogicalNote:
              'La solución es el intervalo acotado que contiene todos los números comprendidos entre $minRLatex y $maxRLatex. '
              '${isStrict ? 'Lleva paréntesis ( ) porque los extremos no se incluyen.' : 'Lleva corchetes [ ] porque los extremos sí se incluyen.'}',
        ),
      );

      final res = StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: 'x \\in $solInterval',
        decimalApproxLatex: 'x \\in $solInterval',
      );

      final visualData = Inequality1DVisualData(
        criticalPoints: [
          CriticalPoint(value: minR, label: minRLatex, isClosed: !isStrict),
          CriticalPoint(value: maxR, label: maxRLatex, isClosed: !isStrict),
        ],
        primaryIntervals: [
          InequalityInterval(
            start: minR,
            end: maxR,
            includeStart: !isStrict,
            includeEnd: !isStrict,
            startLabel: minRLatex,
            endLabel: maxRLatex,
          ),
        ],
        solutionLatex: solInterval,
      );

      _visualDataExpando[res] = visualData;
      return res;
    }

    // -------------------------------------------------------------------------
    // CASO 2: |A| > C o |A| >= C
    // -------------------------------------------------------------------------
    if (isolatedC < 0) {
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Desigualdad siempre cierta (Todos los reales)',
          latexExpression: '|$insideLatex| ${effectiveSign.latex} ${_fmt(isolatedC)} \\implies x \\in (-\\infty, +\\infty) = \\mathbb{R}',
          pedagogicalNote:
              'El valor absoluto de cualquier número real es mayor o igual a cero (|A| ≥ 0). Por tanto, siempre es estrictamente mayor que cualquier número negativo ($isolatedC).',
        ),
      );

      final res = StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: r'(-\infty, +\infty)',
        decimalApproxLatex: r'(-\infty, +\infty)',
      );
      _visualDataExpando[res] = Inequality1DVisualData(
        criticalPoints: const [],
        primaryIntervals: const [
          InequalityInterval(start: double.negativeInfinity, end: double.infinity)
        ],
        solutionLatex: r'(-\infty, +\infty)',
      );
      return res;
    }

    final isStrict = effectiveSign.isStrict;
    final leftBracket = isStrict ? ')' : ']';
    final rightBracket = isStrict ? '(' : '[';

    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Propiedad del valor absoluto (|A| ≥ C)',
        latexExpression: '|$insideLatex| ${effectiveSign.latex} ${_fmt(isolatedC)} \\iff $insideLatex ${isStrict ? '<' : r'\le'} -${_fmt(isolatedC)} \\quad \\text{o} \\quad $insideLatex ${isStrict ? '>' : r'\ge'} ${_fmt(isolatedC)}',
        pedagogicalNote:
            'Para cualquier C ≥ 0, la desigualdad |A| ≥ C significa que la expresión A dista al menos C del origen, es decir, está a la izquierda de -C o a la derecha de C.',
      ),
    );

    // Rama 1: A <= -C
    final r1 = (-isolatedC - b) / a;
    // Rama 2: A >= C
    final r2 = (isolatedC - b) / a;

    final minR = math.min(r1, r2);
    final maxR = math.max(r1, r2);
    final minRLatex = _fmt(minR);
    final maxRLatex = _fmt(maxR);

    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Resolver ambas ramas independientes',
        latexExpression:
            'x ${isStrict ? '<' : r'\le'} $minRLatex \\quad \\text{o} \\quad x ${isStrict ? '>' : r'\ge'} $maxRLatex',
        pedagogicalNote:
            'Despejamos x en cada una de las dos ramas. La solución total es la unión de ambas semirrectas disjuntas.',
      ),
    );

    final solInterval = '(-\\infty, $minRLatex$leftBracket \\cup $rightBracket$maxRLatex, +\\infty)';
    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Solución en unión de intervalos',
        latexExpression: 'x \\in $solInterval',
        pedagogicalNote:
            'La solución se compone de dos tramos infinitos separados por el hueco central ($minRLatex, $maxRLatex).',
      ),
    );

    final res = StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: 'x \\in $solInterval',
      decimalApproxLatex: 'x \\in $solInterval',
    );

    final visualData = Inequality1DVisualData(
      criticalPoints: [
        CriticalPoint(value: minR, label: minRLatex, isClosed: !isStrict),
        CriticalPoint(value: maxR, label: maxRLatex, isClosed: !isStrict),
      ],
      primaryIntervals: [
        InequalityInterval(
          start: double.negativeInfinity,
          end: minR,
          includeStart: false,
          includeEnd: !isStrict,
          endLabel: minRLatex,
        ),
        InequalityInterval(
          start: maxR,
          end: double.infinity,
          includeStart: !isStrict,
          includeEnd: false,
          startLabel: maxRLatex,
        ),
      ],
      solutionLatex: solInterval,
    );

    _visualDataExpando[res] = visualData;
    return res;
  }

  /// Resuelve un sistema de 2 o más inecuaciones de 1 incógnita con intersección de intervalos.
  static ({StepByStepResolution resolution, Inequality1DVisualData visualData}) solveSystem1D(
    List<String> rawInequalities,
  ) {
    if (rawInequalities.isEmpty) {
      throw const FormatException('Introduce al menos una inecuación para el sistema.');
    }

    final singleResolutions = <StepByStepResolution>[];
    final visualDataList = <Inequality1DVisualData>[];

    for (final raw in rawInequalities) {
      final res = solveString(raw);
      singleResolutions.add(res);
      final v = getVisualData(res);
      if (v != null) visualDataList.add(v);
    }

    final steps = <MathStep>[];

    // Paso 1 y Paso 2: Resolución de cada inecuación por separado
    for (int i = 0; i < singleResolutions.length; i++) {
      final r = singleResolutions[i];
      final ineqName = '(${i + 1})';
      final solText = r.exactResultLatex;
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Resolver inecuación $ineqName',
          latexExpression: '${r.originalInputLatex} \\implies S_{${i + 1}} = $solText',
          pedagogicalNote:
              'Resolvemos la inecuación $ineqName por separado. Si en algún despeje se multiplica o divide por un número negativo, se invierte el sentido de la desigualdad.',
          warningTrick:
              'Recuerda: al dividir o multiplicar por un número negativo se cambia el sentido de la desigualdad (< pasa a > y ≤ pasa a ≥).',
        ),
      );
    }

    // Calcular la intersección de intervalos
    final intervals1 = visualDataList.isNotEmpty ? visualDataList[0].primaryIntervals : <InequalityInterval>[];
    final intervals2 = visualDataList.length > 1 ? visualDataList[1].primaryIntervals : <InequalityInterval>[];

    final intersection = _intersectIntervalLists(intervals1, intervals2);

    final s1Latex = singleResolutions[0].exactResultLatex;
    final s2Latex = singleResolutions.length > 1 ? singleResolutions[1].exactResultLatex : '';
    final sfLatex = intersection.isEmpty
        ? r'\emptyset'
        : intersection.map((i) => i.toIntervalLatex()).join(r' \cup ');

    // Paso 3: Representación en la recta e intersección con rayado
    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Representación en la recta e intersección',
        latexExpression:
            'S_{1} = $s1Latex \\quad (\\text{rayado } / / /) \\\\\n'
            'S_{2} = $s2Latex \\quad (\\text{rayado } \\backslash \\backslash \\backslash) \\\\\n'
            'S_{f} = S_{1} \\cap S_{2} = $sfLatex \\quad (\\text{zona en malla XXX})',
        pedagogicalNote:
            'Dibujamos sobre la recta real los puntos críticos ordenados. Trazamos la solución S₁ con rayado inclinado (///) '
            'y la solución S₂ con rayado inclinado opuesto (\\\\\\). La solución final es la zona común donde ambos rayados se cruzan formando una malla (XXX).',
      ),
    );

    // Paso 4: Solución final
    final isNone = intersection.isEmpty;
    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Solución final del sistema',
        latexExpression: isNone
            ? r'S_{f} = S_{1} \cap S_{2} = \emptyset \quad (\text{Sin solucion})'
            : 'x \\in S_{f} = $sfLatex',
        pedagogicalNote: isNone
            ? 'Los intervalos no tienen ningún punto en común: el sistema de inecuaciones es incompatible y no tiene solución (conjunto vacío ∅).'
            : 'Cualquier número real dentro del intervalo solución cumple simultáneamente todas las inecuaciones del sistema.',
      ),
    );

    // Recoger todos los puntos críticos de ambas inecuaciones
    final allCritPoints = <CriticalPoint>[];
    for (final v in visualDataList) {
      allCritPoints.addAll(v.criticalPoints);
    }
    allCritPoints.sort((a, b) => a.value.compareTo(b.value));

    final originalLatex = rawInequalities.join(r' \quad \text{y} \quad ');

    final res = StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: 'S_{f} = $sfLatex',
      decimalApproxLatex: 'S_{f} = $sfLatex',
    );

    final visualData = Inequality1DVisualData(
      criticalPoints: allCritPoints,
      primaryIntervals: intervals1,
      secondaryIntervals: intervals2,
      intersectionIntervals: intersection,
      solutionLatex: 'S_1 \\cap S_2 = $sfLatex',
      label1: 'S_1',
      label2: 'S_2',
    );

    _visualDataExpando[res] = visualData;
    return (resolution: res, visualData: visualData);
  }

  static List<InequalityInterval> _intersectIntervalLists(
    List<InequalityInterval> list1,
    List<InequalityInterval> list2,
  ) {
    if (list1.isEmpty || list2.isEmpty) return const [];
    final result = <InequalityInterval>[];

    for (final i1 in list1) {
      for (final i2 in list2) {
        final start = math.max(i1.start, i2.start);
        final end = math.min(i1.end, i2.end);

        if (start < end) {
          final incStart = (start == i1.start ? i1.includeStart : true) &&
              (start == i2.start ? i2.includeStart : true);
          final incEnd = (end == i1.end ? i1.includeEnd : true) &&
              (end == i2.end ? i2.includeEnd : true);

          final sLabel = start == i1.start ? i1.startLabel : i2.startLabel;
          final eLabel = end == i1.end ? i1.endLabel : i2.endLabel;

          result.add(
            InequalityInterval(
              start: start,
              end: end,
              includeStart: incStart,
              includeEnd: incEnd,
              startLabel: sLabel,
              endLabel: eLabel,
            ),
          );
        } else if (start == end) {
          final incBoth = (start == i1.start ? i1.includeStart : i1.includeEnd) &&
              (start == i2.start ? i2.includeStart : i2.includeEnd);
          if (incBoth) {
            result.add(
              InequalityInterval(
                start: start,
                end: end,
                includeStart: true,
                includeEnd: true,
                startLabel: _fmt(start),
                endLabel: _fmt(end),
              ),
            );
          }
        }
      }
    }
    return result;
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
              '$eqLatex \\implies \\Delta = $discriminant > 0 \\implies x_{1} = ${r1.latex}, \\; x_{2} = ${r2.latex}',
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

      final res = StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: solInterval,
        decimalApproxLatex: solInterval,
      );

      // Intervalos para el pintor de signos (SÍ / NO)
      final sat0 = sign.matchesSign(v0.numerator.sign);
      final sat1 = sign.matchesSign(v1.numerator.sign);
      final sat2 = sign.matchesSign(v2.numerator.sign);

      final signIntervals = [
        InequalityInterval(
          start: double.negativeInfinity,
          end: r1.approx,
          endLabel: r1.latex,
          isSatisfied: sat0,
        ),
        InequalityInterval(
          start: r1.approx,
          end: r2.approx,
          startLabel: r1.latex,
          endLabel: r2.latex,
          isSatisfied: sat1,
        ),
        InequalityInterval(
          start: r2.approx,
          end: double.infinity,
          startLabel: r2.latex,
          isSatisfied: sat2,
        ),
      ];

      final primIntervals = signIntervals.where((i) => i.isSatisfied).toList();

      final visualData = Inequality1DVisualData(
        criticalPoints: [
          CriticalPoint(value: r1.approx, label: r1.latex, isClosed: !sign.isStrict),
          CriticalPoint(value: r2.approx, label: r2.latex, isClosed: !sign.isStrict),
        ],
        primaryIntervals: primIntervals,
        signTestIntervals: signIntervals,
        solutionLatex: solInterval,
      );

      _visualDataExpando[res] = visualData;
      return res;
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
              '${AlgebraicLatexFormatter.quadraticExpression(a, b, c)} = 0 \\implies \\Delta = 0 \\implies x_{0} = $rLatex',
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

      final res = StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: solInterval,
        decimalApproxLatex: solInterval,
      );

      final visualData = Inequality1DVisualData(
        criticalPoints: [
          CriticalPoint(value: root.toDouble(), label: rLatex, isClosed: rootSatisfies),
        ],
        primaryIntervals: outerSatisfies
            ? [
                InequalityInterval(
                  start: double.negativeInfinity,
                  end: root.toDouble(),
                  endLabel: rLatex,
                  includeEnd: rootSatisfies,
                ),
                InequalityInterval(
                  start: root.toDouble(),
                  end: double.infinity,
                  startLabel: rLatex,
                  includeStart: rootSatisfies,
                )
              ]
            : const [],
        solutionLatex: solInterval,
      );

      _visualDataExpando[res] = visualData;
      return res;
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

    final res = StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: solInterval,
      decimalApproxLatex: solInterval,
    );

    final visualData = Inequality1DVisualData(
      criticalPoints: const [],
      primaryIntervals: alwaysTrue
          ? const [InequalityInterval(start: double.negativeInfinity, end: double.infinity)]
          : const [],
      solutionLatex: solInterval,
    );

    _visualDataExpando[res] = visualData;
    return res;
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
      if (0 < high!) return Rational(0);
      return Rational(high.ceil() - 1);
    }
    if (high == null) {
      if (0 > low) return Rational(0);
      return Rational(low.floor() + 1);
    }
    if (low < 0 && 0 < high) return Rational(0);
    final intFirst = low.floor() + 1;
    if (intFirst < high) {
      final intLast = high.ceil() - 1;
      if (intLast >= intFirst) {
        int best = intFirst;
        for (int v = intFirst; v <= intLast; v++) {
          if (v.abs() < best.abs()) best = v;
        }
        return Rational(best);
      }
    }
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

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}

class _QuadRoot {
  final String latex;
  final double approx;
  const _QuadRoot({required this.latex, required this.approx});
}
