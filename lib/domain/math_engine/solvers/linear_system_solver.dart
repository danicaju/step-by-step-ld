import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';

enum SystemResolutionMethod {
  sustitucion('Sustitución'),
  igualacion('Igualación'),
  reduccion('Reducción');

  final String displayName;
  const SystemResolutionMethod(this.displayName);
}

class LinearSystemSolver {
  /// Representa una ecuación lineal en dos variables: ax + by = c
  static String formatEquation(int a, int b, int c) {
    return AlgebraicLatexFormatter.twoVarEquation(a, b, c);
  }

  /// Despeja `varName` en `ax + by = c` con formato limpio sin dobles signos ni denominador negativo.
  static String _isolateVariableExpr({
    required int targetCoeff,
    required int otherCoeff,
    required String otherVar,
    required int constant,
  }) {
    // targetCoeff * v = constant - otherCoeff * otherVar
    if (targetCoeff == 1) {
      if (otherCoeff == 0) return '$constant';
      if (constant == 0) {
        return AlgebraicLatexFormatter.monomialTerm(-otherCoeff, otherVar, isFirst: true);
      }
      return '$constant${AlgebraicLatexFormatter.monomialTerm(-otherCoeff, otherVar, isFirst: false)}';
    }
    if (targetCoeff == -1) {
      return AlgebraicLatexFormatter.linearExpression(
        otherCoeff,
        -constant,
        variable: otherVar,
      );
    }

    // Multiplicamos numerador y denominador por -1 si targetCoeff < 0 para mantener denominador > 0
    final den = targetCoeff.abs();
    final numConst = targetCoeff > 0 ? constant : -constant;
    final numOther = targetCoeff > 0 ? -otherCoeff : otherCoeff;
    final numLatex = numConst == 0 && numOther == 0
        ? '0'
        : numConst == 0
            ? AlgebraicLatexFormatter.monomialTerm(numOther, otherVar, isFirst: true)
            : '$numConst${AlgebraicLatexFormatter.monomialTerm(numOther, otherVar, isFirst: false)}';
    return '\\frac{$numLatex}{$den}';
  }

  /// Resuelve un sistema 2x2 por el método especificado
  static StepByStepResolution solve({
    required int a1,
    required int b1,
    required int c1,
    required int a2,
    required int b2,
    required int c2,
    SystemResolutionMethod method = SystemResolutionMethod.sustitucion,
  }) {
    final eq1Latex = formatEquation(a1, b1, c1);
    final eq2Latex = formatEquation(a2, b2, c2);
    final systemLatex = '\\begin{cases} $eq1Latex \\\\ $eq2Latex \\end{cases}';

    final int det = a1 * b2 - a2 * b1;
    final int detX = c1 * b2 - c2 * b1;
    final int detY = a1 * c2 - a2 * c1;

    // Caso 1: Determinante nulo (Paralelas o Coincidentes)
    if (det == 0) {
      final isCompatibleIndeterminate = detX == 0 && detY == 0;
      final List<MathStep> steps = [];

      final propLatex = (a2 != 0 && b2 != 0)
          ? '${AlgebraicLatexFormatter.signedFraction(a1, a2)} = ${AlgebraicLatexFormatter.signedFraction(b1, b2)} \\quad \\left(a_{1} b_{2} - a_{2} b_{1} = 0\\right)'
          : 'a_{1} b_{2} - a_{2} b_{1} = $a1 \\cdot $b2 - $a2 \\cdot $b1 = 0';

      steps.add(
        MathStep(
          index: 1,
          shortTitle: 'Análisis de proporcionalidad de coeficientes',
          latexExpression: propLatex,
          pedagogicalNote:
              'Los coeficientes de las incógnitas son proporcionales (determinante nulo), lo que indica que las dos rectas tienen la misma inclinación.',
        ),
      );

      if (isCompatibleIndeterminate) {
        steps.add(
          const MathStep(
            index: 2,
            shortTitle: 'Sistema Compatible Indeterminado (SCI)',
            latexExpression:
                '0 = 0 \\implies \\text{S.C.I.}',
            pedagogicalNote:
                'Las dos ecuaciones representan la misma recta (rectas coincidentes). Cualquier punto de la recta es solución del sistema (infinitas soluciones).',
            warningTrick:
                'Si al operar resulta 0 = 0, las ecuaciones son dependientes y el sistema tiene infinitas soluciones (SCI).',
          ),
        );
        return StepByStepResolution(
          originalInputLatex: systemLatex,
          steps: steps,
          exactResultLatex: r'\text{Infinitas soluciones (S.C.I.)}',
          decimalApproxLatex: r'\text{Infinitas}',
        );
      } else {
        steps.add(
          const MathStep(
            index: 2,
            shortTitle: 'Sistema Incompatible (SI)',
            latexExpression:
                '0 \\neq k \\implies \\text{S.I.}',
            pedagogicalNote:
                'Las dos rectas son paralelas y nunca se cortan en ningún punto (sin solución).',
            warningTrick:
                'Si al operar resulta una contradicción como 0 = k (con k ≠ 0), el sistema es incompatible y no tiene solución (SI).',
          ),
        );
        return StepByStepResolution(
          originalInputLatex: systemLatex,
          steps: steps,
          exactResultLatex: r'\text{Sin solucion (S.I.)}',
          decimalApproxLatex: r'\text{Sin sol}',
        );
      }
    }

    // Solución única exacta con Rational
    final xRational = Rational.raw(detX, det).simplify();
    final yRational = Rational.raw(detY, det).simplify();

    switch (method) {
      case SystemResolutionMethod.sustitucion:
        return _solveBySubstitution(
          a1: a1,
          b1: b1,
          c1: c1,
          a2: a2,
          b2: b2,
          c2: c2,
          systemLatex: systemLatex,
          xRational: xRational,
          yRational: yRational,
        );
      case SystemResolutionMethod.igualacion:
        return _solveByEquating(
          a1: a1,
          b1: b1,
          c1: c1,
          a2: a2,
          b2: b2,
          c2: c2,
          systemLatex: systemLatex,
          xRational: xRational,
          yRational: yRational,
        );
      case SystemResolutionMethod.reduccion:
        return _solveByElimination(
          a1: a1,
          b1: b1,
          c1: c1,
          a2: a2,
          b2: b2,
          c2: c2,
          systemLatex: systemLatex,
          xRational: xRational,
          yRational: yRational,
        );
    }
  }

