import '../../core/algebraic_latex_formatter.dart';
import '../../core/rational.dart';
import '../../models/step_resolution.dart';

class LinearFromCoeffsHelper {
  static StepByStepResolution solveLinearFromCoeffs({
    required int b,
    required int c,
    required String originalLatex,
    required List<MathStep> prefixSteps,
    required String lastEquationLatex,
  }) {
    final steps = <MathStep>[...prefixSteps];

    if (b == 0) {
      final isIdentity = c == 0;
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle:
              isIdentity ? 'Identidad (infinitas soluciones)' : 'Ecuación incompatible',
          latexExpression: isIdentity
              ? '0 = 0 \\implies x \\in \\mathbb{R}'
              : '0 = ${-c} \\implies \\text{Sin solucion}',
          pedagogicalNote: isIdentity
              ? 'Al simplificar se anulan todas las incógnitas y queda 0 = 0: cualquier valor real de x cumple la igualdad.'
              : 'Al simplificar se anulan las x y queda una igualdad falsa (0 = ${-c}): no existe solución.',
        ),
      );
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: isIdentity
            ? r'x \in \mathbb{R} \; (\text{Infinitas soluciones})'
            : r'\text{Sin solucion}',
        decimalApproxLatex: isIdentity ? r'x \in \mathbb{R}' : r'\nexists x',
      );
    }

    // b*x = -c (sin escribir 1x ni 0x)
    final rhsInt = -c;
    final leftTermLatex = AlgebraicLatexFormatter.monomialTerm(
      b,
      'x',
      isFirst: true,
    );
    final groupedLatex = '$leftTermLatex = $rhsInt';
    final alreadyGrouped = groupedLatex == lastEquationLatex;
    final sol = Rational(rhsInt, b);

    if (b == 1 && alreadyGrouped && steps.isEmpty) {
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Solución directa',
          latexExpression: groupedLatex,
          pedagogicalNote:
              'La incógnita x ya está despejada directamente en el primer miembro.',
        ),
      );
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: 'x = ${sol.toLatex()}',
        decimalApproxLatex: 'x \\approx ${sol.toDecimalLatex()}',
      );
    }

    if (!alreadyGrouped) {
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Agrupar incógnitas y términos independientes',
          latexExpression: groupedLatex,
          pedagogicalNote:
              'Pasamos los términos con x al primer miembro y los números al segundo cambiando el signo al cruzar el "=".',
        ),
      );
    }

    final prefixIfDirect =
        alreadyGrouped && steps.isEmpty ? '$groupedLatex \\implies ' : '';

    if (b == -1) {
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Despejar x cambiando el signo',
          latexExpression: '${prefixIfDirect}x = ${sol.toLatex()}',
          pedagogicalNote:
              'Multiplicamos ambos miembros por -1 para dejar la x positiva.',
        ),
      );
    } else if (b != 1) {
      final bool isExactInt = rhsInt % b == 0;
      final bool isSimplified = Rational.gcd(rhsInt, b) > 1 && !isExactInt;
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Despejar la incógnita x',
          latexExpression:
              '${prefixIfDirect}x = \\frac{$rhsInt}{$b}'
              '${isExactInt || isSimplified || b < 0 ? ' = ${sol.toLatex()}' : ''}',
          pedagogicalNote:
              'El coeficiente $b que multiplica a x pasa al otro miembro dividiendo'
              '${sol.toLatex() != '\\frac{$rhsInt}{$b}' ? ' y simplificamos al máximo.' : '.'}',
          warningTrick: b < 0
              ? 'Al pasar dividiendo $b (negativo) no cambia de signo; mantiene su signo en el denominador.'
              : null,
        ),
      );
    }

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: 'x = ${sol.toLatex()}',
      decimalApproxLatex: 'x \\approx ${sol.toDecimalLatex()}',
    );
  }
}
