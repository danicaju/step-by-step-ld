import 'dart:math' as math;
import '../../core/algebraic_latex_formatter.dart';
import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import 'super_equation_helpers.dart';

class BiquadraticEquationSolver {
  static bool isBicuadraticPattern(String s) {
    if (!s.contains('=')) return false;
    final hasX4 = s.contains('x^4') || s.contains('x^{4}');
    final hasX3 = s.contains('x^3') || s.contains('x^{3}');
    final hasRadical = s.contains(r'\sqrt') || s.contains('sqrt');
    final hasLog = s.contains('log') || s.contains('ln');
    return hasX4 && !hasX3 && !hasRadical && !hasLog;
  }

  static StepByStepResolution solve(String clean, String originalRaw) {
    final sides = clean.split('=');
    if (sides.length != 2) throw const FormatException('Ecuacion bicuadrada invalida.');

    final lhs = sides[0].trim();
    final rhs = sides[1].trim();

    final tEqStr = '$lhs - ($rhs)'
        .replaceAll('x^{4}', 't^2')
        .replaceAll('x^4', 't^2')
        .replaceAll('x^{2}', 't')
        .replaceAll('x^2', 't')
        .replaceAll('x²', 't');

    final poly = SuperEquationHelpers.parseCoeffs2(tEqStr, 't');
    final a = poly[2]!;
    final b = poly[1]!;
    final c = poly[0]!;

    final aInt = a.round();
    final bInt = b.round();
    final cInt = c.round();

    final List<MathStep> steps = [];
    final originalLatex = originalRaw.trim();

    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Cambio de variable t = x²',
        latexExpression:
            '\\text{Haciendo } t = x^2 \\implies x^4 = t^2 \\implies '
            '${AlgebraicLatexFormatter.quadraticExpression(aInt, bInt, cInt, variable: "t")} = 0',
        pedagogicalNote:
            'Una ecuacion bicuadrada contiene unicamente potencias pares (x⁴ y x²). Al realizar el cambio de variable t = x², se transforma en una ecuacion de 2.º grado en t.',
      ),
    );

    final disc = bInt * bInt - 4 * aInt * cInt;
    final discLatex = '\\Delta = ($bInt)^2 - 4 \\cdot ($aInt) \\cdot ($cInt) = $disc';

    steps.add(
      MathStep(
        index: 2,
        shortTitle: 'Discriminante en t',
        latexExpression: discLatex,
        pedagogicalNote:
            'Calculamos el discriminante respecto a t para determinar cuantas soluciones reales existen para la variable auxiliar.',
      ),
    );

    if (disc < 0) {
      steps.add(
        const MathStep(
          index: 3,
          shortTitle: 'Sin soluciones reales',
          latexExpression:
              '\\Delta < 0 \\implies t \\notin \\mathbb{R} \\implies \\text{No existen soluciones reales}',
          pedagogicalNote:
              'Al ser el discriminante negativo, la ecuacion en t no tiene soluciones reales y, por tanto, la ecuacion bicuadrada tampoco.',
        ),
      );
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: r'\text{Sin solucion real}',
        decimalApproxLatex: r'\text{Sin solucion real}',
      );
    }

    final t1 = (-b + math.sqrt(disc)) / (2 * a);
    final t2 = (-b - math.sqrt(disc)) / (2 * a);

    final t1Rat = Rational.fromDouble(t1, 1000);
    final t2Rat = Rational.fromDouble(t2, 1000);

    steps.add(
      MathStep(
        index: 3,
        shortTitle: 'Valores de la variable auxiliar t',
        latexExpression:
            't_{1} = ${t1Rat.toLatex()}, \\quad t_{2} = ${t2Rat.toLatex()}',
        pedagogicalNote:
            'Aplicamos la formula cuadratica para obtener los valores de t.',
      ),
    );

    final List<String> realSolutions = [];
    final List<String> descarteNotes = [];

    void checkT(Rational tVal, String tName) {
      if (tVal.isNegative) {
        descarteNotes.add(
            '$tName = ${tVal.toLatex()} < 0 \\implies x = \\pm\\sqrt{${tVal.toLatex()}} \\notin \\mathbb{R}');
      } else if (tVal.isZero) {
        realSolutions.add('0');
      } else {
        final dVal = tVal.toDouble();
        final root = math.sqrt(dVal);
        final isPerfect = (root - root.round()).abs() < 1e-9;
        if (isPerfect) {
          final rInt = root.round();
          realSolutions.add('$rInt');
          realSolutions.add('-$rInt');
        } else {
          realSolutions.add('\\sqrt{${tVal.toLatex()}}');
          realSolutions.add('-\\sqrt{${tVal.toLatex()}}');
        }
      }
    }

    checkT(t1Rat, 't_{1}');
    if (t2Rat != t1Rat) {
      checkT(t2Rat, 't_{2}');
    }

    final String descarteLatex = descarteNotes.isNotEmpty
        ? '\\quad [${descarteNotes.join(', ')}]'
        : '';

    steps.add(
      MathStep(
        index: 4,
        shortTitle: 'Deshacer el cambio x = ±√t',
        latexExpression: 'x = \\pm\\sqrt{t} $descarteLatex',
        pedagogicalNote:
            'Para cada valor positivo de t, obtenemos dos soluciones x = ±√t. Si algun valor de t fuera negativo, se descarta porque en el cuerpo de los numeros reales no existen raices de indice par de numeros negativos.',
      ),
    );

    final uniqueSols = realSolutions.toSet().toList();
    uniqueSols.sort((s1, s2) {
      final v1 = SuperEquationHelpers.evalSolutionVal(s1);
      final v2 = SuperEquationHelpers.evalSolutionVal(s2);
      return v1.compareTo(v2);
    });

    final exactStr = uniqueSols.isEmpty
        ? r'\text{Sin solucion real}'
        : uniqueSols.map((s) => 'x = $s').join(', \\quad ');

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: exactStr,
      decimalApproxLatex: exactStr,
    );
  }
}