  /// Método 1: Sustitución
  static StepByStepResolution _solveBySubstitution({
    required int a1,
    required int b1,
    required int c1,
    required int a2,
    required int b2,
    required int c2,
    required String systemLatex,
    required Rational xRational,
    required Rational yRational,
  }) {
    final List<MathStep> steps = [];

    // Priorizamos despejar la variable con coeficiente ±1 (evitando coeficientes nulos)
    final bool isolateY1 = b1 != 0 && (b1.abs() == 1 || (a1.abs() != 1 && b2.abs() != 1));

    if (isolateY1 || a1 == 0) {
      // Despejar y en Ec. 1
      final yExprLatex = _isolateVariableExpr(
        targetCoeff: b1,
        otherCoeff: a1,
        otherVar: 'x',
        constant: c1,
      );

      steps.add(
        MathStep(
          index: 1,
          shortTitle: '1. Despejar una incógnita en la ecuación más sencilla',
          latexExpression: 'y = $yExprLatex',
          pedagogicalNote:
              'Despejamos la incógnita con coeficiente más sencillo en la primera ecuación para sustituirla después.',
        ),
      );

      // Sustituir y en Ec. 2
      final xPart = AlgebraicLatexFormatter.monomialTerm(a2, 'x', isFirst: true);
      final ySubLatex = AlgebraicLatexFormatter.signedCoeffTimesParenthesized(
        b2,
        '\\textcolor{#2563EB}{$yExprLatex}',
        isFirst: a2 == 0,
      );
      final eqSub = '$xPart$ySubLatex'.isEmpty ? '0 = $c2' : '$xPart$ySubLatex = $c2';

      steps.add(
        MathStep(
          index: 2,
          shortTitle: '2. Sustituir en la otra ecuación',
          latexExpression: eqSub,
          pedagogicalNote:
              'Reemplazamos la expresión de y entre paréntesis en la segunda ecuación, obteniendo una ecuación de 1.º grado con solo x.',
        ),
      );

      steps.add(
        MathStep(
          index: 3,
          shortTitle: '3. Resolver la ecuación para hallar x',
          latexExpression: 'x = ${xRational.toLatex()}',
          pedagogicalNote:
              'Operamos los paréntesis, agrupamos los términos en x a la izquierda y despejamos su valor numérico.',
        ),
      );

      steps.add(
        MathStep(
          index: 4,
          shortTitle: '4. Calcular el valor de y',
          latexExpression:
              'y = $yExprLatex = ${yRational.toLatex()}',
          pedagogicalNote:
              'Sustituimos el valor hallado x = ${xRational.toLatex()} en la expresión despejada del Paso 1 para obtener y.',
        ),
      );
    } else {
      // Despejar x en Ec. 1
      final xExprLatex = _isolateVariableExpr(
        targetCoeff: a1,
        otherCoeff: b1,
        otherVar: 'y',
        constant: c1,
      );

      steps.add(
        MathStep(
          index: 1,
          shortTitle: '1. Despejar una incógnita en la ecuación más sencilla',
          latexExpression: 'x = $xExprLatex',
          pedagogicalNote:
              'Aislamos la incógnita con coeficiente más sencillo en la primera ecuación.',
        ),
      );

      final xSubLatex = AlgebraicLatexFormatter.signedCoeffTimesParenthesized(
        a2,
        '\\textcolor{#2563EB}{$xExprLatex}',
        isFirst: true,
      );
      final yPart = AlgebraicLatexFormatter.monomialTerm(
        b2,
        'y',
        isFirst: a2 == 0,
      );
      final eqSub = '$xSubLatex$yPart'.isEmpty ? '0 = $c2' : '$xSubLatex$yPart = $c2';

      steps.add(
        MathStep(
          index: 2,
          shortTitle: '2. Sustituir en la otra ecuación',
          latexExpression: eqSub,
          pedagogicalNote:
              'Sustituimos la incógnita despejada en la segunda ecuación para trabajar con una sola variable (y).',
        ),
      );

      steps.add(
        MathStep(
          index: 3,
          shortTitle: '3. Resolver la ecuación para hallar y',
          latexExpression: 'y = ${yRational.toLatex()}',
          pedagogicalNote:
              'Agrupamos monomios semejantes y despejamos la variable y.',
        ),
      );

      steps.add(
        MathStep(
          index: 4,
          shortTitle: '4. Calcular el valor de x',
          latexExpression:
              'x = $xExprLatex = ${xRational.toLatex()}',
          pedagogicalNote:
              'Sustituimos el valor hallado y = ${yRational.toLatex()} en la expresión de x.',
        ),
      );
    }

    return StepByStepResolution(
      originalInputLatex: systemLatex,
      steps: steps,
      exactResultLatex: 'x = ${xRational.toLatex()}, \\; y = ${yRational.toLatex()}',
      decimalApproxLatex: 'x = ${xRational.toDecimalLatex()}, \\; y = ${yRational.toDecimalLatex()}',
    );
  }

