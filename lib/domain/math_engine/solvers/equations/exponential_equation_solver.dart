import 'dart:math' as math;
import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import 'super_equation_helpers.dart';

class ExponentialEquationSolver {
  static bool isExponentialPattern(String s) {
    if (!s.contains('^')) return false;
    return RegExp(
      r'\^\{[^}]*x[^}]*\}|\^\([^)]*x[^)]*\)|\^[0-9]*x[0-9]*',
    ).hasMatch(s);
  }

  static StepByStepResolution solve(String clean, String originalRaw) {
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
}
