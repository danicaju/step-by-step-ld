import '../models/step_resolution.dart';
import 'polynomial_equation_solver.dart';
import 'equations/super_equation_helpers.dart';
import 'equations/biquadratic_equation_solver.dart';
import 'equations/irrational_equation_solver.dart';
import 'equations/logarithmic_equation_solver.dart';
import 'equations/exponential_equation_solver.dart';
import 'equations/rational_equation_solver.dart';

export 'equations/super_equation_helpers.dart';
export 'equations/biquadratic_equation_solver.dart';
export 'equations/irrational_equation_solver.dart';
export 'equations/logarithmic_equation_solver.dart';
export 'equations/exponential_equation_solver.dart';
export 'equations/rational_equation_solver.dart';

/// Súper-Solver integral para ESO y Bachillerato:
/// Resuelve ecuaciones Exponenciales, Logarítmicas, Irracionales (con radicales),
/// Racionales (x en denominador), Bicuadradas y Polinómicas con comprobación
/// obligatoria de soluciones válidas vs extrañas.
class SuperEquationSolver {
  /// Analiza y resuelve cualquier ecuación en cadena de texto o LaTeX.
  static StepByStepResolution solve(String rawEquation) {
    final clean = SuperEquationHelpers.preClean(rawEquation);

    // 1. Detección de Bicuadrada pura (ax^4 + bx^2 + c = 0)
    if (BiquadraticEquationSolver.isBicuadraticPattern(clean)) {
      try {
        return BiquadraticEquationSolver.solve(clean, rawEquation);
      } catch (_) {
        // Fallback
      }
    }

    // 2. Detección de Ecuaciones Irracionales (con raíces \sqrt o sqrt)
    if (clean.contains(r'\sqrt') || clean.contains('sqrt')) {
      try {
        return IrrationalEquationSolver.solve(clean, rawEquation);
      } catch (_) {
        // Fallback
      }
    }

    // 3. Detección de Ecuaciones Logarítmicas (\log, \ln, log, ln)
    if (LogarithmicEquationSolver.isLogarithmicPattern(clean)) {
      try {
        return LogarithmicEquationSolver.solve(clean, rawEquation);
      } catch (_) {
        // Fallback
      }
    }

    // 4. Detección de Ecuaciones Exponenciales (2^x, a^{x}, etc.)
    if (ExponentialEquationSolver.isExponentialPattern(clean)) {
      try {
        return ExponentialEquationSolver.solve(clean, rawEquation);
      } catch (_) {
        // Fallback
      }
    }

    // 5. Detección de Ecuaciones Racionales (fracciones con x en denominador)
    if (RationalEquationSolver.isRationalPattern(clean)) {
      try {
        return RationalEquationSolver.solve(clean, rawEquation);
      } catch (_) {
        // Fallback
      }
    }

    // 6. Por defecto: Ecuaciones Polinómicas (lineales, cuadráticas, grado > 2)
    return PolynomialEquationSolver.solvePolynomialDirect(rawEquation);
  }
}
