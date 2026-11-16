import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../models/system_3x3_models.dart';
import 'systems_3x3/system_3x3_formatter.dart';
import 'systems_3x3/system_3x3_gauss.dart';
import 'systems_3x3/system_3x3_cramer.dart';

export '../models/system_3x3_models.dart';
export 'systems_3x3/system_3x3_formatter.dart';
export 'systems_3x3/system_3x3_gauss.dart';
export 'systems_3x3/system_3x3_cramer.dart';

class System3x3Solver {
  /// Resuelve un sistema 3x3 con coeficientes [Rational] (3 filas de 4 columnas: `[a, b, c, d]`).
  static StepByStepResolution solve({
    required List<List<Rational>> augmentedRows,
    System3x3Method method = System3x3Method.gauss,
  }) {
    return analyze(augmentedRows: augmentedRows, method: method).resolution;
  }

  /// Conveniencia para tests/llamadas con coeficientes enteros.
  static StepByStepResolution solveFromInts({
    required List<List<int>> augmentedRows,
    System3x3Method method = System3x3Method.gauss,
  }) {
    return analyze(
      augmentedRows: augmentedRows
          .map((r) => r.map((v) => Rational(v)).toList())
          .toList(),
      method: method,
    ).resolution;
  }

  /// Analiza y resuelve el sistema 3x3 devolviendo clasificación, rangos, terna exacta y pasos.
  static System3x3Result analyze({
    required List<List<Rational>> augmentedRows,
    System3x3Method method = System3x3Method.gauss,
  }) {
    if (augmentedRows.length != 3 ||
        augmentedRows.any((r) => r.length != 4)) {
      throw const FormatException(
        'El sistema 3x3 requiere 3 filas con 4 valores cada una (x, y, z y término independiente).',
      );
    }

    final eqLines = [
      for (final row in augmentedRows)
        System3x3Formatter.formatEquationLatex(row[0], row[1], row[2], row[3]),
    ];
    final originalInputLatex = '\\begin{cases} ${eqLines.join(' \\\\ ')} \\end{cases}';

    if (method == System3x3Method.cramer) {
      return System3x3CramerSolver.solveByCramer(augmentedRows, originalInputLatex);
    }
    return System3x3GaussSolver.solveByGauss(augmentedRows, originalInputLatex);
  }
}