  /// Método 2: Igualación
  static StepByStepResolution _solveByEquating({
    required int a1,
    required int b1,
    required int c1,
    required int a2,
    required int b2,
    required int c2,
    required String systemLatex,
    required Rational xRational,
    required Rational yRational,
  }) {
    final List<MathStep> steps = [];

    // Si alguna ecuación no tiene x (a == 0), igualamos la y
    if (a1 == 0 || a2 == 0) {
      final yExpr1 = _isolateVariableExpr(
        targetCoeff: b1,
        otherCoeff: a1,
        otherVar: 'x',
        constant: c1,
      );
      final yExpr2 = _isolateVariableExpr(
        targetCoeff: b2,
        otherCoeff: a2,
        otherVar: 'x',
        constant: c2,
      );

      steps.add(
        MathStep(
          index: 1,
          shortTitle: '1. Despejar la incógnita y en ambas ecuaciones',
          latexExpression:
              '\\begin{cases} y = $yExpr1 \\\\[6pt] y = $yExpr2 \\end{cases}',
          pedagogicalNote:
              'Aislamos la misma variable (y) en las dos ecuaciones del sistema para igualarlas.',
        ),
      );
      steps.add(
        MathStep(
          index: 2,
          shortTitle: '2. Igualar expresiones y resolver x',
          latexExpression: '$yExpr1 = $yExpr2 \\implies x = ${xRational.toLatex()}',
          pedagogicalNote:
              'Como ambas expresiones equivalen a y, las igualamos y despejamos x.',
        ),
      );
      steps.add(
        MathStep(
          index: 3,
          shortTitle: '3. Calcular el valor de y',
          latexExpression: 'y = $yExpr1 = ${yRational.toLatex()}',
          pedagogicalNote:
              'Sustituimos x en cualquiera de las expresiones anteriores para obtener y.',
        ),
      );
      return StepByStepResolution(
        originalInputLatex: systemLatex,
        steps: steps,
        exactResultLatex: 'x = ${xRational.toLatex()}, \\; y = ${yRational.toLatex()}',
        decimalApproxLatex: 'x = ${xRational.toDecimalLatex()}, \\; y = ${yRational.toDecimalLatex()}',
      );
    }

    final frac1 = _isolateVariableExpr(
      targetCoeff: a1,
      otherCoeff: b1,
      otherVar: 'y',
      constant: c1,
    );
    final frac2 = _isolateVariableExpr(
      targetCoeff: a2,
      otherCoeff: b2,
      otherVar: 'y',
      constant: c2,
    );

    steps.add(
      MathStep(
        index: 1,
        shortTitle: '1. Despejar la misma incógnita en ambas ecuaciones',
        latexExpression:
            '\\begin{cases} x = $frac1 \\\\[6pt] x = $frac2 \\end{cases}',
        pedagogicalNote:
            'Aislamos la misma variable (x) en las dos ecuaciones del sistema para poder igualar sus expresiones.',
      ),
    );

    final num1 = b1 == 0
        ? '$c1'
        : (c1 == 0
            ? AlgebraicLatexFormatter.monomialTerm(-b1, 'y', isFirst: true)
            : '$c1${AlgebraicLatexFormatter.monomialTerm(-b1, 'y', isFirst: false)}');
    final num2 = b2 == 0
        ? '$c2'
        : (c2 == 0
            ? AlgebraicLatexFormatter.monomialTerm(-b2, 'y', isFirst: true)
            : '$c2${AlgebraicLatexFormatter.monomialTerm(-b2, 'y', isFirst: false)}');
    final crossLhs = AlgebraicLatexFormatter.signedCoeffTimesParenthesized(a2, num1);
    final crossRhs = AlgebraicLatexFormatter.signedCoeffTimesParenthesized(a1, num2);

    steps.add(
      MathStep(
        index: 2,
        shortTitle: '2. Igualar expresiones y multiplicar en cruz',
        latexExpression: '$frac1 = $frac2 \\implies $crossLhs = $crossRhs',
        pedagogicalNote:
            'Como ambas expresiones equivalen a x, deben ser iguales entre sí. Multiplicamos en cruz para eliminar los denominadores.',
      ),
    );

    steps.add(
      MathStep(
        index: 3,
        shortTitle: '3. Resolver la ecuación lineal para hallar y',
        latexExpression: 'y = ${yRational.toLatex()}',
        pedagogicalNote:
            'Operamos los paréntesis, reducimos términos semejantes y despejamos y.',
      ),
    );

    steps.add(
      MathStep(
        index: 4,
        shortTitle: '4. Sustituir para hallar x',
        latexExpression: 'x = $frac1 = ${xRational.toLatex()}',
        pedagogicalNote:
            'Sustituimos el valor obtenido de y en cualquiera de las expresiones despejadas del Paso 1.',
      ),
    );

    return StepByStepResolution(
      originalInputLatex: systemLatex,
      steps: steps,
      exactResultLatex: 'x = ${xRational.toLatex()}, \\; y = ${yRational.toLatex()}',
      decimalApproxLatex: 'x = ${xRational.toDecimalLatex()}, \\; y = ${yRational.toDecimalLatex()}',
    );
  }

