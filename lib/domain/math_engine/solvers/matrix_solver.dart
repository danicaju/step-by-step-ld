import '../core/rational.dart';
import '../models/matrix_models.dart';
import '../models/step_resolution.dart';
import 'matrices/matrix_arithmetic_solver.dart';
import 'matrices/matrix_determinant_solver.dart';
import 'matrices/matrix_inversion_solver.dart';
import 'matrices/matrix_gauss_cramer_solver.dart';

export '../models/matrix_models.dart';
export 'matrices/matrix_helpers.dart';
export 'matrices/matrix_arithmetic_solver.dart';
export 'matrices/matrix_determinant_solver.dart';
export 'matrices/matrix_inversion_solver.dart';
export 'matrices/matrix_gauss_cramer_solver.dart';

class MatrixSolver {
  /// Enrutador principal de operaciones matriciales del Modo 8.
  static StepByStepResolution solve({
    required MatrixOperation operation,
    RationalMatrix? matrixA,
    RationalMatrix? a,
    RationalMatrix? matrixB,
    RationalMatrix? b,
    Rational? scalarK,
    Rational? scalar,
  }) {
    final effectiveA = matrixA ?? a;
    if (effectiveA == null) {
      throw ArgumentError('Falta la matriz A.');
    }
    final effectiveB = matrixB ?? b;
    final effectiveK = scalarK ?? scalar ?? Rational(1);

    return switch (operation) {
      MatrixOperation.determinant => determinant(effectiveA),
      MatrixOperation.adjoint => adjoint(effectiveA),
      MatrixOperation.inverse => inverse(effectiveA),
      MatrixOperation.transpose => transpose(effectiveA),
      MatrixOperation.scalarMultiply => scalarMultiply(effectiveK, effectiveA),
      MatrixOperation.gauss => gauss(effectiveA, effectiveB),
      MatrixOperation.cramer => () {
          if (effectiveB == null) {
            throw const FormatException('La Regla de Cramer requiere el vector de términos independientes B.');
          }
          return cramer(effectiveA, effectiveB);
        }(),
      MatrixOperation.multiply => () {
          if (effectiveB == null) {
            throw const FormatException('El producto de matrices requiere la matriz B.');
          }
          return multiply(effectiveA, effectiveB);
        }(),
      MatrixOperation.add => () {
          if (effectiveB == null) {
            throw const FormatException('La suma de matrices requiere la matriz B.');
          }
          return add(effectiveA, effectiveB);
        }(),
      MatrixOperation.subtract => () {
          if (effectiveB == null) {
            throw const FormatException('La resta de matrices requiere la matriz B.');
          }
          return subtract(effectiveA, effectiveB);
        }(),
    };
  }

  static StepByStepResolution add(RationalMatrix a, RationalMatrix b) =>
      MatrixArithmeticSolver.add(a, b);

  static StepByStepResolution subtract(RationalMatrix a, RationalMatrix b) =>
      MatrixArithmeticSolver.subtract(a, b);

  static StepByStepResolution scalarMultiply(Rational k, RationalMatrix a) =>
      MatrixArithmeticSolver.scalarMultiply(k, a);

  static StepByStepResolution multiply(RationalMatrix a, RationalMatrix b) =>
      MatrixArithmeticSolver.multiply(a, b);

  static StepByStepResolution determinant(RationalMatrix a) =>
      MatrixDeterminantSolver.determinant(a);

  static StepByStepResolution adjoint(RationalMatrix a) =>
      MatrixInversionSolver.adjoint(a);

  static StepByStepResolution inverse(RationalMatrix a) =>
      MatrixInversionSolver.inverse(a);

  static StepByStepResolution transpose(RationalMatrix a) =>
      MatrixArithmeticSolver.transpose(a);

  static StepByStepResolution cramer(RationalMatrix a, RationalMatrix b) =>
      MatrixGaussCramerSolver.cramer(a, b);

  static StepByStepResolution gauss(RationalMatrix a, [RationalMatrix? b]) =>
      MatrixGaussCramerSolver.gauss(a, b);
}
