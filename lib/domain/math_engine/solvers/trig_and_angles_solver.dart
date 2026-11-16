import '../ast/ast_nodes.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import 'trigonometry/dms_solver.dart';
import 'trigonometry/exact_trig_solver.dart';

export 'trigonometry/dms_solver.dart';
export 'trigonometry/exact_trig_solver.dart';

enum AngleUnit { deg, rad }

class TrigAndAnglesSolver {
  /// Resuelve razones trigonométricas directas e inversas con valores exactos notables de ESO/Bachillerato.
  static StepByStepResolution solveTrig({
    required TrigFunction function,
    required ExprNode argNode,
    required AngleUnit unit,
    required double? evaluatedNumericArg,
    Rational? exactRationalArg,
    Rational? piMultipleRational,
  }) =>
      ExactTrigSolver.solveTrig(
        function: function,
        argNode: argNode,
        unit: unit,
        evaluatedNumericArg: evaluatedNumericArg,
        exactRationalArg: exactRationalArg,
        piMultipleRational: piMultipleRational,
      );

  /// Opera sumas y restas en Sistema Sexagesimal explicando los acarreos/préstamos en base 60.
  static StepByStepResolution solveDmsOperation({
    required String originalLatex,
    required List<({DmsValue value, bool isSubtract})> terms,
  }) =>
      DmsSolver.solveDmsOperation(
        originalLatex: originalLatex,
        terms: terms,
      );

  /// Convierte un ángulo decimal (ej. 34.52°) a Grados, Minutos y Segundos paso a paso.
  static StepByStepResolution solveDecimalToDms(
    double decimalDegrees, {
    String? originalLatex,
  }) =>
      DmsSolver.solveDecimalToDms(
        decimalDegrees,
        originalLatex: originalLatex,
      );
}