  /// Método 3: Reducción
  static StepByStepResolution _solveByElimination({
    required int a1,
    required int b1,
    required int c1,
    required int a2,
    required int b2,
    required int c2,
    required String systemLatex,
    required Rational xRational,
    required Rational yRational,
  }) {
    final List<MathStep> steps = [];

    // Si alguna ecuación ya carece de y, resolvemos directamente sin dividir entre 0
    if (b1 == 0 || b2 == 0) {
      steps.add(
        MathStep(
          index: 1,
          shortTitle: '1. Una incógnita ya está despejada directamente',
          latexExpression:
              '\\begin{cases} ${formatEquation(a1, b1, c1)} \\\\ ${formatEquation(a2, b2, c2)} \\end{cases}',
          pedagogicalNote:
              'Como una de las ecuaciones solo tiene una incógnita, la despejamos directamente sin multiplicar filas.',
        ),
      );
      steps.add(
        MathStep(
          index: 2,
          shortTitle: '2. Solución del sistema',
          latexExpression: 'x = ${xRational.toLatex()}, \\quad y = ${yRational.toLatex()}',
          pedagogicalNote:
              'Obtenemos x y sustituimos en la otra ecuación para hallar y.',
        ),
      );
      return StepByStepResolution(
        originalInputLatex: systemLatex,
        steps: steps,
        exactResultLatex: 'x = ${xRational.toLatex()}, \\; y = ${yRational.toLatex()}',
        decimalApproxLatex: 'x = ${xRational.toDecimalLatex()}, \\; y = ${yRational.toDecimalLatex()}',
      );
    }

    // Elegimos eliminar y
    final int lcmY = Rational.lcm(b1.abs(), b2.abs());
    int m1 = lcmY ~/ b1.abs() * (b1 < 0 ? -1 : 1);
    int m2 = -(lcmY ~/ b2.abs()) * (b2 < 0 ? -1 : 1);

    // Multiplicar filas
    final newA1 = m1 * a1;
    final newB1 = m1 * b1;
    final newC1 = m1 * c1;

    final newA2 = m2 * a2;
    final newB2 = m2 * b2;
    final newC2 = m2 * c2;

    steps.add(
      MathStep(
        index: 1,
        shortTitle: '1. Multiplicar las ecuaciones para lograr coeficientes opuestos',
        latexExpression:
            '\\begin{array}{rll}\n'
            '\\textcolor{#2563EB}{\\cdot ${AlgebraicLatexFormatter.parenIfNegative(m1)}} & \\rightarrow & ${formatEquation(newA1, newB1, newC1)} \\\\\n'
            '\\textcolor{#2563EB}{\\cdot ${AlgebraicLatexFormatter.parenIfNegative(m2)}} & \\rightarrow & ${formatEquation(newA2, newB2, newC2)}\n'
            '\\end{array}',
        pedagogicalNote:
            'Buscamos el m.c.m. de los coeficientes de y (m.c.m. = $lcmY). '
            'Multiplicamos la fila 1 por $m1 y la fila 2 por $m2 para que los coeficientes de y sean opuestos ($newB1 y $newB2).',
      ),
    );

    final sumA = newA1 + newA2;
    final sumC = newC1 + newC2;

    final row1X = AlgebraicLatexFormatter.monomialTerm(newA1, 'x');
    final row1Sign = newB1 >= 0 ? '+' : '-';
    final row1Y = AlgebraicLatexFormatter.monomialTerm(newB1.abs(), 'y');
    final row2X = AlgebraicLatexFormatter.monomialTerm(newA2, 'x');
    final row2Sign = newB2 >= 0 ? '+' : '-';
    final row2Y = AlgebraicLatexFormatter.monomialTerm(newB2.abs(), 'y');
    final sumX = AlgebraicLatexFormatter.monomialTerm(sumA, 'x');

    steps.add(
      MathStep(
        index: 2,
        shortTitle: '2. Sumar las dos ecuaciones verticalmente',
        latexExpression:
            '\\begin{array}{rcrcr}\n'
            '${row1X.isEmpty ? "0" : row1X} & $row1Sign & \\textcolor{#DC2626}{$row1Y} & = & $newC1 \\\\\n'
            '${row2X.isEmpty ? "0" : row2X} & $row2Sign & \\textcolor{#DC2626}{$row2Y} & = & $newC2 \\\\\n'
            '\\hline\n'
            '$sumX & & \\textcolor{#DC2626}{0} & = & $sumC\n'
            '\\end{array}',
        pedagogicalNote:
            'Sumamos término a término en vertical. Los coeficientes opuestos de y se anulan por completo ($newB1 + (${AlgebraicLatexFormatter.parenIfNegative(newB2)}) = 0).',
      ),
    );

    final xLatex = xRational.toLatex();
    final sumXTerm = AlgebraicLatexFormatter.monomialTerm(sumA, 'x');
    final String solveXLatex;
    if (sumA == 1) {
      solveXLatex = 'x = $xLatex';
    } else if (sumA == -1) {
      solveXLatex = '-x = $sumC \\implies x = $xLatex';
    } else {
      final rawFracX = AlgebraicLatexFormatter.signedFraction(sumC, sumA);
      solveXLatex = rawFracX == xLatex
          ? '$sumXTerm = $sumC \\implies x = $xLatex'
          : '$sumXTerm = $sumC \\implies x = $rawFracX = $xLatex';
    }

    steps.add(
      MathStep(
        index: 3,
        shortTitle: '3. Despejar la primera incógnita (x)',
        latexExpression: solveXLatex,
        pedagogicalNote:
            'Al eliminarse y, resolvemos la ecuación lineal directa resultante dividiendo entre el coeficiente de x.',
      ),
    );

    // Sustituir en la primera ecuación original
    final eq1Formatted = formatEquation(a1, b1, c1);
    final a1SubX = AlgebraicLatexFormatter.signedCoeffTimesParenthesized(a1, xLatex);
    final b1Y = AlgebraicLatexFormatter.monomialTerm(b1, 'y', isFirst: a1 == 0);
    steps.add(
      MathStep(
        index: 4,
        shortTitle: '4. Sustituir en la ecuación original para hallar y',
        latexExpression:
            '$a1SubX$b1Y = $c1 \\implies y = ${yRational.toLatex()}',
        pedagogicalNote:
            'Sustituimos el valor de x en la primera ecuación original ($eq1Formatted) y despejamos y.',
      ),
    );

    return StepByStepResolution(
      originalInputLatex: systemLatex,
      steps: steps,
      exactResultLatex: 'x = ${xRational.toLatex()}, \\; y = ${yRational.toLatex()}',
      decimalApproxLatex: 'x = ${xRational.toDecimalLatex()}, \\; y = ${yRational.toDecimalLatex()}',
    );
  }

