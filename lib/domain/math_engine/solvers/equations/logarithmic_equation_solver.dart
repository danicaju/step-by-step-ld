import 'dart:math' as math;
import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import 'super_equation_helpers.dart';

class LogarithmicEquationSolver {
  static bool isLogarithmicPattern(String s) {
    return s.contains(r'\log') || s.contains(r'\ln') || s.contains('log(') || s.contains('ln(');
  }

  static StepByStepResolution solve(String clean, String originalRaw) {
    final originalLatex = originalRaw.trim();
    final steps = <MathStep>[];

    final bool isLn = clean.contains(r'\ln') || clean.contains('ln(');

    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Propiedades de los logaritmos',
        latexExpression: isLn
            ? r'\ln(A) + \ln(B) = \ln(A \cdot B), \quad \ln(A) - \ln(B) = \ln\left(\frac{A}{B}\right), \quad k\ln(A) = \ln(A^k)'
            : r'\log(A) + \log(B) = \log(A \cdot B), \quad \log(A) - \log(B) = \log\left(\frac{A}{B}\right), \quad k\log(A) = \log(A^k)',
        pedagogicalNote:
            'Agrupamos todos los terminos logaritmicos en un unico miembro utilizando las propiedades de la suma, resta y potencia de logaritmos.',
      ),
    );

    final sides = clean.split('=');
    final lhs = sides[0].trim();
    final rhs = sides.length > 1 ? sides[1].trim() : '0';

    final logArgs = <String>[];
    final reg = RegExp(r'(?:\\log|\\ln|log|ln)(?:_\{?\w+\}?)?\(([^)]+)\)');
    for (final m in reg.allMatches(clean)) {
      logArgs.add(m.group(1)!.trim());
    }

    final candidateRoots = <double>[];

    // Caso A: Inyectividad pura: ln(A) = ln(B) o log(A) = log(B)
    final lhsIsPureLog = RegExp(r'^(?:\\log|\\ln|log|ln)\(([^)]+)\)$').hasMatch(lhs);
    final rhsIsPureLog = RegExp(r'^(?:\\log|\\ln|log|ln)\(([^)]+)\)$').hasMatch(rhs);

    if (lhsIsPureLog && rhsIsPureLog && logArgs.length == 2) {
      final aArg = logArgs[0];
      final bArg = logArgs[1];
      final aLin = LinearExpression.parse(aArg, varName: 'x');
      final bLin = LinearExpression.parse(bArg, varName: 'x');

      steps.add(
        MathStep(
          index: 2,
          shortTitle: 'Aplicar inyectividad: log(A) = log(B) => A = B',
          latexExpression: '$aArg = $bArg',
          pedagogicalNote:
              'Al tener un unico logaritmo con la misma base en ambos miembros, igualamos directamente los argumentos gracias a la inyectividad de la funcion logaritmica.',
        ),
      );

      final diffM = aLin.m - bLin.m;
      final diffN = aLin.n - bLin.n;
      if (diffM.abs() > 1e-9) {
        candidateRoots.add(-diffN / diffM);
      }
    } else if (logArgs.length >= 2 && lhs.contains('+')) {
      // Caso B: Suma de logaritmos: log(A) + log(B) = k
      final aArg = logArgs[0];
      final bArg = logArgs[1];
      final aLin = LinearExpression.parse(aArg, varName: 'x');
      final bLin = LinearExpression.parse(bArg, varName: 'x');

      final k = double.tryParse(rhs) ?? 1.0;
      final baseVal = isLn ? math.e : 10.0;
      final basePow = math.pow(baseVal, k).toDouble();

      steps.add(
        MathStep(
          index: 2,
          shortTitle: 'Definicion de logaritmo: log_b(M) = k => M = b^k',
          latexExpression:
              '${isLn ? "\\ln" : "\\log"}\\left(($aArg) \\cdot ($bArg)\\right) = $rhs \\implies ($aArg) \\cdot ($bArg) = ${basePow.round()}',
          pedagogicalNote:
              'Convertimos la suma en el logaritmo del producto y aplicamos la definicion fundamental: la base elevada al resultado es igual al argumento.',
        ),
      );

      final aQ = aLin.m * bLin.m;
      final bQ = aLin.m * bLin.n + aLin.n * bLin.m;
      final cQ = aLin.n * bLin.n - basePow;

      if (aQ.abs() < 1e-9) {
        if (bQ.abs() > 1e-9) candidateRoots.add(-cQ / bQ);
      } else {
        final disc = bQ * bQ - 4 * aQ * cQ;
        if (disc >= 0) {
          candidateRoots.add((-bQ + math.sqrt(disc)) / (2 * aQ));
          if (disc > 0) candidateRoots.add((-bQ - math.sqrt(disc)) / (2 * aQ));
        }
      }
    } else if (logArgs.isNotEmpty) {
      // Caso C: log(A) = k
      final aArg = logArgs[0];
      final aLin = LinearExpression.parse(aArg, varName: 'x');
      final k = double.tryParse(rhs) ?? 1.0;
      final baseVal = isLn ? math.e : 10.0;
      final basePow = math.pow(baseVal, k).toDouble();

      steps.add(
        MathStep(
          index: 2,
          shortTitle: 'Aplicar definicion de logaritmo',
          latexExpression: '$aArg = ${basePow.round()}',
          pedagogicalNote:
              'Despejamos el argumento igualandolo a la base elevada al termino independiente.',
        ),
      );

      if (aLin.m.abs() > 1e-9) {
        candidateRoots.add((basePow - aLin.n) / aLin.m);
      }
    }

    steps.add(
      MathStep(
        index: 3,
        shortTitle: 'Soluciones algebraicas preliminares',
        latexExpression: candidateRoots.isEmpty
            ? r'\text{Sin soluciones}'
            : candidateRoots
                .map((r) => 'x = ${Rational.fromDouble(r, 1000).toLatex()}')
                .join(', \\quad '),
        pedagogicalNote:
            'Resolvemos la ecuacion algebraica resultante de eliminar los operadores logaritmicos.',
      ),
    );

    // Comprobación estricta de dominio (Argumentos > 0)
    final List<String> validSolutions = [];
    final List<String> checkLines = [];

    for (final root in candidateRoots) {
      final rat = Rational.fromDouble(root, 1000);
      final rLatex = rat.toLatex();
      bool allPositive = true;

      for (final arg in logArgs) {
        final lin = LinearExpression.parse(arg, varName: 'x');
        final val = lin.m * root + lin.n;
        if (val <= 1e-6) {
          allPositive = false;
          checkLines.add(
              '\\text{Para } x = $rLatex: \\text{argumento } ($arg) = ${val.toStringAsFixed(2)} \\le 0 \\implies \\text{Descartada}');
          break;
        }
      }

      if (allPositive) {
        validSolutions.add(rLatex);
        checkLines.add(
            '\\text{Para } x = $rLatex: \\text{todos los argumentos } > 0 \\implies \\text{Valida } (\\checkmark)');
      }
    }

    steps.add(
      MathStep(
        index: 4,
        shortTitle: 'Comprobacion de existencia del logaritmo (Argumentos > 0)',
        latexExpression: checkLines.isEmpty
            ? r'\text{No hay candidatos}'
            : checkLines.join(' \\\\\n'),
        pedagogicalNote:
            'En el conjunto de los numeros reales, el logaritmo solo esta definido para valores estrictamente positivos (> 0). Cualquier solucion que anule o haga negativo el argumento queda descartada.',
        warningTrick:
            '¡Ojo en examenes! No basta con que x sea positivo; lo que debe ser estrictamente positivo es TODO el argumento dentro del logaritmo.',
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
