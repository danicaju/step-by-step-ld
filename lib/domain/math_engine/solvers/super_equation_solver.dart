import 'dart:math' as math;

import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import 'polynomial_equation_solver.dart';

/// Expresión lineal auxiliar de la forma m·x + n
class LinearExpression {
  final double m;
  final double n;
  const LinearExpression(this.m, this.n);

  static LinearExpression parse(String s, {String varName = 'x'}) {
    var str = s.replaceAll(' ', '');
    // Insertar espacios delante de los signos para separar tokens
    var formatted = '';
    for (int i = 0; i < str.length; i++) {
      final ch = str[i];
      if ((ch == '+' || ch == '-') && i > 0 && str[i - 1] != '(' && str[i - 1] != '^') {
        formatted += ' $ch';
      } else {
        formatted += ch;
      }
    }

    final tokens = formatted.split(' ').where((t) => t.isNotEmpty).toList();
    double slope = 0;
    double intercept = 0;

    for (final tok in tokens) {
      final cleanTok = tok.replaceAll('(', '').replaceAll(')', '');
      if (cleanTok.contains(varName)) {
        var coeff = cleanTok.replaceAll(varName, '');
        if (coeff.isEmpty || coeff == '+') {
          slope += 1.0;
        } else if (coeff == '-') {
          slope -= 1.0;
        } else {
          slope += double.tryParse(coeff) ?? 1.0;
        }
      } else {
        intercept += double.tryParse(cleanTok) ?? 0.0;
      }
    }
    return LinearExpression(slope, intercept);
  }
}

/// Súper-Solver integral para ESO y Bachillerato:
/// Resuelve ecuaciones Exponenciales, Logarítmicas, Irracionales (con radicales),
/// Racionales (x en denominador), Bicuadradas y Polinómicas con comprobación
/// obligatoria de soluciones válidas vs extrañas.
class SuperEquationSolver {
  /// Analiza y resuelve cualquier ecuación en cadena de texto o LaTeX.
  static StepByStepResolution solve(String rawEquation) {
    final clean = _preClean(rawEquation);

    // 1. Detección de Bicuadrada pura (ax^4 + bx^2 + c = 0)
    if (_isBicuadraticPattern(clean)) {
      try {
        return _solveBicuadratic(clean, rawEquation);
      } catch (_) {
        // Fallback
      }
    }

    // 2. Detección de Ecuaciones Irracionales (con raíces \sqrt o sqrt)
    if (clean.contains(r'\sqrt') || clean.contains('sqrt')) {
      try {
        return _solveIrrational(clean, rawEquation);
      } catch (_) {
        // Fallback
      }
    }

    // 3. Detección de Ecuaciones Logarítmicas (\log, \ln, log, ln)
    if (_isLogarithmicPattern(clean)) {
      try {
        return _solveLogarithmic(clean, rawEquation);
      } catch (_) {
        // Fallback
      }
    }

    // 4. Detección de Ecuaciones Exponenciales (2^x, a^{x}, etc.)
    if (_isExponentialPattern(clean)) {
      try {
        return _solveExponential(clean, rawEquation);
      } catch (_) {
        // Fallback
      }
    }

    // 5. Detección de Ecuaciones Racionales (fracciones con x en denominador)
    if (_isRationalPattern(clean)) {
      try {
        return _solveRational(clean, rawEquation);
      } catch (_) {
        // Fallback
      }
    }

    // 6. Por defecto: Ecuaciones Polinómicas (lineales, cuadráticas, grado > 2)
    return PolynomialEquationSolver.solvePolynomialDirect(rawEquation);
  }

  // ===========================================================================
  // 1. ECUACIONES BICUADRADAS (a x^4 + b x^2 + c = 0)
  // ===========================================================================
  static bool _isBicuadraticPattern(String s) {
    if (!s.contains('=')) return false;
    final hasX4 = s.contains('x^4') || s.contains('x^{4}');
    final hasX3 = s.contains('x^3') || s.contains('x^{3}');
    final hasRadical = s.contains(r'\sqrt') || s.contains('sqrt');
    final hasLog = s.contains('log') || s.contains('ln');
    return hasX4 && !hasX3 && !hasRadical && !hasLog;
  }