  // ===========================================================================
  // PARSER DE ENTRADA DESORDENADA Y SISTEMAS N×N (HASTA 4 ECUACIONES)
  // ===========================================================================

  /// Parsea cualquier ecuación lineal desordenada (ej: "2y + 3x - 5 = x + 1")
  /// y la agrupa a la forma estándar: a1*x + a2*y + a3*z + a4*w = C.
  static ParsedLinearEquation parseUnorderedEquation(
    String raw, {
    List<String> vars = const ['x', 'y', 'z', 'w'],
  }) {
    final clean = raw
        .replaceAll('\r', '')
        .replaceAll(' ', '')
        .replaceAll('X', 'x')
        .replaceAll('Y', 'y')
        .replaceAll('Z', 'z')
        .replaceAll('W', 'w')
        .replaceAll('−', '-')
        .replaceAll('·', '*')
        .replaceAll('×', '*')
        .replaceAll(r'\cdot', '*')
        .replaceAll(r'\times', '*');

    final sides = clean.split('=');
    final lhsStr = sides[0].trim();
    final rhsStr = sides.length > 1 ? sides[1].trim() : '0';

    final lhsMap = _parseLinearSide(lhsStr, vars);
    final rhsMap = _parseLinearSide(rhsStr, vars);

    final finalCoeffs = <String, Rational>{};
    for (final v in vars) {
      final lhsCoeff = lhsMap[v] ?? Rational(0);
      final rhsCoeff = rhsMap[v] ?? Rational(0);
      finalCoeffs[v] = lhsCoeff - rhsCoeff;
    }

    final lhsConst = lhsMap['__const__'] ?? Rational(0);
    final rhsConst = rhsMap['__const__'] ?? Rational(0);
    final finalConst = rhsConst - lhsConst;

    // Construir LaTeX ordenado
    final buffer = StringBuffer();
    bool first = true;
    for (final v in vars) {
      final c = finalCoeffs[v]!;
      if (c.isZero) continue;
      if (first) {
        if (c.isNegative) buffer.write('-');
        final absC = c.abs();
        if (absC != Rational(1)) buffer.write(absC.toLatex());
        buffer.write(v);
        first = false;
      } else {
        buffer.write(c.isNegative ? ' - ' : ' + ');
        final absC = c.abs();
        if (absC != Rational(1)) buffer.write(absC.toLatex());
        buffer.write(v);
      }
    }
    if (first) buffer.write('0');
    buffer.write(' = ${finalConst.toLatex()}');

    return ParsedLinearEquation(
      coefficients: finalCoeffs,
      constant: finalConst,
      originalRaw: raw,
      orderedLatex: buffer.toString(),
    );
  }

