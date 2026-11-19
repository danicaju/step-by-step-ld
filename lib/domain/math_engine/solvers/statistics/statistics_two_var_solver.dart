import 'dart:math' as math;

import '../../core/rational.dart';
import '../../models/statistics_models.dart';
import '../../models/step_resolution.dart';

/// Solver de Estadística Bidimensional (Regresión lineal, Pearson r y manejo de varianza cero).
class StatisticsTwoVarSolver {
  static StatisticsTwoVarResult analyze(List<TwoVarPoint> points) {
    if (points.length < 2) {
      throw const FormatException('Se necesitan al menos 2 pares de datos (x, y).');
    }
    final n = points.length;
    Rational sumX = Rational(0);
    Rational sumY = Rational(0);
    Rational sumX2 = Rational(0);
    Rational sumY2 = Rational(0);
    Rational sumXY = Rational(0);

    for (final p in points) {
      sumX = sumX + p.x;
      sumY = sumY + p.y;
      sumX2 = sumX2 + (p.x * p.x);
      sumY2 = sumY2 + (p.y * p.y);
      sumXY = sumXY + (p.x * p.y);
    }

    final nRat = Rational(n);
    final meanX = sumX / nRat;
    final meanY = sumY / nRat;

    final varX = (sumX2 / nRat) - (meanX * meanX);
    final varY = (sumY2 / nRat) - (meanY * meanY);
    final covXY = (sumXY / nRat) - (meanX * meanY);

    final steps = <MathStep>[];

    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Paso 1: Medias marginales',
        latexExpression:
            '\\bar{x} = \\frac{\\sum x_{i}}{N} = ${meanX.toLatex()}, \\quad '
            '\\bar{y} = \\frac{\\sum y_{i}}{N} = ${meanY.toLatex()}',
        pedagogicalNote:
            'Calculamos el centro de gravedad (x̄, ȳ) de la distribución bidimensional.',
      ),
    );

    steps.add(
      MathStep(
        index: 2,
        shortTitle: 'Paso 2: Varianzas y covarianza',
        latexExpression:
            '\\sigma_{x}^2 = ${varX.toLatex()}, \\quad '
            '\\sigma_{y}^2 = ${varY.toLatex()}, \\quad '
            '\\sigma_{xy} = ${covXY.toLatex()}',
        pedagogicalNote:
            'Calculamos la dispersión de cada variable y la covarianza que mide la relación lineal conjunta.',
      ),
    );

    Rational? slopeM;
    Rational? interceptN;
    double? pearsonR;
    String regLatex;

    if (varX.isZero) {
      regLatex = 'x = ${meanX.toLatex()} \\quad (\\text{Varianza } \\sigma_{x}^2 = 0)';
      steps.add(
        MathStep(
          index: 3,
          shortTitle: 'Paso 3: Varianza cero (Recta vertical)',
          latexExpression: regLatex,
          pedagogicalNote:
              'Al ser la varianza de x igual a cero, todos los valores de x son idénticos y la recta de regresión es perfectamente vertical.',
        ),
      );
    } else {
      slopeM = covXY / varX;
      interceptN = meanY - (slopeM * meanX);

      final varXDouble = varX.toDouble();
      final varYDouble = varY.toDouble();
      if (varXDouble > 0 && varYDouble > 0) {
        pearsonR = covXY.toDouble() / (math.sqrt(varXDouble) * math.sqrt(varYDouble));
      }

      final rStr = pearsonR != null ? pearsonR.toStringAsFixed(4) : '0';
      final nLatex = interceptN.isNegative
          ? '- ${interceptN.abs().toLatex()}'
          : '+ ${interceptN.toLatex()}';
      regLatex = 'y = ${slopeM.toLatex()}x $nLatex';

      steps.add(
        MathStep(
          index: 3,
          shortTitle: 'Paso 3: Recta de regresión y Pearson r',
          latexExpression: '$regLatex, \\quad r = $rStr',
          pedagogicalNote:
              'La pendiente de la recta es m = σ_xy / σ_x² y r mide la fuerza de la correlación lineal entre -1 y 1.',
        ),
      );
    }

    final res = StepByStepResolution(
      originalInputLatex: 'N = $n',
      steps: steps,
      exactResultLatex: regLatex,
      decimalApproxLatex: regLatex,
    );

    return StatisticsTwoVarResult(
      meanX: meanX,
      meanY: meanY,
      varX: varX,
      varY: varY,
      covXY: covXY,
      slopeM: slopeM,
      interceptN: interceptN,
      pearsonR: pearsonR,
      resolution: res,
    );
  }

  static StepByStepResolution solve(List<TwoVarPoint> points) =>
      analyze(points).resolution;

  /// Anade a la regresion la estimacion `ŷ(x0) = m·x0 + n` para cada x pedido (fila con x y sin y).
  static StepByStepResolution withEstimates(
    StatisticsTwoVarResult r,
    List<TwoVarPoint> points,
    List<Rational> xs,
  ) {
    final m = r.slopeM, n = r.interceptN;
    if (xs.isEmpty || m == null || n == null) return r.resolution;
    final minX = points.map((p) => p.x.toDouble()).reduce(math.min);
    final maxX = points.map((p) => p.x.toDouble()).reduce(math.max);
    final steps = List<MathStep>.of(r.resolution.steps);
    final results = <String>[];
    for (final x0 in xs) {
      final y0 = m * x0 + n;
      final outside = x0.toDouble() < minX || x0.toDouble() > maxX;
      results.add('\\hat{y}(${x0.toLatex()}) = ${y0.toLatex()}');
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Paso ${steps.length + 1}: Estimación de y para x = ${x0.toLatex()}',
          latexExpression:
              '\\hat{y}(${x0.toLatex()}) = ${m.toLatex()} \\cdot ${x0.isNegative ? '\\left(${x0.toLatex()}\\right)' : x0.toLatex()} ${n.isNegative ? '-' : '+'} ${n.abs().toLatex()} = ${y0.toLatex()}',
          pedagogicalNote:
              'Sustituimos el valor de x en la recta de regresión y = mx + n para predecir y.',
          warningTrick: outside
              ? 'Cuidado: x = ${x0.toLatex()} está fuera del rango de los datos (${minX.toStringAsFixed(0)} a ${maxX.toStringAsFixed(0)}); es una extrapolación y la predicción es menos fiable.'
              : 'x = ${x0.toLatex()} está dentro del rango de los datos (interpolación): la estimación es fiable si r es cercano a ±1.',
        ),
      );
    }
    final reg = r.resolution.exactResultLatex;
    return StepByStepResolution(
      originalInputLatex: r.resolution.originalInputLatex,
      steps: steps,
      exactResultLatex: '$reg,\\; ${results.join(',\\; ')}',
      decimalApproxLatex: r.resolution.decimalApproxLatex,
    );
  }
}