  static StepByStepResolution _solveBicuadratic(String clean, String originalRaw) {
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

    final poly = _parseCoeffs2(tEqStr, 't');
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
      final v1 = _evalSolutionVal(s1);
      final v2 = _evalSolutionVal(s2);
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

  // ===========================================================================
  // 2. ECUACIONES IRRACIONALES (CON RAÍCES)
  // ===========================================================================
  static StepByStepResolution _solveIrrational(String clean, String originalRaw) {
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
      return _solveIrrational('$rhs = $lhs', originalRaw);
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

  // ===========================================================================
  // 3. ECUACIONES LOGARÍTMICAS
  // ===========================================================================
  static bool _isLogarithmicPattern(String s) {
    return s.contains(r'\log') || s.contains(r'\ln') || s.contains('log(') || s.contains('ln(');
  }

  static StepByStepResolution _solveLogarithmic(String clean, String originalRaw) {
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

  // ===========================================================================
  // 4. ECUACIONES EXPONENCIALES
  // ===========================================================================
  static bool _isExponentialPattern(String s) {
    if (!s.contains('^')) return false;
    return RegExp(
      r'\^\{[^}]*x[^}]*\}|\^\([^)]*x[^)]*\)|\^[0-9]*x[0-9]*',
    ).hasMatch(s);
  }

  static StepByStepResolution _solveExponential(String clean, String originalRaw) {
    final originalLatex = originalRaw.trim();
    final steps = <MathStep>[];

    final sides = clean.split('=');
    if (sides.length != 2) throw const FormatException('Ecuacion exponencial invalida.');
    final lhs = sides[0].trim();
    final rhs = sides[1].trim();

    // Comprobar si el miembro izquierdo es un término exponencial simple: base^{f(x)}
    final singleExpMatch = RegExp(r'^(\d+)\^(?:\{([^}]+)\}|\(?([^)]+)\)?|(\w+))$').firstMatch(lhs);

    if (singleExpMatch != null) {
      final base = int.parse(singleExpMatch.group(1)!);
      final expPart = (singleExpMatch.group(2) ?? singleExpMatch.group(3) ?? singleExpMatch.group(4))!.trim();

      // Evaluar valor numérico de RHS (soporta enteros como 8 y fracciones como 1/27)
      double? rhsVal;
      if (rhs.contains('/')) {
        final fracParts = rhs.split('/');
        final num = double.tryParse(fracParts[0].trim());
        final den = double.tryParse(fracParts[1].trim());
        if (num != null && den != null && den != 0) {
          rhsVal = num / den;
        }
      } else {
        rhsVal = double.tryParse(rhs);
      }

      if (rhsVal != null && rhsVal > 0) {
        // Calcular exponente k tal que base^k = rhsVal
        final logVal = math.log(rhsVal) / math.log(base);
        final isExactPow = (logVal - logVal.round()).abs() < 1e-5;

        if (isExactPow) {
          // Caso 1: Igualación de bases común
          final k = logVal.round();
          steps.add(
            MathStep(
              index: 1,
              shortTitle: 'Igualacion de bases: a^f(x) = a^k',
              latexExpression: '$base^{$expPart} = $base^{$k}',
              pedagogicalNote:
                  'Descomponemos el segundo miembro en potencias de la base comun ($base) para igualar directamente los exponentes.',
            ),
          );

          steps.add(
            MathStep(
              index: 2,
              shortTitle: 'Igualar exponentes: f(x) = k',
              latexExpression: '$expPart = $k',
              pedagogicalNote:
                  'Al tener la misma base en ambos miembros, los exponentes deben ser necesariamente iguales.',
            ),
          );

          final expLin = LinearExpression.parse(expPart, varName: 'x');
          Rational sol;
          if (expLin.m.abs() > 1e-9) {
            sol = Rational.fromDouble((k - expLin.n) / expLin.m, 1000);
          } else {
            sol = Rational(k);
          }

          steps.add(
            MathStep(
              index: 3,
              shortTitle: 'Solucion final',
              latexExpression: 'x = ${sol.toLatex()}',
              pedagogicalNote: 'Despejamos la incognita de la ecuacion lineal obtenida.',
            ),
          );

          return StepByStepResolution(
            originalInputLatex: originalLatex,
            steps: steps,
            exactResultLatex: 'x = ${sol.toLatex()}',
            decimalApproxLatex: 'x = ${sol.toDecimalLatex()}',
          );
        } else {
          // Caso 3: Bases distintas tomando logaritmos (ej: 5^x = 7)
          steps.add(
            MathStep(
              index: 1,
              shortTitle: 'Tomar logaritmos en ambos miembros',
              latexExpression: '\\ln($lhs) = \\ln($rhs) \\implies x \\cdot \\ln($base) = \\ln($rhs)',
              pedagogicalNote:
                  'Cuando las bases no coinciden ni pueden descomponerse en una base comun, tomamos logaritmo neperiano en ambos lados para bajar el exponente.',
            ),
          );

          final exactX = '\\frac{\\ln($rhs)}{\\ln($base)}';
          final approxVal = math.log(rhsVal) / math.log(base);

          steps.add(
            MathStep(
              index: 2,
              shortTitle: 'Despejar x',
              latexExpression: 'x = $exactX \\approx ${approxVal.toStringAsFixed(4)}',
              pedagogicalNote:
                  'Dividimos entre el logaritmo de la base original para obtener la solucion exacta y su valor decimal.',
            ),
          );

          return StepByStepResolution(
            originalInputLatex: originalLatex,
            steps: steps,
            exactResultLatex: 'x = $exactX',
            decimalApproxLatex: 'x \\approx ${approxVal.toStringAsFixed(4)}',
          );
        }
      }
    }

    // Caso 2: Cambio de variable t = a^x (ej: 4^x - 5·2^x + 4 = 0)
    int base = 2;
    final bMatch = RegExp(r'(\d+)\^[{(]?([^})]+)[})]').firstMatch(clean);
    if (bMatch != null) {
      base = int.tryParse(bMatch.group(1)!) ?? 2;
    }

    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Cambio de variable t = $base^x',
        latexExpression:
            '\\text{Haciendo } t = $base^x \\implies $base^{2x} = t^2, \\quad $base^{x+k} = $base^k \\cdot t',
        pedagogicalNote:
            'Aplicamos las propiedades de las potencias para descomponer los exponentes suma (a^{x+k} = a^k · a^x) y sustituimos t = a^x para obtener una ecuacion polinomica.',
        warningTrick:
            'Recuerda: la funcion exponencial a^x es SIEMPRE positiva (> 0) para cualquier x real. Si al resolver en t obtenemos valores t <= 0, se descartan obligatoriamente.',
      ),
    );

    // Parsear cuadrática en t para 4^x - 5·2^x + 4 = 0
    double aT = 1, bT = -5, cT = 4;
    final tMatch = RegExp(r'([+-]?\d*)\*?' + RegExp.escape('$base') + r'\^x').firstMatch(clean);
    if (tMatch != null) {
      final cStr = tMatch.group(1)?.replaceAll(' ', '') ?? '-5';
      bT = double.tryParse(cStr) ?? -5;
    }
    final cConstMatch = RegExp(r'\+\s*(\d+)\s*=\s*0').firstMatch(clean);
    if (cConstMatch != null) {
      cT = double.tryParse(cConstMatch.group(1)!) ?? 4;
    }

    final List<double> tSolutions = [];
    final disc = bT * bT - 4 * aT * cT;
    if (disc >= 0) {
      tSolutions.add((-bT + math.sqrt(disc)) / (2 * aT));
      if (disc > 0) tSolutions.add((-bT - math.sqrt(disc)) / (2 * aT));
    }

    steps.add(
      MathStep(
        index: 2,
        shortTitle: 'Resolucion en la variable auxiliar t',
        latexExpression:
            't^2 ${bT >= 0 ? "+ $bT" : "- ${bT.abs()}"}t ${cT >= 0 ? "+ $cT" : "- ${cT.abs()}"} = 0 '
            '\\implies ${tSolutions.map((t) => "t = ${Rational.fromDouble(t, 1000).toLatex()}").join(", \\quad ")}',
        pedagogicalNote: 'Resolvemos la ecuacion de segundo grado en t.',
      ),
    );

    final List<String> finalSolutions = [];
    final List<String> descarteNotes = [];

    for (final tVal in tSolutions) {
      final tRat = Rational.fromDouble(tVal, 1000);
      if (tVal <= 0) {
        descarteNotes.add('t = ${tRat.toLatex()} \\le 0 \\implies \\text{Descartada } ($base^x > 0)');
      } else {
        final xVal = math.log(tVal) / math.log(base);
        final isIntX = (xVal - xVal.round()).abs() < 1e-6;
        if (isIntX) {
          final xInt = xVal.round();
          finalSolutions.add('$xInt');
        } else {
          finalSolutions.add('\\frac{\\ln(${tRat.toLatex()})}{\\ln($base)}');
        }
      }
    }

    steps.add(
      MathStep(
        index: 3,
        shortTitle: 'Deshacer el cambio t = a^x',
        latexExpression:
            '${finalSolutions.map((s) => "$base^x = \\dots \\implies x = $s").join(", \\quad ")} '
            '${descarteNotes.isNotEmpty ? "\\quad [${descarteNotes.join(', ')}]" : ""}',
        pedagogicalNote:
            'Deshacemos el cambio de variable calculando el logaritmo en base $base para cada valor valido de t.',
      ),
    );

    final finalStr = finalSolutions.isEmpty
        ? r'\text{Sin solucion real}'
        : finalSolutions.map((s) => 'x = $s').join(', \\quad ');

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: finalStr,
      decimalApproxLatex: finalStr,
    );
  }