  static Map<String, Rational> _parseLinearSide(String expr, List<String> vars) {
    final res = <String, Rational>{};
    for (final v in vars) {
      res[v] = Rational(0);
    }
    res['__const__'] = Rational(0);

    if (expr.isEmpty) return res;

    // Expandir paréntesis simples si existen: k*(ax + b)
    var expanded = expr;
    final parenPattern = RegExp(r'([+-]?\d*(?:\.\d+)?)\*?\(([^)]+)\)');
    while (parenPattern.hasMatch(expanded)) {
      final m = parenPattern.firstMatch(expanded)!;
      final kStr = m.group(1)!;
      final k = kStr.isEmpty || kStr == '+' ? 1.0 : (kStr == '-' ? -1.0 : double.parse(kStr));
      final inner = m.group(2)!;
      // reemplazar k*(...) por expansión
      final innerTokens = _splitSignedTokens(inner);
      final expBuf = StringBuffer();
      for (final t in innerTokens) {
        final parsedT = _parseSingleToken(t, vars);
        if (parsedT.varName != null) {
          final newCoeff = parsedT.val * k;
          final sign = newCoeff >= 0 ? '+' : '-';
          expBuf.write('$sign${newCoeff.abs()}${parsedT.varName}');
        } else {
          final newConst = parsedT.val * k;
          final sign = newConst >= 0 ? '+' : '-';
          expBuf.write('$sign${newConst.abs()}');
        }
      }
      expanded = expanded.replaceFirst(m.group(0)!, expBuf.toString());
    }

    final tokens = _splitSignedTokens(expanded);
    for (final t in tokens) {
      final item = _parseSingleToken(t, vars);
      if (item.varName != null) {
        final r = Rational.fromDouble(item.val, 1000);
        res[item.varName!] = res[item.varName!]! + r;
      } else {
        final r = Rational.fromDouble(item.val, 1000);
        res['__const__'] = res['__const__']! + r;
      }
    }
    return res;
  }

