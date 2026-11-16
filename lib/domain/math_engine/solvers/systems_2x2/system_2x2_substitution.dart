import '../../core/algebraic_latex_formatter.dart';
import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import 'system_2x2_helpers.dart';

class System2x2SubstitutionSolver {
  /// Método 1: Sustitución
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

    // Priorizamos despejar la variable con coeficiente ±1 (evitando coeficientes nulos)
    final bool isolateY1 = b1 != 0 && (b1.abs() == 1 || (a1.abs() != 1 && b2.abs() != 1));

    if (isolateY1 || a1 == 0) {
      // Despejar y en Ec. 1
      final yExprLatex = System2x2Helpers.isolateVariableExpr(
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
      final xExprLatex = System2x2Helpers.isolateVariableExpr(
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
}
