import '../../core/rational.dart';
import '../../core/algebraic_latex_formatter.dart';
import '../../models/step_resolution.dart';
import '../../models/inequality_models.dart';
import '../linear_equation_solver.dart';
import 'inequality_sign.dart';
import 'inequality_parsing_helper.dart';

class LinearInequality1DSolver {
  static final Expando<Inequality1DVisualData> visualDataExpando =
      Expando<Inequality1DVisualData>();

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
        '${InequalityParsingHelper.formatLinearSideLatex(leftTerms)} ${sign.latex} ${InequalityParsingHelper.formatLinearSideLatex(rightTerms)}';
    final List<MathStep> steps = [];

    final allDenoms = <int>{
      ...leftTerms.map((t) => t.denominator),
      ...rightTerms.map((t) => t.denominator),
    }..remove(1);

    final int commonDen =
        allDenoms.isEmpty ? 1 : allDenoms.fold<int>(1, InequalityParsingHelper.lcm);

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
      visualDataExpando[res] = visualData;
      return res;
    }

    // Despeje de x con regla crítica del signo negativo
    final Rational solution = Rational.raw(netNum, netX).simplify();
    final InequalitySign finalSign;
    final String intervalLatex = InequalityParsingHelper.formatHalfLineInterval(
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

    visualDataExpando[res] = visualData;
    return res;
  }
}
