import '../core/rational.dart';
import 'step_resolution.dart';

/// Métodos de resolución disponibles en el Modo 11 (Sistemas 3x3).
enum System3x3Method {
  gauss('Gauss'),
  cramer('Cramer');

  final String displayName;
  const System3x3Method(this.displayName);
}

/// Clasificación del sistema lineal según el Teorema de Rouché-Frobenius.
enum System3x3Classification {
  scd, // Sistema Compatible Determinado (solución única)
  sci, // Sistema Compatible Indeterminado (infinitas soluciones)
  si,  // Sistema Incompatible (sin solución)
}

/// Resultado estructurado del análisis de un sistema 3x3.
class System3x3Result {
  final System3x3Classification classification;
  final int rankA;
  final int rankAugmented;
  final Rational? x;
  final Rational? y;
  final Rational? z;
  final StepByStepResolution resolution;

  const System3x3Result({
    required this.classification,
    required this.rankA,
    required this.rankAugmented,
    required this.x,
    required this.y,
    required this.z,
    required this.resolution,
  });
}
