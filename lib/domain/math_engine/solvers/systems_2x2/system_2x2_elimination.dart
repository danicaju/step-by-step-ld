import '../../core/algebraic_latex_formatter.dart';
import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import 'system_2x2_helpers.dart';

class System2x2EliminationSolver {
  /// Método 3: Reducción
  static StepByStepResolution solve({
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
              '\\begin{cases} ${System2x2Helpers.formatEquation(a1, b1, c1)} \\\\ ${System2x2Helpers.formatEquation(a2, b2, c2)} \\end{cases}',
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
            '\\textcolor{#2563EB}{\\cdot ${AlgebraicLatexFormatter.parenIfNegative(m1)}} & \\rightarrow & ${System2x2Helpers.formatEquation(newA1, newB1, newC1)} \\\\\n'
            '\\textcolor{#2563EB}{\\cdot ${AlgebraicLatexFormatter.parenIfNegative(m2)}} & \\rightarrow & ${System2x2Helpers.formatEquation(newA2, newB2, newC2)}\n'
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

    final eq1Formatted = System2x2Helpers.formatEquation(a1, b1, c1);
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
