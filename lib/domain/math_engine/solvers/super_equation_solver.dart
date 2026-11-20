import '../models/step_resolution.dart';
import 'polynomial_equation_solver.dart';
import 'equations/super_equation_helpers.dart';
import 'equations/biquadratic_equation_solver.dart';
import 'equations/eq_context.dart';
import 'equations/exponential_equation_solver.dart';
import 'equations/hyperbolic_equation_solver.dart';
import 'equations/identity_equation_solver.dart';
import 'equations/inverse_function_equation_solver.dart';
import 'equations/nth_root_equation_solver.dart';
import 'equations/irrational_equation_solver.dart';
import 'equations/logarithmic_equation_solver.dart';
import 'equations/rational_equation_solver.dart';
import 'equations/trigonometric_equation_solver.dart';
import 'exact/ext_expr.dart';
import 'trig_and_angles_solver.dart';

export 'equations/super_equation_helpers.dart';
export 'equations/biquadratic_equation_solver.dart';
export 'equations/irrational_equation_solver.dart';
export 'equations/logarithmic_equation_solver.dart';
export 'equations/exponential_equation_solver.dart';
export 'equations/rational_equation_solver.dart';
export 'equations/trigonometric_equation_solver.dart';

/// Super-Solver de M2 para ESO y Bachillerato. Clasifica la ecuacion sobre su AST
/// y la resuelve con el solver especializado (con comprobacion de soluciones):
/// bicuadradas, trigonometricas, logaritmicas, exponenciales, irracionales,
/// racionales y, por defecto, polinomicas (1.º, 2.º y grado >= 3 por Ruffini).
class SuperEquationSolver {
  static StepByStepResolution solve(
    String rawEquation, {
    AngleUnit angle = AngleUnit.deg,
  }) {
    final clean = SuperEquationHelpers.preClean(rawEquation);

    // 1. Bicuadrada pura (ax^4 + bx^2 + c = 0): cambio t = x^2
    if (BiquadraticEquationSolver.isBicuadraticPattern(clean)) {
      try {
        return BiquadraticEquationSolver.solve(clean, rawEquation);
      } catch (_) {
        // continua con el resto de solvers
      }
    }

    // 2. Solvers por tipo sobre el AST (cada intento con un contexto limpio).
    final attempts = <(bool Function(EqCtx), StepByStepResolution? Function(EqCtx))>[
      (IdentityEquationSolver.matches, IdentityEquationSolver.solve),
      (TrigonometricEquationSolver.matches, TrigonometricEquationSolver.solve),
      (LogarithmicEquationSolver.matches, LogarithmicEquationSolver.solve),
      (ExponentialEquationSolver.matches, ExponentialEquationSolver.solve),
      (NthRootEquationSolver.matches, NthRootEquationSolver.solve),
      (InverseFunctionEquationSolver.matches, InverseFunctionEquationSolver.solve),
      (HyperbolicEquationSolver.matches, HyperbolicEquationSolver.solve),
      (IrrationalEquationSolver.matches, IrrationalEquationSolver.solve),
      (RationalEquationSolver.matches, RationalEquationSolver.solve),
    ];
    for (final (matches, solve) in attempts) {
      try {
        final probe = EqCtx.parse(clean, angle: angle);
        if (!matches(probe)) continue;
        final res = solve(EqCtx.parse(clean, angle: angle));
        if (res != null) return res;
      } on ExtUnsupported {
        break;
      } on FormatException {
        continue;
      }
    }

    // 3. Por defecto: polinomicas (lineales, cuadraticas, grado >= 3).
    return PolynomialEquationSolver.solvePolynomialDirect(rawEquation);
  }
}
