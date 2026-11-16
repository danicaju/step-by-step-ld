import '../core/rational.dart';

enum SystemResolutionMethod {
  sustitucion('Sustitución'),
  igualacion('Igualación'),
  reduccion('Reducción');

  final String displayName;
  const SystemResolutionMethod(this.displayName);
}

/// Representa una ecuación lineal desordenada que ha sido agrupada en forma canónica.
class ParsedLinearEquation {
  final Map<String, Rational> coefficients;
  final Rational constant;
  final String originalRaw;
  final String orderedLatex;

  const ParsedLinearEquation({
    required this.coefficients,
    required this.constant,
    required this.originalRaw,
    required this.orderedLatex,
  });
}