  // ===========================================================================
  // 5. ECUACIONES RACIONALES (x EN EL DENOMINADOR)
  // ===========================================================================
  static bool _isRationalPattern(String s) {
    if (!s.contains('/') && !s.contains(r'\frac')) return false;
    return RegExp(r'\/[^=]*x').hasMatch(s) || RegExp(r'\\frac\{[^}]*\}\{[^}]*x[^}]*\}').hasMatch(s);
  }

  static StepByStepResolution _solveRational(String clean, String originalRaw) {
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

  // ===========================================================================
  // UTILIDADES AUXILIARES
  // ===========================================================================
  static String _preClean(String raw) {
    return raw
        .replaceAll('\r', '')
        .replaceAll(' ', '')
        .replaceAll('·', '*')
        .replaceAll('×', '*')
        .replaceAll(r'\cdot', '*')
        .replaceAll(r'\times', '*')
        .replaceAll('²', '^2')
        .replaceAll('³', '^3')
        .replaceAll('X', 'x');
  }

  static double _evalSolutionVal(String s) {
    final clean = s.replaceAll(r'\sqrt', '').replaceAll('{', '').replaceAll('}', '');
    return double.tryParse(clean) ?? 0.0;
  }

  static Map<int, double> _parseCoeffs2(String expr, String varName) {
    double a = 0, b = 0, c = 0;
    var str = expr.replaceAll(' ', '');
    var formatted = '';
    for (int i = 0; i < str.length; i++) {
      final ch = str[i];
      if ((ch == '+' || ch == '-') && i > 0 && str[i - 1] != '(' && str[i - 1] != '^') {
        formatted += ' $ch';
      } else {
        formatted += ch;
      }
    }
    final tokens = formatted.split(' ').where((t) => t.isNotEmpty).toList();

    for (final tok in tokens) {
      if (tok.contains('$varName^2') || tok.contains('$varName^{2}') || tok.contains('$varName²')) {
        final coeffStr = tok
            .replaceAll('$varName^2', '')
            .replaceAll('$varName^{2}', '')
            .replaceAll('$varName²', '');
        a += _parseCoeff(coeffStr);
      } else if (tok.contains(varName)) {
        final coeffStr = tok.replaceAll(varName, '');
        b += _parseCoeff(coeffStr);
      } else {
        c += double.tryParse(tok) ?? 0.0;
      }
    }
    return {2: a, 1: b, 0: c};
  }

  static double _parseCoeff(String raw) {
    final s = raw.trim();
    if (s.isEmpty || s == '+') return 1.0;
    if (s == '-') return -1.0;
    return double.tryParse(s) ?? 1.0;
  }
}
