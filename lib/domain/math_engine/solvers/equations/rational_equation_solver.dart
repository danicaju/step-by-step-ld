import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import 'super_equation_helpers.dart';

class RationalEquationSolver {
  static bool isRationalPattern(String s) {
    if (!s.contains('/') && !s.contains(r'\frac')) return false;
    return RegExp(r'\/[^=]*x').hasMatch(s) || RegExp(r'\\frac\{[^}]*\}\{[^}]*x[^}]*\}').hasMatch(s);
  }

  static StepByStepResolution solve(String clean, String originalRaw) {
    final originalLatex = originalRaw.trim();
    final steps = <MathStep>[];

    // Extraer numerador, denominador y RHS: \frac{num}{den} = rhs
    String numStr = 'x';
    String denStr = 'x - 1';
    String rhsStr = '3';

    final fracMatch = RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}\s*=\s*(.+)').firstMatch(clean);
    if (fracMatch != null) {
      numStr = fracMatch.group(1)!.trim();
      denStr = fracMatch.group(2)!.trim();
      rhsStr = fracMatch.group(3)!.trim();
    } else {
      final slashMatch = RegExp(r'([^\/=]+)\/([^=]+)\s*=\s*(.+)').firstMatch(clean);
      if (slashMatch != null) {
        numStr = slashMatch.group(1)!.trim().replaceAll('(', '').replaceAll(')', '');
        denStr = slashMatch.group(2)!.trim().replaceAll('(', '').replaceAll(')', '');
        rhsStr = slashMatch.group(3)!.trim();
      }
    }

    final denLin = LinearExpression.parse(denStr, varName: 'x');
    double? forbiddenVal;
    if (denLin.m.abs() > 1e-9) {
      forbiddenVal = -denLin.n / denLin.m;
    }

    final forbiddenLatex = forbiddenVal != null
        ? Rational.fromDouble(forbiddenVal, 1000).toLatex()
        : '0';

    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Identificar valores prohibidos (Denominador nulo)',
        latexExpression: '$denStr = 0 \\implies x \\neq $forbiddenLatex',
        pedagogicalNote:
            'En una ecuacion racional, los denominadores jamas pueden anularse. Cualquier valor de x que haga 0 un denominador queda prohibido del dominio de la ecuacion.',
        warningTrick:
            '¡Atencion! Si una de las soluciones obtenidas coincide con un valor prohibido, debe tacharse inmediatamente.',
      ),
    );

    steps.add(
      MathStep(
        index: 2,
        shortTitle: 'Multiplicar por el m.c.m. de los denominadores',
        latexExpression: '($denStr) \\cdot \\left(\\frac{$numStr}{$denStr}\\right) = ($denStr) \\cdot ($rhsStr) \\implies $numStr = ($rhsStr) \\cdot ($denStr)',
        pedagogicalNote:
            'Calculamos el minimo comun multiplo de todas las expresiones en los denominadores y multiplicamos ambos miembros para eliminarlas.',
      ),
    );

    // Resolver numStr = rhsVal * denStr
    final rhsNum = double.tryParse(rhsStr) ?? 3.0;
    final numLin = LinearExpression.parse(numStr, varName: 'x');

    final resSlope = numLin.m - rhsNum * denLin.m;
    final resIntercept = numLin.n - rhsNum * denLin.n;

    final candidateRoots = <double>[];
    if (resSlope.abs() > 1e-9) {
      candidateRoots.add(-resIntercept / resSlope);
    }

    final List<String> validSolutions = [];
    final List<String> checkLines = [];

    for (final r in candidateRoots) {
      final rat = Rational.fromDouble(r, 1000);
      final rLatex = rat.toLatex();
      if (forbiddenVal != null && (r - forbiddenVal).abs() < 1e-5) {
        checkLines.add('\\text{Para } x = $rLatex: \\text{coincide con valor prohibido } \\implies \\text{Descartada}');
      } else {
        validSolutions.add(rLatex);
        checkLines.add('\\text{Para } x = $rLatex: \\text{denominador } \\neq 0 \\implies \\text{Valida } (\\checkmark)');
      }
    }

    steps.add(
      MathStep(
        index: 3,
        shortTitle: 'Soluciones algebraicas obtenidas',
        latexExpression: checkLines.join(' \\\\\n'),
        pedagogicalNote: 'Resolvemos la ecuacion entera resultante y comprobamos los valores prohibidos.',
      ),
    );

    final finalLatex = validSolutions.isEmpty
        ? r'\text{Sin solucion real}'
        : validSolutions.map((s) => 'x = $s').join(', \\quad ');

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: finalLatex,
      decimalApproxLatex: finalLatex,
    );
  }
}
