import 'dart:math' as math;
import '../../core/algebraic_latex_formatter.dart';
import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../polynomial_equation_solver.dart';
import 'super_equation_helpers.dart';

class IrrationalEquationSolver {
  static StepByStepResolution solve(String clean, String originalRaw) {
    final originalLatex = originalRaw.trim();
    final steps = <MathStep>[];

    final sqrtMatch = RegExp(r'\\sqrt\{([^}]+)\}').firstMatch(clean);
    if (sqrtMatch == null) {
      return PolynomialEquationSolver.solveEquationString(originalRaw);
    }

    final insideRadical = sqrtMatch.group(1)!.trim();
    final eqParts = clean.split('=');
    if (eqParts.length != 2) throw const FormatException('Ecuacion irracional invalida.');

    String lhs = eqParts[0].trim();
    String rhs = eqParts[1].trim();

    String rhsIsolated = rhs;
    if (lhs.contains(r'\sqrt')) {
      final withoutSqrt = lhs.replaceFirst(sqrtMatch.group(0)!, '').trim();
      if (withoutSqrt.isNotEmpty) {
        if (withoutSqrt.startsWith('+')) {
          final toPass = withoutSqrt.substring(1).trim();
          rhsIsolated = '$rhs - ($toPass)';
        } else if (withoutSqrt.startsWith('-')) {
          final toPass = withoutSqrt.substring(1).trim();
          rhsIsolated = '$rhs + $toPass';
        } else {
          rhsIsolated = '$rhs - ($withoutSqrt)';
        }
      }
    } else {
      return solve('$rhs = $lhs', originalRaw);
    }

    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Aislar el radical en un miembro',
        latexExpression: '\\sqrt{$insideRadical} = $rhsIsolated',
        pedagogicalNote:
            'Para resolver una ecuacion irracional, el primer paso fundamental es aislar la raiz cuadrada en uno de los miembros antes de elevar a ninguna potencia.',
      ),
    );

    steps.add(
      MathStep(
        index: 2,
        shortTitle: 'Elevar al cuadrado ambos miembros',
        latexExpression:
            '\\left(\\sqrt{$insideRadical}\\right)^2 = \\left($rhsIsolated\\right)^2 '
            '\\implies $insideRadical = \\left($rhsIsolated\\right)^2',
        pedagogicalNote:
            'Elevamos al cuadrado ambos lados de la igualdad para anular la raiz. Si el otro miembro es un binomio, aplicamos la identidad notable correspondiente: (a ± b)² = a² ± 2ab + b².',
        warningTrick:
            '¡Atencion! Al elevar al cuadrado pueden aparecer soluciones falsas (raices extranas). Es OBLIGATORIO comprobar las soluciones en la ecuacion original al final.',
      ),
    );

    // Expandir algebraicamente: (m·x + n)² - (p·x + q) = 0
    final rhsLin = LinearExpression.parse(rhsIsolated, varName: 'x');
    final insideLin = LinearExpression.parse(insideRadical, varName: 'x');

    final aQuad = rhsLin.m * rhsLin.m;
    final bQuad = 2 * rhsLin.m * rhsLin.n - insideLin.m;
    final cQuad = rhsLin.n * rhsLin.n - insideLin.n;

    final aInt = aQuad.round();
    final bInt = bQuad.round();
    final cInt = cQuad.round();

    final List<double> candidateRoots = [];
    if (aInt == 0) {
      if (bInt != 0) {
        candidateRoots.add(-cQuad / bQuad);
      }
    } else {
      final disc = bInt * bInt - 4 * aInt * cInt;
      if (disc >= 0) {
        candidateRoots.add((-bQuad + math.sqrt(disc)) / (2 * aQuad));
        if (disc > 0) {
          candidateRoots.add((-bQuad - math.sqrt(disc)) / (2 * aQuad));
        }
      }
    }

    steps.add(
      MathStep(
        index: 3,
        shortTitle: 'Resolver la ecuacion resultante',
        latexExpression:
            '${AlgebraicLatexFormatter.quadraticExpression(aInt, bInt, cInt)} = 0 \\implies '
            '${candidateRoots.map((r) => "x = ${Rational.fromDouble(r, 1000).toLatex()}").join(", \\quad ")}',
        pedagogicalNote:
            'Reducimos los terminos semejantes e igualamos a cero para resolver la ecuacion cuadratica/lineal obtenida.',
      ),
    );

    // Comprobación obligatoria
    final List<String> validSolutions = [];
    final List<String> checkLatexLines = [];

    for (final root in candidateRoots) {
      final rat = Rational.fromDouble(root, 1000);
      final rLatex = rat.toLatex();

      final insideVal = insideLin.m * root + insideLin.n;
      if (insideVal < -1e-6) {
        checkLatexLines.add(
            '\\text{Para } x = $rLatex: \\sqrt{$insideVal} \\notin \\mathbb{R} \\implies \\text{Descartada}');
        continue;
      }

      final lhsVal = math.sqrt(insideVal.clamp(0.0, double.infinity));
      final rhsVal = rhsLin.m * root + rhsLin.n;

      final isClose = (lhsVal - rhsVal).abs() < 1e-4;
      if (isClose) {
        validSolutions.add(rLatex);
        checkLatexLines.add(
            '\\text{Para } x = $rLatex: \\sqrt{${insideVal.toStringAsFixed(1)}} = ${lhsVal.toStringAsFixed(1)} '
            '\\implies \\text{Valida } (\\checkmark)');
      } else {
        checkLatexLines.add(
            '\\text{Para } x = $rLatex: ${lhsVal.toStringAsFixed(1)} \\neq ${rhsVal.toStringAsFixed(1)} '
            '\\implies \\text{No valida (raiz extrana)}');
      }
    }

    steps.add(
      MathStep(
        index: 4,
        shortTitle: 'Comprobacion obligatoria en la ecuacion original',
        latexExpression: checkLatexLines.join(' \\\\\n'),
        pedagogicalNote:
            'Sustituimos cada solucion obtenida en la ecuacion con radical inicial. Descartamos aquellas que no cumplan la igualdad matematica exacta.',
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
