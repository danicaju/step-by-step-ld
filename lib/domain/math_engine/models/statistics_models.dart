import '../core/rational.dart';
import 'step_resolution.dart';

/// Par estadístico `(x_i, f_i)` para el cálculo de 1 variable.
class StatDataPoint {
  final Rational xi;
  final int fi;

  const StatDataPoint(this.xi, [this.fi = 1]);
}

/// Resultado completo del análisis estadístico unidimensional.
class StatisticsResult {
  final int nTotal;
  final Rational mean;
  final Rational variance;
  final double stdDevDouble;
  final String stdDevLatex;
  final List<Rational> modes;
  final Rational median;
  final Rational q1;
  final Rational q3;
  final StepByStepResolution resolution;

  const StatisticsResult({
    required this.nTotal,
    required this.mean,
    required this.variance,
    required this.stdDevDouble,
    required this.stdDevLatex,
    required this.modes,
    required this.median,
    required this.q1,
    required this.q3,
    required this.resolution,
  });
}

/// Punto bidimensional (x, y) para estadística de 2 variables.
class TwoVarPoint {
  final Rational x;
  final Rational y;
  const TwoVarPoint(this.x, this.y);
}

class StatisticsTwoVarResult {
  final Rational meanX;
  final Rational meanY;
  final Rational varX;
  final Rational varY;
  final Rational covXY;
  final Rational? slopeM;
  final Rational? interceptN;
  final double? pearsonR;
  final StepByStepResolution resolution;

  const StatisticsTwoVarResult({
    required this.meanX,
    required this.meanY,
    required this.varX,
    required this.varY,
    required this.covXY,
    required this.slopeM,
    required this.interceptN,
    required this.pearsonR,
    required this.resolution,
  });
}
