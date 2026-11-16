import '../../core/rational.dart';
import '../../models/matrix_models.dart';
import '../../models/step_resolution.dart';
import 'matrix_helpers.dart';

class MatrixArithmeticSolver {
  /// Suma de matrices elemento a elemento: `A + B`.
  static StepByStepResolution add(RationalMatrix a, RationalMatrix b) {
    if (a.rowCount != b.rowCount || a.colCount != b.colCount) {
      throw const FormatException('Las matrices A y B deben tener las mismas dimensiones.');
    }
    final result = a + b;
    final colSpec = List.filled(a.colCount, 'c').join();
    final exprRows = [
      for (int r = 0; r < a.rowCount; r++)
        [
          for (int c = 0; c < a.colCount; c++)
            MatrixHelpers.formatBinarySumCell(a.at(r, c), b.at(r, c), isSubtract: false),
        ].join(' & '),
    ].join(' \\\\\n');

    final step1Matrix = '\\left(\\begin{array}{$colSpec}\n$exprRows\n\\end{array}\\right)';

    return StepByStepResolution(
      originalInputLatex: '${a.toLatex()} + ${b.toLatex()}',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Sumar elemento a elemento',
          latexExpression: 'A + B = $step1Matrix',
          pedagogicalNote:
              'Sumamos cada coeficiente de la matriz A con el elemento situado en la misma fila y columna de B (cᵢⱼ = aᵢⱼ + bᵢⱼ).',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Matriz suma simplificada',
          latexExpression: 'A + B = ${result.toLatex()}',
          pedagogicalNote:
              'Operamos cada casilla y reducimos las fracciones resultantes a irreducibles.',
        ),
      ],
      exactResultLatex: result.toLatex(),
      decimalApproxLatex: result.toDecimalLatex(),
    );
  }

  /// Resta de matrices elemento a elemento: `A - B`.
  static StepByStepResolution subtract(RationalMatrix a, RationalMatrix b) {
    if (a.rowCount != b.rowCount || a.colCount != b.colCount) {
      throw const FormatException('Las matrices A y B deben tener las mismas dimensiones.');
    }
    final result = a - b;
    final colSpec = List.filled(a.colCount, 'c').join();
    final exprRows = [
      for (int r = 0; r < a.rowCount; r++)
        [
          for (int c = 0; c < a.colCount; c++)
            MatrixHelpers.formatBinarySumCell(a.at(r, c), b.at(r, c), isSubtract: true),
        ].join(' & '),
    ].join(' \\\\\n');

    final step1Matrix = '\\left(\\begin{array}{$colSpec}\n$exprRows\n\\end{array}\\right)';

    return StepByStepResolution(
      originalInputLatex: '${a.toLatex()} - ${b.toLatex()}',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Restar elemento a elemento',
          latexExpression: 'A - B = $step1Matrix',
          pedagogicalNote:
              'Restamos cada coeficiente de B al correspondiente de A (cᵢⱼ = aᵢⱼ - bᵢⱼ).',
          warningTrick:
              'Si un coeficiente de B es negativo, restarlo equivale a sumarlo: a - (-b) = a + b.',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Matriz diferencia simplificada',
          latexExpression: 'A - B = ${result.toLatex()}',
          pedagogicalNote:
              'Calculamos el resultado final de cada posición en fracción irreducible.',
        ),
      ],
      exactResultLatex: result.toLatex(),
      decimalApproxLatex: result.toDecimalLatex(),
    );
  }

  /// Producto por un escalar `k · A` con visualización en la LCD en 3 pasos exactos.
  static StepByStepResolution scalarMultiply(Rational k, RationalMatrix a) {
    final result = a.scale(k);
    final colSpec = List.filled(a.colCount, 'c').join();
    final kLatex = k.toLatex();
    final multRows = [
      for (int r = 0; r < a.rowCount; r++)
        [
          for (int c = 0; c < a.colCount; c++)
            '$kLatex \\cdot ${MatrixHelpers.wrapNegative(a.at(r, c))}',
        ].join(' & '),
    ].join(' \\\\\n');

    return StepByStepResolution(
      originalInputLatex: '${MatrixHelpers.wrapNegative(k)} \\cdot ${a.toLatex()}',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Escalar k delante de la matriz A',
          latexExpression: '$kLatex \\cdot ${a.toLatex()}',
          pedagogicalNote:
              'Planteamos el producto del escalar k = $kLatex multiplicando delante de toda la matriz A.',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Multiplicar elemento por elemento',
          latexExpression:
              '\\left(\\begin{array}{$colSpec}\n$multRows\n\\end{array}\\right)',
          pedagogicalNote:
              'Multiplicamos el escalar $kLatex por cada uno de los elementos individuales dentro de la matriz.',
        ),
        MathStep(
          index: 3,
          shortTitle: 'Matriz resultado simplificada',
          latexExpression: result.toLatex(),
          pedagogicalNote:
              'Operamos cada celda y reducimos las fracciones resultantes a irreducibles.',
        ),
      ],
      exactResultLatex: result.toLatex(),
      decimalApproxLatex: result.toDecimalLatex(),
    );
  }

  /// Producto de matrices `A · B` con desglose de producto escalar fila por columna.
  static StepByStepResolution multiply(RationalMatrix a, RationalMatrix b) {
    if (a.colCount != b.rowCount) {
      throw const FormatException(
        'No se puede multiplicar A·B: las columnas de A deben coincidir con las filas de B.',
      );
    }
    final result = a * b;
    final colSpec = List.filled(b.colCount, 'c').join();

    final expandedRows = [
      for (int r = 0; r < a.rowCount; r++)
        [
          for (int c = 0; c < b.colCount; c++)
            List.generate(
              a.colCount,
              (k) => '${MatrixHelpers.wrapNegative(a.at(r, k))} \\cdot ${MatrixHelpers.wrapNegative(b.at(k, c))}',
            ).join(' + '),
        ].join(' & '),
    ].join(' \\\\\n');

    final partialSumRows = [
      for (int r = 0; r < a.rowCount; r++)
        [
          for (int c = 0; c < b.colCount; c++)
            MatrixHelpers.formatSignedSumTerms([
              for (int k = 0; k < a.colCount; k++) a.at(r, k) * b.at(k, c),
            ]),
        ].join(' & '),
    ].join(' \\\\\n');

    return StepByStepResolution(
      originalInputLatex: '${a.toLatex()} \\cdot ${b.toLatex()}',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Producto escalar: Fila de A por Columna de B',
          latexExpression:
              'c_{ij} = \\sum a_{ik} \\cdot b_{kj} \\implies A \\cdot B = \\left(\\begin{array}{$colSpec}\n$expandedRows\n\\end{array}\\right)',
          pedagogicalNote:
              'Cada elemento cᵢⱼ se obtiene realizando el producto escalar de la fila i de A por la columna j de B.',
          warningTrick:
              'El producto de matrices no es conmutativo: en general A·B ≠ B·A. Multiplica cada fila de la primera por cada columna de la segunda.',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Operar productos parciales',
          latexExpression:
              'A \\cdot B = \\left(\\begin{array}{$colSpec}\n$partialSumRows\n\\end{array}\\right)',
          pedagogicalNote:
              'Calculamos cada multiplicación parcial respetando los signos antes de sumar cada casilla.',
        ),
        MathStep(
          index: 3,
          shortTitle: 'Matriz producto simplificada',
          latexExpression: 'A \\cdot B = ${result.toLatex()}',
          pedagogicalNote:
              'Sumamos los términos de cada posición para obtener la matriz producto de dimensión ${result.rowCount}×${result.colCount}.',
        ),
      ],
      exactResultLatex: result.toLatex(),
      decimalApproxLatex: result.toDecimalLatex(),
    );
  }

  /// Traspuesta de una matriz A^t.
  static StepByStepResolution transpose(RationalMatrix a) {
    final t = a.transpose();
    return StepByStepResolution(
      originalInputLatex: 'A^t',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Definicion de matriz traspuesta',
          latexExpression: '(A^t)_{ij} = A_{ji} \\implies A^t = ${t.toLatex()}',
          pedagogicalNote:
              'La matriz traspuesta se obtiene intercambiando ordenadamente las filas por columnas: la fila 1 se convierte en la columna 1.',
        ),
      ],
      exactResultLatex: t.toLatex(),
      decimalApproxLatex: t.toDecimalLatex(),
    );
  }
}
