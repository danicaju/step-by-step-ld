import 'dart:math' as math;
import '../core/algebraic_latex_formatter.dart';
import '../models/step_resolution.dart';

class RuffiniStepResult {
  final int root;
  final List<int> dividendCoeffs;
  final List<int> products;
  final List<int> quotientCoeffs;
  final int remainder;

  const RuffiniStepResult({
    required this.root,
    required this.dividendCoeffs,
    required this.products,
    required this.quotientCoeffs,
    required this.remainder,
  });

  String toLatexTable() {
    final colSpec = 'r|${'r' * dividendCoeffs.length}';
    final row1 = ' & ${dividendCoeffs.join(' & ')}';
    final row2 = '$root & ${products.map((p) => '$p').join(' & ')}';
    final row3Coeffs = quotientCoeffs.map((q) => '$q').toList();
    final row3 = ' & ${row3Coeffs.join(' & ')} & \\boxed{$remainder}';

    return '\\begin{array}{$colSpec}\n'
        '$row1 \\\\\n'
        '$row2 \\\\\n'
        '\\hline\n'
        '$row3\n'
        '\\end{array}';
  }
}

class RuffiniSolver {
  /// Convierte una lista de coeficientes [a_n, a_{n-1}, ..., a_0] a formato LaTeX
  static String polynomialToLatex(List<int> coeffs) {
    if (coeffs.isEmpty) return '0';
    return AlgebraicLatexFormatter.polynomialExpression(coeffs);
  }

  /// Calcula los divisores enteros de un número: {±1, ±2, ...}
  static List<int> getDivisors(int n) {
    final absN = n.abs();
    if (absN == 0) return [1, -1];
    final Set<int> divisors = {};
    final limit = math.sqrt(absN).toInt();
    for (int i = 1; i <= limit; i++) {
      if (absN % i == 0) {
        divisors.add(i);
        divisors.add(-i);
        divisors.add(absN ~/ i);
        divisors.add(-(absN ~/ i));
      }
    }
    final sorted = divisors.toList()..sort((a, b) => a.abs().compareTo(b.abs()));
    return sorted;
  }

  /// Ejecuta un paso individual de la regla de Ruffini
  static RuffiniStepResult executeRuffiniStep(List<int> coeffs, int root) {
    if (coeffs.isEmpty) {
      throw ArgumentError('Los coeficientes no pueden estar vacíos.');
    }

    final int lead = coeffs.first;
    final List<int> prodInts = [];
    final List<int> quotients = [lead];

    int current = lead;
    for (int i = 1; i < coeffs.length; i++) {
      final p = current * root;
      prodInts.add(p);
      current = coeffs[i] + p;
      if (i < coeffs.length - 1) {
        quotients.add(current);
      }
    }

    return RuffiniStepResult(
      root: root,
      dividendCoeffs: coeffs,
      products: prodInts,
      quotientCoeffs: quotients,
      remainder: current,
    );
  }

  static String _superscript(int deg) {
    const map = {
      '0': '⁰',
      '1': '¹',
      '2': '²',
      '3': '³',
      '4': '⁴',
      '5': '⁵',
      '6': '⁶',
      '7': '⁷',
      '8': '⁸',
      '9': '⁹',
    };
    return deg.toString().split('').map((ch) => map[ch] ?? ch).join();
  }

  static String _plainDegreeTerm(int d) =>
      d == 1 ? 'x' : 'x${_superscript(d)}';

