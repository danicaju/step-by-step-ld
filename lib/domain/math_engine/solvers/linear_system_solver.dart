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
          ? '${AlgebraicLatexFormatter.signedFraction(a1, a2)} = ${AlgebraicLatexFormatter.signedFraction(b1, b2)} \\quad \\left(a_1 b_2 - a_2 b_1 = 0\\right)'
          : 'a_1 b_2 - a_2 b_1 = $a1 \\cdot $b2 - $a2 \\cdot $b1 = 0';

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
}
