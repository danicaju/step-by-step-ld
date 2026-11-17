import '../../core/rational.dart';
import '../../core/algebraic_latex_formatter.dart';
import '../../models/step_resolution.dart';
import '../../models/inequality_models.dart';
import '../linear_equation_solver.dart';
import 'inequality_sign.dart';
import 'inequality_parsing_helper.dart';
import 'linear_inequality_1d_solver.dart';

class QuadraticInequalitySolver {
  static final Expando<Inequality1DVisualData> visualDataExpando =
      Expando<Inequality1DVisualData>();

  static StepByStepResolution solveQuadratic({
    required int a,
    required int b,
    required int c,
    required InequalitySign sign,
    String? customOriginalLatex,
  }) {
    if (a == 0) {
      return LinearInequality1DSolver.solveLinearTerms(
        leftTerms: [LinearTerm(xCoeff: b, constant: c)],
        rightTerms: const [LinearTerm(xCoeff: 0, constant: 0)],
        sign: sign,
        customOriginalLatex: customOriginalLatex,
      );
    }

    final originalLatex = customOriginalLatex ??
        '${AlgebraicLatexFormatter.quadraticExpression(a, b, c)} ${sign.latex} 0';
    final canonicalLatex =
        '${AlgebraicLatexFormatter.quadraticExpression(a, b, c)} ${sign.latex} 0';
    final List<MathStep> steps = [];

    // Paso de transposición si la entrada original no está igualada a 0
    final bool needsTransposition = customOriginalLatex != null &&
        customOriginalLatex.replaceAll(' ', '') != canonicalLatex.replaceAll(' ', '');
    if (needsTransposition) {
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Transponer términos e igualar a cero',
          latexExpression: '$originalLatex \\implies $canonicalLatex',
          pedagogicalNote:
              'Pasamos todos los términos al primer miembro para dejar el segundo miembro igual a cero.',
        ),
      );
    }

    final int discriminant = b * b - 4 * a * c;

    // -----------------------------------------------------------------
    // CASO 1: Dos raíces reales distintas (Δ > 0)
    // -----------------------------------------------------------------
    if (discriminant > 0) {
      final roots = InequalityParsingHelper.computeOrderedQuadraticRoots(a, b, discriminant);
      final r1 = roots.$1;
      final r2 = roots.$2;

      final eqLatex = '${AlgebraicLatexFormatter.quadraticExpression(a, b, c)} = 0';
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Resolver la ecuación asociada (= 0)',
          latexExpression:
              '$eqLatex \\implies \\Delta = $discriminant > 0 \\implies x_{1} = ${r1.latex}, \\; x_{2} = ${r2.latex}',
          pedagogicalNote:
              'Igualamos a cero para localizar los puntos críticos que dividen la recta real en tres intervalos: (-∞, x₁), (x₁, x₂) y (x₂, +∞).',
        ),
      );

      // Valores de prueba limpios en cada uno de los 3 tramos
      final t0 = InequalityParsingHelper.pickTestPoint(low: null, high: r1.approx);
      final t1 = InequalityParsingHelper.pickTestPoint(low: r1.approx, high: r2.approx);
      final t2 = InequalityParsingHelper.pickTestPoint(low: r2.approx, high: null);

      final v0 = InequalityParsingHelper.evalPolyAt(a, b, c, t0);
      final v1 = InequalityParsingHelper.evalPolyAt(a, b, c, t1);
      final v2 = InequalityParsingHelper.evalPolyAt(a, b, c, t2);

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

      final boundExplain = sign.isStrict
          ? 'Como la desigualdad es estricta (${sign.symbol}), los extremos quedan abiertos con paréntesis ( ).'
          : 'Como incluye el igual (${sign.symbol}), las raíces donde P(x)=0 se incluyen con corchetes [ ].';

      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Estudio de zonas en la recta real y solución',
          latexExpression: 'x \\in $solInterval',
          pedagogicalNote:
              'La recta real con carteles SÍ y NO sustituye a la tabla tradicional de signos. $boundExplain',
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

      final closedRoots = !sign.isStrict;
      final signIntervals = [
        InequalityInterval(
          start: double.negativeInfinity,
          end: r1.approx,
          endLabel: r1.latex,
          includeEnd: closedRoots,
          isSatisfied: sat0,
        ),
        InequalityInterval(
          start: r1.approx,
          end: r2.approx,
          startLabel: r1.latex,
          endLabel: r2.latex,
          includeStart: closedRoots,
          includeEnd: closedRoots,
          isSatisfied: sat1,
        ),
        InequalityInterval(
          start: r2.approx,
          end: double.infinity,
          startLabel: r2.latex,
          includeStart: closedRoots,
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

      visualDataExpando[res] = visualData;
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
          index: steps.length + 1,
          shortTitle: 'Resolver la ecuación asociada (Δ = 0)',
          latexExpression:
              '${AlgebraicLatexFormatter.quadraticExpression(a, b, c)} = 0 \\implies \\Delta = 0 \\implies x_{0} = $rLatex',
          pedagogicalNote:
              'El discriminante es nulo: existe una única raíz doble x₀ = $rLatex donde la parábola toca el eje X sin cambiar de signo a los lados.',
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
          index: steps.length + 1,
          shortTitle: 'Estudio de zonas alrededor de la raíz doble y solución',
          latexExpression: 'x \\in $solInterval',
          pedagogicalNote:
              'A ambos lados de la raíz doble el signo de la parábola es constante. La recta real visual muestra la solución.',
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

      visualDataExpando[res] = visualData;
      return res;
    }

    // -----------------------------------------------------------------
    // CASO 3: Sin raíces reales (Δ < 0)
    // -----------------------------------------------------------------
    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Ecuación asociada sin raíces reales (Δ < 0)',
        latexExpression:
            '\\Delta = $discriminant < 0 \\implies \\text{Sin raices reales}',
        pedagogicalNote:
            'Al no cortar al eje X, el polinomio mantiene siempre el mismo signo en toda la recta real (-∞, +∞).',
      ),
    );

    final bool alwaysTrue = sign.matchesSign(a > 0 ? 1 : -1);
    final String solInterval = alwaysTrue ? r'(-\infty, +\infty)' : r'\emptyset';

    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Estudio de signo en toda la recta y solución',
        latexExpression: alwaysTrue
            ? r'x \in (-\infty, +\infty) = \mathbb{R}'
            : r'\text{Sin solucion}',
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

    visualDataExpando[res] = visualData;
    return res;
  }
}