  static List<String> _splitSignedTokens(String s) {
    final clean = s.replaceAll(' ', '');
    final tokens = <String>[];
    int start = 0;
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && (clean[i] == '+' || clean[i] == '-')) {
        tokens.add(clean.substring(start, i));
        start = i;
      }
    }
    if (start < clean.length) {
      tokens.add(clean.substring(start));
    }
    return tokens;
  }

  static ({double val, String? varName}) _parseSingleToken(String tok, List<String> vars) {
    for (final v in vars) {
      if (tok.contains(v)) {
        final coeffStr = tok.replaceAll(v, '').replaceAll('*', '').trim();
        final double coeff;
        if (coeffStr.isEmpty || coeffStr == '+') {
          coeff = 1.0;
        } else if (coeffStr == '-') {
          coeff = -1.0;
        } else if (coeffStr.contains('/')) {
          final parts = coeffStr.split('/');
          coeff = double.parse(parts[0]) / double.parse(parts[1]);
        } else {
          coeff = double.parse(coeffStr);
        }
        return (val: coeff, varName: v);
      }
    }
    // Constante
    final double cVal;
    if (tok.contains('/')) {
      final parts = tok.split('/');
      cVal = double.parse(parts[0]) / double.parse(parts[1]);
    } else {
      cVal = double.tryParse(tok) ?? 0.0;
    }
    return (val: cVal, varName: null);
  }

  /// Resuelve un sistema de N ecuaciones lineales (N = 2, 3 o 4) con coeficientes exactos [Rational].
  static StepByStepResolution solveNxN({
    required List<List<Rational>> augmentedRows,
    SystemResolutionMethod method = SystemResolutionMethod.sustitucion,
  }) {
    final n = augmentedRows.length;
    if (n < 2 || n > 4) {
      throw const FormatException('El sistema admite de 2 a 4 ecuaciones.');
    }
    for (final r in augmentedRows) {
      if (r.length != n + 1) {
        throw FormatException('Cada fila debe tener ${n + 1} coeficientes.');
      }
    }

    if (n == 2) {
      final a1 = augmentedRows[0][0].toDouble().round();
      final b1 = augmentedRows[0][1].toDouble().round();
      final c1 = augmentedRows[0][2].toDouble().round();
      final a2 = augmentedRows[1][0].toDouble().round();
      final b2 = augmentedRows[1][1].toDouble().round();
      final c2 = augmentedRows[1][2].toDouble().round();
      return solve(
        a1: a1,
        b1: b1,
        c1: c1,
        a2: a2,
        b2: b2,
        c2: c2,
        method: method,
      );
    }

    final varNames = const ['x', 'y', 'z', 'w'].sublist(0, n);
    final eqLines = [
      for (final r in augmentedRows)
        _formatRowLatex(r.sublist(0, n), r[n], varNames),
    ];
    final originalInputLatex = '\\begin{cases} ${eqLines.join(" \\\\ ")} \\end{cases}';

    // Resolver mediante reducción progresiva (triangularización) o sustitución
    final m = [
      for (final r in augmentedRows) [for (final v in r) v],
    ];
    final steps = <MathStep>[];

    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Sistema de $n ecuaciones con $n incognitas planteado',
        latexExpression: originalInputLatex,
        pedagogicalNote:
            'Planteamos el sistema con todas las incognitas (${varNames.join(", ")}) ordenadas a la izquierda y los terminos independientes a la derecha.',
      ),
    );

    // Eliminación progresiva
    for (int k = 0; k < n - 1; k++) {
      if (m[k][k].isZero) {
        // Intercambiar con fila debajo
        int swapRow = -1;
        for (int r = k + 1; r < n; r++) {
          if (!m[r][k].isZero) {
            swapRow = r;
            break;
          }
        }
        if (swapRow != -1) {
          final tmp = m[k];
          m[k] = m[swapRow];
          m[swapRow] = tmp;
        }
      }

      final pivot = m[k][k];
      if (pivot.isZero) continue;

      final elimNotes = <String>[];
      for (int r = k + 1; r < n; r++) {
        final target = m[r][k];
        if (!target.isZero) {
          final factor = target / pivot;
          for (int c = k; c <= n; c++) {
            m[r][c] = m[r][c] - (factor * m[k][c]);
          }
          elimNotes.add('E_{${r + 1}} \\leftarrow E_{${r + 1}} - (${factor.toLatex()}) E_{${k + 1}}');
        }
      }

      if (elimNotes.isNotEmpty) {
        final remainingEqs = [
          for (int r = 0; r < n; r++)
            _formatRowLatex(m[r].sublist(0, n), m[r][n], varNames),
        ];
        steps.add(
          MathStep(
            index: steps.length + 1,
            shortTitle: 'Eliminar incognita ${varNames[k]} en las ecuaciones inferiores',
            latexExpression:
                '${elimNotes.join(", ")} \\implies \\begin{cases} ${remainingEqs.join(" \\\\ ")} \\end{cases}',
            pedagogicalNote:
                'Combinamos linealmente las ecuaciones para anular la incognita ${varNames[k]} por debajo del pivote.',
          ),
        );
      }
    }

    // Comprobación de compatibilidad
    if (m[n - 1][n - 1].isZero) {
      if (m[n - 1][n].isZero) {
        return StepByStepResolution(
          originalInputLatex: originalInputLatex,
          steps: steps,
          exactResultLatex: r'\text{Infinitas soluciones (S.C.I.)}',
          decimalApproxLatex: r'\text{Infinitas}',
        );
      } else {
        return StepByStepResolution(
          originalInputLatex: originalInputLatex,
          steps: steps,
          exactResultLatex: r'\text{Sin solucion (S.I.)}',
          decimalApproxLatex: r'\text{Sin sol}',
        );
      }
    }

    // Sustitución hacia atrás
    final solution = List<Rational>.filled(n, Rational(0));
    final backSubNotes = <String>[];

    for (int r = n - 1; r >= 0; r--) {
      var sum = m[r][n];
      for (int c = r + 1; c < n; c++) {
        sum = sum - (m[r][c] * solution[c]);
      }
      solution[r] = sum / m[r][r];
      backSubNotes.add('${varNames[r]} = ${solution[r].toLatex()}');
    }

    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Sustitucion hacia atras (Back-substitution)',
        latexExpression: backSubNotes.join(', \\quad '),
        pedagogicalNote:
            'Despejamos desde la ultima ecuacion triangularizada y sustituimos progresivamente hacia arriba para hallar cada incognita.',
      ),
    );

    final exactRes = [
      for (int i = 0; i < n; i++) '${varNames[i]} = ${solution[i].toLatex()}',
    ].join(', \\; ');

    return StepByStepResolution(
      originalInputLatex: originalInputLatex,
      steps: steps,
      exactResultLatex: exactRes,
      decimalApproxLatex: [
        for (int i = 0; i < n; i++) '${varNames[i]} \\approx ${solution[i].toDecimalLatex()}',
      ].join(', \\; '),
    );
  }

  static String _formatRowLatex(List<Rational> coeffs, Rational constant, List<String> vars) {
    final buffer = StringBuffer();
    bool first = true;
    for (int i = 0; i < coeffs.length; i++) {
      final c = coeffs[i];
      if (c.isZero) continue;
      final v = vars[i];
      if (first) {
        if (c.isNegative) buffer.write('-');
        final absC = c.abs();
        if (absC != Rational(1)) buffer.write(absC.toLatex());
        buffer.write(v);
        first = false;
      } else {
        buffer.write(c.isNegative ? ' - ' : ' + ');
        final absC = c.abs();
        if (absC != Rational(1)) buffer.write(absC.toLatex());
        buffer.write(v);
      }
    }
    if (first) buffer.write('0');
    buffer.write(' = ${constant.toLatex()}');
    return buffer.toString();
  }

  /// Resuelve un conjunto de ecuaciones en texto libre con entrada desordenada.
  static StepByStepResolution solveFromEquations(
    List<String> rawEquations, {
    SystemResolutionMethod method = SystemResolutionMethod.sustitucion,
  }) {
    final dim = rawEquations.length;
    final varNames = const ['x', 'y', 'z', 'w'].sublist(0, dim);
    final parsed = rawEquations.map((e) => parseUnorderedEquation(e, vars: varNames)).toList();

    final augmentedRows = <List<Rational>>[];
    for (final p in parsed) {
      final row = <Rational>[];
      for (final v in varNames) {
        row.add(p.coefficients[v] ?? Rational(0));
      }
      row.add(p.constant);
      augmentedRows.add(row);
    }

    final isAnyDisordered = parsed.any((p) => p.originalRaw.trim() != p.orderedLatex.trim());
    final baseRes = solveNxN(augmentedRows: augmentedRows, method: method);
    if (!isAnyDisordered) return baseRes;

    final reorderStep = MathStep(
      index: 1,
      shortTitle: 'Reordenacion y agrupacion de terminos semejantes',
      latexExpression: '\\begin{cases} ${parsed.map((p) => p.orderedLatex).join(" \\\\ ")} \\end{cases}',
      pedagogicalNote:
          'Agrupamos las incognitas (${varNames.join(", ")}) en el primer miembro y reducimos los terminos independientes en el segundo miembro antes de aplicar el metodo de resolucion.',
    );

    final renumberedSteps = [
      reorderStep,
      for (int i = 0; i < baseRes.steps.length; i++)
        MathStep(
          index: i + 2,
          shortTitle: baseRes.steps[i].shortTitle,
          latexExpression: baseRes.steps[i].latexExpression,
          pedagogicalNote: baseRes.steps[i].pedagogicalNote,
          warningTrick: baseRes.steps[i].warningTrick,
        ),
    ];

    return StepByStepResolution(
      originalInputLatex: '\\begin{cases} ${rawEquations.join(" \\\\ ")} \\end{cases}',
      steps: renumberedSteps,
      exactResultLatex: baseRes.exactResultLatex,
      decimalApproxLatex: baseRes.decimalApproxLatex,
    );
  }
}

/// Representa una ecuación lineal desordenada que ha sido agrupada en forma canónica.
class ParsedLinearEquation {
  final Map<String, Rational> coefficients;
  final Rational constant;
  final String originalRaw;
  final String orderedLatex;

  const ParsedLinearEquation({
    required this.coefficients,
    required this.constant,
    required this.originalRaw,
    required this.orderedLatex,
  });
}

