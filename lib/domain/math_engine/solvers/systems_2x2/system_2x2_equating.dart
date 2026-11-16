import '../../core/algebraic_latex_formatter.dart';
import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import 'system_2x2_helpers.dart';

class System2x2EquatingSolver {
  /// Método 2: Igualación
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

    // Si alguna ecuación no tiene x (a == 0), igualamos la y
    if (a1 == 0 || a2 == 0) {
      final yExpr1 = System2x2Helpers.isolateVariableExpr(
        targetCoeff: b1,
        otherCoeff: a1,
        otherVar: 'x',
        constant: c1,
      );
      final yExpr2 = System2x2Helpers.isolateVariableExpr(
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

    final frac1 = System2x2Helpers.isolateVariableExpr(
      targetCoeff: a1,
      otherCoeff: b1,
      otherVar: 'y',
      constant: c1,
    );
    final frac2 = System2x2Helpers.isolateVariableExpr(
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
}
