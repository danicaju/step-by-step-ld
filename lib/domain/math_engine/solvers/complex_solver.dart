import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../models/complex_models.dart';
import 'complex/complex_arithmetic_solver.dart';
import 'complex/complex_euler_solver.dart';
import 'exact/exact_number.dart';
import 'complex/complex_polar_solver.dart';

export '../models/complex_models.dart';
export 'complex/complex_arithmetic_solver.dart';
export 'complex/complex_polar_solver.dart';
export 'complex/complex_polar_radical.dart';
export 'complex/complex_euler_solver.dart';

/// Facade modular para operaciones con números complejos en 1.º de Bachillerato / PAU.
/// Todas las APIs históricas se mantienen 100 % retrocompatibles.
class ComplexSolver {
  static StepByStepResolution solve({
    required ComplexOperation operation,
    required RationalComplex z1,
    RationalComplex? z2,
    Rational? polarModulus,
    double? polarAngleDegrees,
  }) {
    final second = z2 ?? RationalComplex.fromInts(1, 0);
    return switch (operation) {
      ComplexOperation.add => add(z1, second),
      ComplexOperation.subtract => subtract(z1, second),
      ComplexOperation.multiply => multiply(z1, second),
      ComplexOperation.divide => divide(z1, second),
      ComplexOperation.toPolar => toPolar(z1),
      ComplexOperation.fromPolar => fromPolar(
          modulus: polarModulus ?? Rational(1),
          angleDegrees: polarAngleDegrees ?? 0,
        ),
      ComplexOperation.powerOfI => powerOfI(z1.real.numerator),
      ComplexOperation.expZ => exp(_exact(z1.real), _exact(z1.imag)).resolution,
      ComplexOperation.lnZ => ln(_exact(z1.real), _exact(z1.imag)).resolution,
    };
  }

  static ComplexResult analyzeOperation({
    required ComplexOperation operation,
    required RationalComplex z1,
    RationalComplex? z2,
  }) {
    final second = z2 ?? RationalComplex.fromInts(1, 0);
    return switch (operation) {
      ComplexOperation.add =>
        ComplexResult(binomial: z1 + second, resolution: add(z1, second)),
      ComplexOperation.subtract =>
        ComplexResult(binomial: z1 - second, resolution: subtract(z1, second)),
      ComplexOperation.multiply =>
        ComplexResult(binomial: z1 * second, resolution: multiply(z1, second)),
      ComplexOperation.divide =>
        ComplexResult(binomial: z1 / second, resolution: divide(z1, second)),
      ComplexOperation.toPolar => analyzeToPolar(z1),
      ComplexOperation.fromPolar =>
        ComplexResult(resolution: fromPolar(modulus: z1.real, angleDegrees: z1.imag.toDouble())),
      ComplexOperation.powerOfI => ComplexResult(resolution: powerOfI(z1.real.numerator)),
      ComplexOperation.expZ => exp(_exact(z1.real), _exact(z1.imag)),
      ComplexOperation.lnZ => ln(_exact(z1.real), _exact(z1.imag)),
    };
  }

  static ExNum _exact(Rational r) => ExNum.rational(r);

  /// Exponencial compleja `e^(a+bi) = e^a (cos b + i sen b)` (b en radianes).
  static ComplexResult exp(ExNum a, ExNum b) => ComplexEulerSolver.exp(a, b);

  /// Logaritmo complejo principal `Ln z = ln|z| + i arg(z)`, con `arg(z)` en (-π, π].
  static ComplexResult ln(ExNum a, ExNum b) => ComplexEulerSolver.ln(a, b);

  /// Suma de complejos en forma binómica: (a + bi) + (c + di).
  static StepByStepResolution add(RationalComplex z1, RationalComplex z2) =>
      ComplexArithmeticSolver.add(z1, z2);

  /// Resta de complejos en forma binómica: (a + bi) - (c + di).
  static StepByStepResolution subtract(RationalComplex z1, RationalComplex z2) =>
      ComplexArithmeticSolver.subtract(z1, z2);

  /// Multiplicación de complejos en forma binómica con expansión distributiva.
  static StepByStepResolution multiply(RationalComplex z1, RationalComplex z2) =>
      ComplexArithmeticSolver.multiply(z1, z2);

  /// División de complejos multiplicando numerador y denominador por el conjugado.
  static StepByStepResolution divide(RationalComplex z1, RationalComplex z2) =>
      ComplexArithmeticSolver.divide(z1, z2);

  /// Análisis completo a Forma Polar `r_α` con deducción de cuadrante.
  static ComplexResult analyzeToPolar(RationalComplex z) =>
      ComplexPolarSolver.analyzeToPolar(z);

  /// Conversión de Forma Binómica a Forma Polar devolviendo únicamente la resolución por pasos.
  static StepByStepResolution toPolar(RationalComplex z) =>
      ComplexPolarSolver.toPolar(z);

  /// Potencias de la unidad imaginaria `i^n` con reducción cíclica mod 4.
  static StepByStepResolution powerOfI(int n) =>
      ComplexPolarSolver.powerOfI(n);

  /// Conversión inversa de Forma Polar `r_α` a Forma Binómica `a + bi`.
  static StepByStepResolution fromPolar({
    required Rational modulus,
    required double angleDegrees,
  }) =>
      ComplexPolarSolver.fromPolar(
        modulus: modulus,
        angleDegrees: angleDegrees,
      );
}
