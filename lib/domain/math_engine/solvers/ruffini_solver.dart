import 'dart:math' as math;
import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import 'equations/eq_poly.dart';
import 'ruffini_helpers.dart';

export 'ruffini_helpers.dart' show RuffiniFactorization;

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

/// Resolucion paso a paso junto con la factorizacion estructurada (para verificarla).
class RuffiniOutcome {
  final StepByStepResolution resolution;
  final RuffiniFactorization factorization;
  const RuffiniOutcome(this.resolution, this.factorization);
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

  /// Ruffini con coeficientes racionales: se multiplica por el m.c.m. de los denominadores
  /// para trabajar con enteros (las raices no cambian) y al final se devuelve el factor `1/m`.
  static StepByStepResolution factorizeRational(List<Rational> coeffs) {
    if (coeffs.every((c) => c.isInteger)) {
      return factorize([for (final c in coeffs) c.numerator]);
    }
    final den = Rational.lcmMany([for (final c in coeffs) c.denominator]);
    final ints = [for (final c in coeffs) (c * Rational(den)).numerator];
    final n = coeffs.length - 1;
    final given = {for (var i = 0; i < coeffs.length; i++) n - i: coeffs[i]};
    final scaled = {for (var i = 0; i < ints.length; i++) n - i: Rational(ints[i])};
    final pLatex = 'P(x) = ${PolyOps.latex(given)}';
    final inner = factorize(ints);

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Quitar denominadores',
        latexExpression:
            '$pLatex \\;\\Rightarrow\\; Q(x) = $den \\cdot P(x) = ${PolyOps.latex(scaled)}',
        pedagogicalNote:
            'Ruffini funciona con coeficientes enteros: multiplicamos P(x) por el m.c.m. de los denominadores ($den). Q(x) y P(x) tienen las mismas raíces.',
        warningTrick: 'Al final hay que volver a P(x): P(x) = Q(x) / $den.',
      ),
      for (final st in inner.steps)
        MathStep(
          index: st.index + 1,
          shortTitle: st.shortTitle,
          latexExpression: st.latexExpression.replaceAll('P(x)', 'Q(x)'),
          pedagogicalNote: st.pedagogicalNote,
          warningTrick: st.warningTrick,
        ),
    ];
    final result = '\\frac{1}{$den}\\left(${inner.exactResultLatex}\\right)';
    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Volver a P(x)',
        latexExpression: 'P(x) = \\frac{Q(x)}{$den} = $result',
        pedagogicalNote: 'Dividimos entre $den para recuperar el polinomio original; las raíces son las mismas.',
      ),
    );
    return StepByStepResolution(
      originalInputLatex: pLatex,
      steps: steps,
      exactResultLatex: result,
      decimalApproxLatex: inner.decimalApproxLatex,
    );
  }

  /// Factoriza un polinomio mediante la Regla de Ruffini paso a paso
  static StepByStepResolution factorize(List<int> inputCoeffs) =>
      factorizeFull(inputCoeffs).resolution;

  /// Igual que [factorize], devolviendo ademas la factorizacion estructurada.
  ///
  /// Orden: factor comun (constante y `x^k`), candidatos `±p/q` (si `a_n != ±1` son racionales),
  /// Ruffini con raices enteras o racionales hasta grado 2, y remate con la formula cuadratica
  /// (raices racionales, irracionales o irreducible en R si Δ < 0).
  static RuffiniOutcome factorizeFull(List<int> inputCoeffs) {
    // Normalizar lista eliminando ceros a la izquierda
    final coeffs = List<int>.from(inputCoeffs);
    while (coeffs.isNotEmpty && coeffs.first == 0) {
      coeffs.removeAt(0);
    }

    if (coeffs.isEmpty) {
      return const RuffiniOutcome(
        StepByStepResolution(
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
        ),
        RuffiniFactorization(constant: 0, xPower: 0, roots: [], remaining: [0]),
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

    // Factor comun: x^k (sin termino independiente) y la constante (mcd con el signo de a_n).
    var current = List<int>.from(coeffs);
    int zeroRootCount = 0;
    while (current.length > 1 && current.last == 0) {
      current.removeLast();
      zeroRootCount++;
    }
    final content = Rational.gcdMany(current);
    final constant = current.first < 0 ? -content : content;
    if (constant != 1) {
      current = [for (final c in current) c ~/ constant];
    }

    if (zeroRootCount > 0 || (constant != 1 && current.length > 1)) {
      final cText = constant == 1 ? '' : (constant == -1 ? '-' : '$constant');
      final xText = zeroRootCount == 0
          ? ''
          : (zeroRootCount == 1 ? 'x' : 'x^{$zeroRootCount}');
      final commonLatex = '$cText$xText' == '-' ? '-1' : '$cText$xText';
      final commonPlain = '$cText${zeroRootCount == 0 ? '' : _plainDegreeTerm(zeroRootCount)}';
      final restLatex = current.length == 1
          ? '${current.first}'
          : '(${polynomialToLatex(current)})';
      final why = [
        if (zeroRootCount > 0)
          'no hay término independiente (a₀ = 0), así que ${_plainDegreeTerm(zeroRootCount)} es factor común',
        if (constant != 1)
          constant == -1
              ? 'cambiamos el signo para que el coeficiente principal sea positivo'
              : 'los coeficientes tienen un factor numérico común (${constant.abs()}${constant < 0 ? ' y el signo de a_n' : ''})',
      ].join('; ');
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Sacar factor común $commonPlain',
          latexExpression: '$polyLatex = $commonLatex \\cdot $restLatex',
          pedagogicalNote: 'Antes de buscar raíces: $why.',
          warningTrick: current.length <= 2 ? missingDegreeWarning : null,
        ),
      );
    }

    final foundRoots = <(int, int)>[];
    final rootsLatex = <String>[if (zeroRootCount > 0) 'x = 0'];
    final rootsPlain = <String>[if (zeroRootCount > 0) 'x = 0'];
    final factorParts = <String>[];

    // Candidatos ±p/q solo si todavia se buscaran raices con Ruffini (grado >= 3).
    if (current.length >= 4) {
      final a0 = current.last, an = current.first;
      final pos = RuffiniCandidates.positive(a0, an);
      final divA0 = RuffiniCandidates.positiveDivisors(a0).map((d) => '\\pm $d').join(', ');
      final divAn = RuffiniCandidates.positiveDivisors(an).map((d) => '\\pm $d').join(', ');
      final monic = an.abs() == 1;
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: monic
              ? 'Candidatos a raíz entera (Divisores de a₀)'
              : 'Candidatos a raíz racional (±p/q, p divide a a₀, q divide a aₙ)',
          latexExpression: monic
              ? '\\text{Divisores de } $a0 = \\left\\{ $divA0 \\right\\}'
              : '\\text{Divisores de } $a0 = \\left\\{ $divA0 \\right\\},\\; '
                  '\\text{divisores de } $an = \\left\\{ $divAn \\right\\} \\;\\Rightarrow\\; '
                  '\\pm\\frac{p}{q} \\in \\left\\{ ${RuffiniCandidates.listLatex(pos)} \\right\\}',
          pedagogicalNote: monic
              ? 'Según el Teorema del Resto, las raíces enteras de un polinomio con coeficientes enteros deben ser divisores del término independiente ($a0).'
              : 'Como aₙ = $an no es ±1, las raíces racionales son ±p/q con p divisor de a₀ ($a0) y q divisor de aₙ ($an), con la fracción simplificada.',
          warningTrick: missingDegreeWarning,
        ),
      );
    }

    // Iterar aplicando Ruffini mientras el grado sea >= 3
    while (current.length > 3) {
      (int, int)? hit;
      for (final cand in RuffiniCandidates.searchOrder(current.last, current.first)) {
        final d = RationalRuffini.divide(current, Rational(cand.$1, cand.$2));
        if (d.remainder.isZero) {
          hit = cand;
          break;
        }
      }
      if (hit == null) break; // sin mas raices racionales

      final (p, q) = hit;
      final rootRat = Rational(p, q);
      final String table;
      final List<int> next;
      if (q == 1) {
        final st = executeRuffiniStep(current, p);
        table = st.toLatexTable();
        next = st.quotientCoeffs;
      } else {
        final d = RationalRuffini.divide(current, rootRat);
        table = RationalRuffini.tableLatex(current, rootRat, d.quotient, d.products, d.remainder);
        next = [for (final c in d.quotient) (c / Rational(q)).numerator];
      }
      final factor = RuffiniCandidates.factorLatex(p, q);
      final rootText = q == 1 ? '$p' : '$p/$q';
      foundRoots.add(hit);
      factorParts.add(factor);
      rootsLatex.add('x = ${rootRat.toLatex()}');
      rootsPlain.add('x = $rootText');
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Tabla de Ruffini con raíz x = $rootText',
          latexExpression: table,
          pedagogicalNote:
              'Bajamos el primer coeficiente (${current.first}), multiplicamos por la raíz ($rootText) y sumamos en columna. '
              'Como el resto es 0, x = $rootText es raíz y divide exactamente al polinomio.',
          warningTrick: q == 1
              ? 'La raíz x = $p pasa al factor $factor (se cambia el signo de la raíz).'
              : 'La raíz x = $rootText pasa al factor primitivo $factor: el denominador ($q) se mueve a la x y el cociente de la tabla se divide entre $q.',
        ),
      );
      current = next;
    }

    // Remate: lineal, cuadratico (formula) o resto sin descomponer.
    var remaining = <int>[1];
    var absorbed = 1;
    String? stalledNote;
    var irreducibleReal = false;
    if (current.length == 3) {
      final qc = RuffiniQuadratic.solve(current[0], current[1], current[2]);
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: qc.title,
          latexExpression: qc.latex,
          pedagogicalNote: qc.note,
          warningTrick: qc.warning,
        ),
      );
      foundRoots.addAll(qc.rationalRoots);
      factorParts.add(qc.factorLatex);
      rootsLatex.addAll(qc.rootsLatex);
      rootsPlain.addAll(qc.rootsPlain);
      absorbed = qc.absorbedConstant;
      irreducibleReal = qc.irreducible;
      if (qc.irrational || qc.irreducible) remaining = current;
    } else if (current.length == 2) {
      final p = -current[1], q = current[0];
      final g = Rational.gcd(p, q);
      foundRoots.add((p ~/ g, q ~/ g));
      factorParts.add(RuffiniCandidates.factorLatex(p ~/ g, q ~/ g));
      rootsLatex.add('x = ${Rational(p, q).toLatex()}');
      rootsPlain.add('x = ${p ~/ g}${q ~/ g == 1 ? '' : '/${q ~/ g}'}');
    } else if (current.length > 3) {
      remaining = current;
      factorParts.add('(${polynomialToLatex(current)})');
      stalledNote =
          'No quedan más raíces racionales (ni enteras): el factor ${_plain(current)} se deja sin descomponer. '
          'Aun así puede tener raíces irracionales o complejas, que Ruffini no encuentra.';
    }

    // Construcción de la factorización completa final
    final shownConstant = constant * absorbed;
    final prefix = shownConstant == 1 ? '' : (shownConstant == -1 ? '-' : '$shownConstant');
    final xPart = zeroRootCount == 0
        ? ''
        : (zeroRootCount == 1 ? 'x' : 'x^{$zeroRootCount}');
    var factoredLatex = '$prefix$xPart${factorParts.join()}';
    if (factoredLatex.isEmpty) factoredLatex = '1';
    final noRootsText = irreducibleReal
        ? r'\text{Sin raices reales}'
        : r'\text{Sin raices racionales}';
    final rootsFormatted = rootsLatex.isEmpty ? noRootsText : rootsLatex.join(', \\; ');
    final hasRoots = rootsPlain.isNotEmpty && rootsLatex.isNotEmpty;

    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Factorización completa del polinomio',
        latexExpression: '$polyLatex = $factoredLatex',
        pedagogicalNote: hasRoots
            ? 'Expresamos el polinomio como producto de factores simples. Las raíces obtenidas son: ${rootsPlain.join(', ')}.${stalledNote == null ? '' : ' $stalledNote'}'
            : (stalledNote ??
                (irreducibleReal
                    ? 'No hay raíces reales: el polinomio no se descompone más en ℝ (ver el discriminante negativo).'
                    : 'No se han encontrado raíces racionales entre los candidatos.')),
      ),
    );

    return RuffiniOutcome(
      StepByStepResolution(
        originalInputLatex: polyLatex,
        steps: steps,
        exactResultLatex: factoredLatex,
        decimalApproxLatex: rootsFormatted,
      ),
      RuffiniFactorization(
        constant: constant,
        xPower: zeroRootCount,
        roots: foundRoots,
        remaining: remaining,
      ),
    );
  }

  static String _plain(List<int> coeffs) {
    final latex = polynomialToLatex(coeffs);
    return '(${latex.replaceAll(RegExp(r'\^\{(\d+)\}'), r'^$1')})';
  }
}
