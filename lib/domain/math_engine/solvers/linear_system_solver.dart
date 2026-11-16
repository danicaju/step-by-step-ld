import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/linear_system_models.dart';
import '../models/step_resolution.dart';
import 'systems_2x2/system_2x2_helpers.dart';
import 'systems_2x2/system_2x2_substitution.dart';
import 'systems_2x2/system_2x2_equating.dart';
import 'systems_2x2/system_2x2_elimination.dart';
import 'systems_2x2/system_unordered_parser.dart';
import 'systems_2x2/system_nxn_solver.dart';

export '../models/linear_system_models.dart';
export 'systems_2x2/system_2x2_helpers.dart';
export 'systems_2x2/system_2x2_substitution.dart';
export 'systems_2x2/system_2x2_equating.dart';
export 'systems_2x2/system_2x2_elimination.dart';
export 'systems_2x2/system_unordered_parser.dart';
export 'systems_2x2/system_nxn_solver.dart';

class LinearSystemSolver {
  /// Representa una ecuación lineal en dos variables: ax + by = c
  static String formatEquation(int a, int b, int c) =>
      System2x2Helpers.formatEquation(a, b, c);

  /// Parsea cualquier ecuación lineal desordenada y la agrupa a forma canónica.
  static ParsedLinearEquation parseUnorderedEquation(
    String raw, {
    List<String> vars = const ['x', 'y', 'z', 'w'],
  }) =>
      SystemUnorderedParser.parse(raw, vars: vars);

  /// Resuelve un sistema 2x2 por el método especificado
  static StepByStepResolution solve({
    required int a1,
    required int b1,
    required int c1,
    required int a2,
    required int b2,
    required int c2,
    SystemResolutionMethod method = SystemResolutionMethod.sustitucion,
  }) {
    final eq1Latex = formatEquation(a1, b1, c1);
    final eq2Latex = formatEquation(a2, b2, c2);
    final systemLatex = '\\begin{cases} $eq1Latex \\\\ $eq2Latex \\end{cases}';

    final int det = a1 * b2 - a2 * b1;
    final int detX = c1 * b2 - c2 * b1;
    final int detY = a1 * c2 - a2 * c1;

    // Caso 1: Determinante nulo (Paralelas o Coincidentes)
    if (det == 0) {
      final isCompatibleIndeterminate = detX == 0 && detY == 0;
      final List<MathStep> steps = [];

      final propLatex = (a2 != 0 && b2 != 0)
          ? '${AlgebraicLatexFormatter.signedFraction(a1, a2)} = ${AlgebraicLatexFormatter.signedFraction(b1, b2)} \\quad \\left(a_{1} b_{2} - a_{2} b_{1} = 0\\right)'
          : 'a_{1} b_{2} - a_{2} b_{1} = $a1 \\cdot $b2 - $a2 \\cdot $b1 = 0';

      steps.add(
        MathStep(
          index: 1,
          shortTitle: 'Análisis de proporcionalidad de coeficientes',
          latexExpression: propLatex,
          pedagogicalNote:
              'Los coeficientes de las incógnitas son proporcionales (determinante nulo), lo que indica que las dos rectas tienen la misma inclinación.',
        ),
      );

      if (isCompatibleIndeterminate) {
        steps.add(
          const MathStep(
            index: 2,
            shortTitle: 'Sistema Compatible Indeterminado (SCI)',
            latexExpression: '0 = 0 \\implies \\text{S.C.I.}',
            pedagogicalNote:
                'Las dos ecuaciones representan la misma recta (rectas coincidentes). Cualquier punto de la recta es solución del sistema (infinitas soluciones).',
            warningTrick:
                'Si al operar resulta 0 = 0, las ecuaciones son dependientes y el sistema tiene infinitas soluciones (SCI).',
          ),
        );
        return StepByStepResolution(
          originalInputLatex: systemLatex,
          steps: steps,
          exactResultLatex: r'\text{Infinitas soluciones (S.C.I.)}',
          decimalApproxLatex: r'\text{Infinitas}',
        );
      } else {
        steps.add(
          const MathStep(
            index: 2,
            shortTitle: 'Sistema Incompatible (SI)',
            latexExpression: '0 \\neq k \\implies \\text{S.I.}',
            pedagogicalNote:
                'Las dos rectas son paralelas y nunca se cortan en ningún punto (sin solución).',
            warningTrick:
                'Si al operar resulta una contradicción como 0 = k (con k ≠ 0), el sistema es incompatible y no tiene solución (SI).',
          ),
        );
        return StepByStepResolution(
          originalInputLatex: systemLatex,
          steps: steps,
          exactResultLatex: r'\text{Sin solucion (S.I.)}',
          decimalApproxLatex: r'\text{Sin sol}',
        );
      }
    }

    // Caso 2: Determinante != 0 (Sistema Compatible Determinado)
    final xRational = Rational(detX, det);
    final yRational = Rational(detY, det);

    return switch (method) {
      SystemResolutionMethod.sustitucion => System2x2SubstitutionSolver.solve(
          a1: a1,
          b1: b1,
          c1: c1,
          a2: a2,
          b2: b2,
          c2: c2,
          systemLatex: systemLatex,
          xRational: xRational,
          yRational: yRational,
        ),
      SystemResolutionMethod.igualacion => System2x2EquatingSolver.solve(
          a1: a1,
          b1: b1,
          c1: c1,
          a2: a2,
          b2: b2,
          c2: c2,
          systemLatex: systemLatex,
          xRational: xRational,
          yRational: yRational,
        ),
      SystemResolutionMethod.reduccion => System2x2EliminationSolver.solve(
          a1: a1,
          b1: b1,
          c1: c1,
          a2: a2,
          b2: b2,
          c2: c2,
          systemLatex: systemLatex,
          xRational: xRational,
          yRational: yRational,
        ),
    };
  }

  /// Resuelve un sistema de N ecuaciones lineales (N = 2, 3 o 4) con coeficientes exactos [Rational].
  static StepByStepResolution solveNxN({
    required List<List<Rational>> augmentedRows,
    SystemResolutionMethod method = SystemResolutionMethod.sustitucion,
  }) =>
      SystemNxnSolver.solveNxN(
        augmentedRows: augmentedRows,
        solve2x2: solve,
        method: method,
      );

  /// Resuelve un conjunto de ecuaciones en texto libre con entrada desordenada.
  static StepByStepResolution solveFromEquations(
    List<String> rawEquations, {
    SystemResolutionMethod method = SystemResolutionMethod.sustitucion,
  }) =>
      SystemNxnSolver.solveFromEquations(
        rawEquations,
        solveNxN: solveNxN,
        method: method,
      );
}
