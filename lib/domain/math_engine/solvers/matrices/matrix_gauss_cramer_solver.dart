import '../../core/rational.dart';
import '../../models/matrix_models.dart';
import '../../models/step_resolution.dart';
import 'matrix_helpers.dart';

class MatrixGaussCramerSolver {
  /// Regla de Cramer para resolver el sistema matricial A · X = B.
  static StepByStepResolution cramer(RationalMatrix a, RationalMatrix b) {
    if (!a.isSquare || a.rowCount < 2 || a.rowCount > 4) {
      throw const FormatException('La Regla de Cramer requiere una matriz cuadrada de orden 2, 3 o 4.');
    }
    final bCol = <Rational>[];
    if (b.colCount == 1 && b.rowCount == a.rowCount) {
      for (int i = 0; i < a.rowCount; i++) {
        bCol.add(b.at(i, 0));
      }
    } else if (b.rowCount == 1 && b.colCount == a.rowCount) {
      for (int i = 0; i < a.rowCount; i++) {
        bCol.add(b.at(0, i));
      }
    } else {
      throw const FormatException('Las dimensiones de B deben coincidir con las filas de A.');
    }

    final detA = a.determinantValue();
    final detALatex = detA.toLatex();
    final varNames = const ['x', 'y', 'z', 'w'].sublist(0, a.rowCount);

    final steps = <MathStep>[];
    final originalLatex = '${a.toLatex()} \\cdot X = ${b.toLatex()}';

    final isZero = detA.isZero;
    final detNote = isZero
        ? 'El determinante de la matriz de coeficientes es cero (|A| = 0). No es aplicable la Regla de Cramer porque el sistema no es compatible determinado.'
        : 'Calculamos el determinante de la matriz de coeficientes |A|. Como |A| = $detALatex ≠ 0, el sistema es Compatible Determinado y admite solucion unica segun la Regla de Cramer.';

    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Determinante principal |A|',
        latexExpression: '\\left|A\\right| = $detALatex ${isZero ? "\\implies \\text{No aplicable Cramer}" : "\\neq 0 \\implies \\text{S.C.D.}"}',
        pedagogicalNote: detNote,
      ),
    );

    if (isZero) {
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: r'\text{No aplicable Cramer (}\left|A\right|=0\text{)}',
        decimalApproxLatex: '',
      );
    }

    final subDets = <Rational>[];
    final subLatexLines = <String>[];
    for (int i = 0; i < a.rowCount; i++) {
      final v = varNames[i];
      final matAi = a.replaceColumn(i, bCol);
      final detAi = matAi.determinantValue();
      subDets.add(detAi);
      subLatexLines.add('\\left|A_{$v}\\right| = ${detAi.toLatex()}');
    }

    steps.add(
      MathStep(
        index: 2,
        shortTitle: 'Determinantes de matrices sustituidas |A_i|',
        latexExpression: subLatexLines.join(', \\quad '),
        pedagogicalNote:
            'Para cada incognita, sustituimos su columna en A por el vector de terminos independientes B y calculamos su determinante.',
      ),
    );

    final solutions = <Rational>[];
    final solLatexLines = <String>[];
    for (int i = 0; i < a.rowCount; i++) {
      final v = varNames[i];
      final sol = subDets[i] / detA;
      solutions.add(sol);
      solLatexLines.add('$v = \\frac{\\left|A_{$v}\\right|}{\\left|A\\right|} = \\frac{${subDets[i].toLatex()}}{$detALatex} = ${sol.toLatex()}');
    }

    steps.add(
      MathStep(
        index: 3,
        shortTitle: 'Cocientes de Cramer y solucion',
        latexExpression: solLatexLines.join(', \\quad '),
        pedagogicalNote:
            'Dividimos el determinante de cada matriz sustituida entre |A| y simplificamos a fracciones irreducibles.',
      ),
    );

    final exactResult = [
      for (int i = 0; i < a.rowCount; i++) '${varNames[i]} = ${solutions[i].toLatex()}',
    ].join(', \\quad ');

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: exactResult,
      decimalApproxLatex: [
        for (int i = 0; i < a.rowCount; i++) '${varNames[i]} \\approx ${solutions[i].toDecimalLatex()}',
      ].join(', \\quad '),
    );
  }

  /// Eliminación Gaussiana y cálculo de rango / compatibilidad.
  static StepByStepResolution gauss(RationalMatrix a, [RationalMatrix? b]) {
    final bool isAugmented = b != null;
    final int m = a.rowCount;
    final int nA = a.colCount;
    final int nTotal = isAugmented ? nA + b.colCount : nA;

    final rows = <List<Rational>>[];
    for (int r = 0; r < m; r++) {
      final row = <Rational>[];
      for (int c = 0; c < nA; c++) {
        row.add(a.at(r, c));
      }
      if (isAugmented) {
        for (int c = 0; c < b.colCount; c++) {
          row.add(b.at(r, c));
        }
      }
      rows.add(row);
    }

    final steps = <MathStep>[];
    final originalLatex = isAugmented ? '\\left(A \\;\\middle|\\; B\\right)' : a.toLatex();

    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Matriz inicial para eliminacion gaussiana',
        latexExpression: MatrixHelpers.matrixRowsToLatex(rows),
        pedagogicalNote: isAugmented
            ? 'Construimos la matriz ampliada (A|B) con la matriz de coeficientes a la izquierda y los terminos independientes a la derecha.'
            : 'Partimos de la matriz original A para obtener una matriz escalonada equivalente mediante transformaciones por filas.',
      ),
    );

    int pivotRow = 0;
    int pivotCol = 0;
    final transformNotes = <String>[];

    while (pivotRow < m && pivotCol < nA) {
      int nonZeroRow = -1;
      for (int r = pivotRow; r < m; r++) {
        if (!rows[r][pivotCol].isZero) {
          nonZeroRow = r;
          break;
        }
      }

      if (nonZeroRow == -1) {
        pivotCol++;
        continue;
      }

      if (nonZeroRow != pivotRow) {
        final tmp = rows[pivotRow];
        rows[pivotRow] = rows[nonZeroRow];
        rows[nonZeroRow] = tmp;
        transformNotes.add('F_{${pivotRow + 1}} \\leftrightarrow F_{${nonZeroRow + 1}}');
      }

      final pivotVal = rows[pivotRow][pivotCol];

      for (int r = pivotRow + 1; r < m; r++) {
        final targetVal = rows[r][pivotCol];
        if (!targetVal.isZero) {
          final factor = targetVal / pivotVal;
          for (int c = pivotCol; c < nTotal; c++) {
            rows[r][c] = rows[r][c] - (factor * rows[pivotRow][c]);
          }
          final factorLatex = factor.toLatex();
          transformNotes.add(
            factor.isNegative
                ? 'F_{${r + 1}} \\leftarrow F_{${r + 1}} + (${factor.abs().toLatex()}) F_{${pivotRow + 1}}'
                : 'F_{${r + 1}} \\leftarrow F_{${r + 1}} - ($factorLatex) F_{${pivotRow + 1}}',
          );
        }
      }

      pivotRow++;
      pivotCol++;
    }

    if (transformNotes.isNotEmpty) {
      steps.add(
        MathStep(
          index: 2,
          shortTitle: 'Transformaciones elementales por filas',
          latexExpression: transformNotes.join(', \\quad '),
          pedagogicalNote:
              'Realizamos combinaciones lineales por filas para anular los coeficientes situados por debajo de la diagonal principal.',
        ),
      );
    }

    int rankA = 0;
    int rankAug = 0;
    for (int r = 0; r < m; r++) {
      bool nonZeroA = false;
      bool nonZeroTotal = false;
      for (int c = 0; c < nA; c++) {
        if (!rows[r][c].isZero) nonZeroA = true;
      }
      for (int c = 0; c < nTotal; c++) {
        if (!rows[r][c].isZero) nonZeroTotal = true;
      }
      if (nonZeroA) rankA++;
      if (nonZeroTotal) rankAug++;
    }

    final echelonLatex = MatrixHelpers.matrixRowsToLatex(rows);
    final classificationLatex = isAugmented
        ? '\\text{rg}(A) = $rankA, \\; \\text{rg}(A|B) = $rankAug \\implies ${rankA == rankAug ? (rankA == nA ? "\\text{S.C.D.}" : "\\text{S.C.I.}") : "\\text{S.I.}"}'
        : '\\text{rg}(A) = $rankA';

    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Matriz escalonada y rango',
        latexExpression: '$echelonLatex \\quad \\implies $classificationLatex',
        pedagogicalNote: isAugmented
            ? 'Segun el Teorema de Rouche-Frobenius: si rg(A) = rg(A|B) = n el sistema tiene solucion unica (S.C.D.); si rg(A) = rg(A|B) < n tiene infinitas soluciones (S.C.I.); y si rg(A) < rg(A|B) no tiene solucion (S.I.).'
            : 'El rango de la matriz es igual al numero de filas no completamente nulas de su forma escalonada: rg(A) = $rankA.',
      ),
    );

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: classificationLatex,
      decimalApproxLatex: '',
    );
  }
}