  /// Factoriza un polinomio mediante la Regla de Ruffini paso a paso
  static StepByStepResolution factorize(List<int> inputCoeffs) {
    // Normalizar lista eliminando ceros a la izquierda
    var coeffs = List<int>.from(inputCoeffs);
    while (coeffs.isNotEmpty && coeffs.first == 0) {
      coeffs.removeAt(0);
    }

    if (coeffs.isEmpty) {
      return const StepByStepResolution(
        originalInputLatex: 'P(x) = 0',
        steps: [
          MathStep(
            index: 1,
            shortTitle: 'Polinomio nulo',
            latexExpression: 'P(x) = 0',
            pedagogicalNote: 'El polinomio nulo tiene infinitas raíces.',
          ),
        ],
        exactResultLatex: '0',
        decimalApproxLatex: '0',
      );
    }

    final polyLatex = 'P(x) = ${polynomialToLatex(coeffs)}';
    final List<MathStep> steps = [];

    // Verificar grados faltantes para la advertencia típica de examen
    final n = coeffs.length - 1;
    final List<int> missingDegrees = [];
    for (int i = 1; i < coeffs.length - 1; i++) {
      if (coeffs[i] == 0) {
        missingDegrees.add(n - i);
      }
    }

    String? missingDegreeWarning;
    if (missingDegrees.isNotEmpty) {
      final degsStr = missingDegrees.map(_plainDegreeTerm).join(', ');
      missingDegreeWarning =
          'El polinomio no tiene término en $degsStr. '
          'Es necesario colocar un 0 en la tabla de Ruffini para cada grado ausente.';
    }

    List<int> currentCoeffs = List<int>.from(coeffs);
    final List<int> foundRoots = [];

    // Si el término independiente es 0, sacar factor común x / x^k antes de Ruffini
    int zeroRootCount = 0;
    while (currentCoeffs.length > 1 && currentCoeffs.last == 0) {
      currentCoeffs.removeLast();
      zeroRootCount++;
    }

    if (zeroRootCount > 0) {
      final commonLatex = zeroRootCount == 1 ? 'x' : 'x^{$zeroRootCount}';
      final commonPlain = _plainDegreeTerm(zeroRootCount);
      final restLatex = currentCoeffs.length == 1
          ? '${currentCoeffs.first}'
          : '(${polynomialToLatex(currentCoeffs)})';
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Sacar factor común $commonPlain',
          latexExpression: '$polyLatex = $commonLatex \\cdot $restLatex',
          pedagogicalNote:
              'Como no hay término independiente (a₀ = 0), sacamos $commonPlain como factor común antes de buscar divisores.',
          warningTrick: currentCoeffs.length <= 2 ? missingDegreeWarning : null,
        ),
      );
    }

    // Paso 1 (o 2): Divisores del término independiente si queda grado >= 2
    if (currentCoeffs.length >= 3) {
      final lastCoeff = currentCoeffs.last;
      final divisors = getDivisors(lastCoeff);
      final divPos = divisors.where((d) => d > 0).toList()..sort();
      final divisorsFormatted = divPos.map((d) => '\\pm $d').join(', ');

      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Candidatos a raíz entera (Divisores de a₀)',
          latexExpression:
              '\\text{Divisores de } $lastCoeff = \\left\\{ $divisorsFormatted \\right\\}',
          pedagogicalNote:
              'Según el Teorema del Resto, las raíces enteras de un polinomio con coeficientes enteros deben ser divisores del término independiente ($lastCoeff).',
          warningTrick: missingDegreeWarning,
        ),
      );
    }

    // Iterar aplicando Ruffini mientras el grado sea >= 3
    while (currentCoeffs.length > 3) {
      int? successfulRoot;
      RuffiniStepResult? successfulStep;

      final currentDivisors = getDivisors(currentCoeffs.last);
      for (final candidate in currentDivisors) {
        final stepResult = executeRuffiniStep(currentCoeffs, candidate);
        if (stepResult.remainder == 0) {
          successfulRoot = candidate;
          successfulStep = stepResult;
          break;
        }
      }

      if (successfulRoot != null && successfulStep != null) {
        foundRoots.add(successfulRoot);
        final factorLatex = AlgebraicLatexFormatter.linearFactor(successfulRoot);

        steps.add(
          MathStep(
            index: steps.length + 1,
            shortTitle: 'Tabla de Ruffini con raíz x = $successfulRoot',
            latexExpression: successfulStep.toLatexTable(),
            pedagogicalNote:
                'Bajamos el primer coeficiente (${currentCoeffs.first}), multiplicamos por la raíz ($successfulRoot) y sumamos en columna. '
                'Como el resto es 0, x = $successfulRoot es raíz y divide exactamente al polinomio.',
            warningTrick:
                'La raíz x = $successfulRoot pasa al factor $factorLatex (se cambia el signo de la raíz).',
          ),
        );

        currentCoeffs = [
          ...successfulStep.quotientCoeffs,
          successfulStep.remainder,
        ]..removeLast();
      } else {
        // No se encontraron más raíces enteras por Ruffini
        break;
      }
    }

    // Si queda un polinomio de grado 2: ax² + bx + c
    if (currentCoeffs.length == 3) {
      final a = currentCoeffs[0];
      final b = currentCoeffs[1];
      final c = currentCoeffs[2];

      final quadPolyLatex = polynomialToLatex(currentCoeffs);
      final disc = b * b - 4 * a * c;

      if (disc >= 0) {
        final sqrtDisc = math.sqrt(disc);
        if (sqrtDisc == sqrtDisc.toInt()) {
          final sInt = sqrtDisc.toInt();
          final r1Num = -b + sInt;
          final r2Num = -b - sInt;
          final twoA = 2 * a;

          if (r1Num % twoA == 0 && r2Num % twoA == 0) {
            final r1 = r1Num ~/ twoA;
            final r2 = r2Num ~/ twoA;
            foundRoots.add(r1);
            foundRoots.add(r2);

            final f1 = AlgebraicLatexFormatter.linearFactor(r1);
            final f2 = AlgebraicLatexFormatter.linearFactor(r2);

            steps.add(
              MathStep(
                index: steps.length + 1,
                shortTitle: 'Resolver el cociente cuadrático restante',
                latexExpression:
                    '$quadPolyLatex = 0 \\implies x = \\frac{-${AlgebraicLatexFormatter.parenIfNegative(b)} \\pm \\sqrt{$disc}}{2 \\cdot ${AlgebraicLatexFormatter.parenIfNegative(a)}} \\implies x = $r1, \\; x = $r2',
                pedagogicalNote:
                    'Al llegar a grado 2, resolvemos la ecuación de segundo grado directamente para obtener las dos últimas raíces.',
                warningTrick:
                    'Las raíces $r1 y $r2 se convierten en los factores $f1 y $f2.',
              ),
            );
            currentCoeffs = [a];
          }
        }
      }
    }

    // Construcción de la factorización completa final
    final leadCoeff = coeffs.first;
    final factorParts = <String>[];
    if (leadCoeff != 1 && leadCoeff != -1) {
      factorParts.add('$leadCoeff');
    } else if (leadCoeff == -1) {
      factorParts.add('-');
    }

    if (zeroRootCount == 1) {
      factorParts.add('x');
    } else if (zeroRootCount > 1) {
      factorParts.add('x^{$zeroRootCount}');
    }

    for (final r in foundRoots) {
      factorParts.add(AlgebraicLatexFormatter.linearFactor(r));
    }

    if (currentCoeffs.length > 1) {
      factorParts.add('(${polynomialToLatex(currentCoeffs)})');
    }

    final factoredLatex = factorParts.join();
    final allRootsForDisplay = [
      if (zeroRootCount > 0) 0,
      ...foundRoots,
    ];
    final rootsFormatted = allRootsForDisplay.isEmpty
        ? r'\text{Sin raices enteras}'
        : allRootsForDisplay.map((r) => 'x = $r').join(', \\; ');

    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Factorización completa del polinomio',
        latexExpression: '$polyLatex = $factoredLatex',
        pedagogicalNote: allRootsForDisplay.isEmpty
            ? 'No se han encontrado raíces enteras entre los divisores.'
            : 'Expresamos el polinomio como producto de factores simples (x - r). Las raíces obtenidas son: ${allRootsForDisplay.map((r) => 'x = $r').join(', ')}.',
      ),
    );

    return StepByStepResolution(
      originalInputLatex: polyLatex,
      steps: steps,
      exactResultLatex: factoredLatex,
      decimalApproxLatex: rootsFormatted,
    );
  }
}
