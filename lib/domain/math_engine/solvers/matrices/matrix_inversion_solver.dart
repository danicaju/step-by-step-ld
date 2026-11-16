import '../../core/rational.dart';
import '../../models/matrix_models.dart';
import '../../models/step_resolution.dart';
import 'matrix_determinant_solver.dart';

class MatrixInversionSolver {
  /// Matriz Adjunta `Adj(A)` calculada mediante menores complementarios y tablero de signos.
  static StepByStepResolution adjoint(RationalMatrix a) {
    if (!a.isSquare || a.rowCount < 2 || a.rowCount > 4) {
      throw const FormatException('La matriz adjunta está disponible para 2x2, 3x3 o 4x4.');
    }
    final adj = a.cofactorMatrix();

    if (a.rowCount == 2) {
      return StepByStepResolution(
        originalInputLatex: '\\text{Adj}${a.toLatex()}',
        steps: [
          MathStep(
            index: 1,
            shortTitle: 'Tablero de signos y cofactores 2x2',
            latexExpression:
                '\\left(\\begin{array}{cc} + & - \\\\ - & + \\end{array}\\right) \\implies \\text{Adj}(A) = \\left(\\begin{array}{cc} +(${a.at(1, 1).toLatex()}) & -(${a.at(1, 0).toLatex()}) \\\\ -(${a.at(0, 1).toLatex()}) & +(${a.at(0, 0).toLatex()}) \\end{array}\\right)',
            pedagogicalNote:
                'Cada adjunto Aᵢⱼ es el elemento opuesto multiplicado por el tablero de signos (-1)^(i+j).',
            warningTrick:
                'Cambia el signo en las posiciones impares (1,2) y (2,1).',
          ),
          MathStep(
            index: 2,
            shortTitle: 'Matriz adjunta simplificada',
            latexExpression: '\\text{Adj}(A) = ${adj.toLatex()}',
            pedagogicalNote:
                'Aplicamos los cambios de signo para obtener la matriz Adj(A).',
          ),
        ],
        exactResultLatex: adj.toLatex(),
        decimalApproxLatex: adj.toDecimalLatex(),
      );
    }

    if (a.rowCount == 3) {
      final minorLines = <String>[];
      for (int r = 0; r < 3; r++) {
        final lineTerms = <String>[];
        for (int c = 0; c < 3; c++) {
          final subDet = a.minorSubmatrix(r, c).determinantValue();
          final isOdd = (r + c) % 2 == 1;
          final signStr = isOdd ? '-' : '+';
          lineTerms.add(
            'A_{${r + 1}${c + 1}} = $signStr(${subDet.toLatex()}) = ${adj.at(r, c).toLatex()}',
          );
        }
        minorLines.add(lineTerms.join(', \\; '));
      }

      return StepByStepResolution(
        originalInputLatex: '\\text{Adj}${a.toLatex()}',
        steps: [
          MathStep(
            index: 1,
            shortTitle: 'Menores complementarios y tablero de signos',
            latexExpression:
                '\\left(\\begin{array}{ccc} + & - & + \\\\ - & + & - \\\\ + & - & + \\end{array}\\right) \\implies \\begin{aligned} ${minorLines.join(' \\\\ ')} \\end{aligned}',
            pedagogicalNote:
                'Calculamos los 9 menores Mᵢⱼ (eliminando la fila i y columna j) y aplicamos el tablero de signos (-1)^(i+j).',
            warningTrick:
                'Cambia siempre el signo en las 4 posiciones impares en forma de rombo: (1,2), (2,1), (2,3) y (3,2).',
          ),
          MathStep(
            index: 2,
            shortTitle: 'Matriz de Adjuntos Adj(A)',
            latexExpression: '\\text{Adj}(A) = ${adj.toLatex()}',
            pedagogicalNote:
                'Colocamos cada cofactor Aᵢⱼ en su fila i y columna j correspondiente.',
          ),
        ],
        exactResultLatex: adj.toLatex(),
        decimalApproxLatex: adj.toDecimalLatex(),
      );
    }

    // 4x4
    final minorLines = <String>[];
    for (int r = 0; r < 4; r++) {
      final lineTerms = <String>[];
      for (int c = 0; c < 4; c++) {
        final subDet = a.minorSubmatrix(r, c).determinantValue();
        final isOdd = (r + c) % 2 == 1;
        final signStr = isOdd ? '-' : '+';
        lineTerms.add(
          'A_{${r + 1}${c + 1}} = $signStr(${subDet.toLatex()}) = ${adj.at(r, c).toLatex()}',
        );
      }
      minorLines.add(lineTerms.join(', \\; '));
    }

    return StepByStepResolution(
      originalInputLatex: '\\text{Adj}${a.toLatex()}',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Menores complementarios 3x3 y tablero de signos 4x4',
          latexExpression:
              '\\begin{aligned} ${minorLines.take(2).join(" \\\\ ")} \\\\ \\dots \\end{aligned}',
          pedagogicalNote:
              'Calculamos los 16 menores Mᵢⱼ de orden 3 y aplicamos el tablero de signos alternos (-1)^(i+j).',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Matriz de Adjuntos Adj(A)',
          latexExpression: '\\text{Adj}(A) = ${adj.toLatex()}',
          pedagogicalNote:
              'Construimos la matriz de adjuntos completa de dimension 4x4.',
        ),
      ],
      exactResultLatex: adj.toLatex(),
      decimalApproxLatex: adj.toDecimalLatex(),
    );
  }

  /// Matriz Inversa `A⁻¹ = (1/|A|) · (Adj(A))^t` paso a paso estilo PAU/EBAU.
  static StepByStepResolution inverse(RationalMatrix a) {
    if (!a.isSquare || a.rowCount < 2 || a.rowCount > 4) {
      throw const FormatException('La inversa está disponible para matrices 2x2, 3x3 o 4x4.');
    }

    final detRes = MatrixDeterminantSolver.determinant(a);
    final det = a.determinantValue();

    // Paso 1: Comprobar determinante
    if (det.isZero) {
      final step1Expr = a.rowCount >= 3
          ? detRes.steps[2].latexExpression
          : '\\left|A\\right| = 0 \\implies \\nexists A^{-1}';
      return StepByStepResolution(
        originalInputLatex: '${a.toLatex()}^{-1}',
        steps: [
          MathStep(
            index: 1,
            shortTitle: 'Calcular |A|: determinante nulo (sin inversa)',
            latexExpression: step1Expr,
            pedagogicalNote:
                'El primer paso de la fórmula A⁻¹ = (1/|A|)·(Adj(A))ᵗ es calcular |A|. Como |A| = 0, no se puede dividir por cero: la matriz es singular y NO existe su inversa.',
            warningTrick:
                'Si |A| = 0, la matriz no es invertible por tener determinante nulo (no es posible dividir por 0).',
          ),
        ],
        exactResultLatex: r'\nexists A^{-1} \; (\left|A\right| = 0)',
        decimalApproxLatex: '',
      );
    }

    final detSummary = a.rowCount >= 3
        ? detRes.steps[2].latexExpression
        : '\\left|A\\right| = ${det.toLatex()} \\neq 0 \\implies \\exists A^{-1}';

    // Paso 2: Adj(A)
    final adjRes = adjoint(a);
    final adj = a.cofactorMatrix();

    // Paso 3: Traspuesta de la Adjunta (Adj(A))^t
    final adjT = adj.transpose();

    // Paso 4: Multiplicar por 1 / |A|
    final invDet = Rational(1) / det;
    final invMatrix = adjT.scale(invDet);

    return StepByStepResolution(
      originalInputLatex: '${a.toLatex()}^{-1}',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Paso 1: Calcular el determinante |A|',
          latexExpression: detSummary,
          pedagogicalNote:
              'Comprobamos si |A| ≠ 0. Como |A| = ${det.toLatex()}, la matriz es invertible y podemos aplicar A⁻¹ = (1/|A|) · (Adj(A))ᵗ.',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Paso 2: Matriz de Adjuntos Adj(A)',
          latexExpression: adjRes.steps.first.latexExpression,
          pedagogicalNote:
              'Calculamos los cofactores con el tablero de signos alternos hasta formar Adj(A) = ${adj.toLatex()}.',
        ),
        MathStep(
          index: 3,
          shortTitle: 'Paso 3: Traspuesta de la Adjunta (Adj(A))ᵗ',
          latexExpression:
              '\\left(\\text{Adj}(A)\\right)^t = \\left(${adj.toLatex()}\\right)^t = ${adjT.toLatex()}',
          pedagogicalNote:
              'Intercambiamos las filas por las columnas de Adj(A) (la fila 1 pasa a ser la columna 1, etc.).',
        ),
        MathStep(
          index: 4,
          shortTitle: 'Paso 4: Dividir entre |A| = ${det.toLatex()} y simplificar',
          latexExpression:
              'A^{-1} = ${invDet.toLatex()} \\cdot ${adjT.toLatex()} = ${invMatrix.toLatex()}',
          pedagogicalNote:
              'Dividimos cada elemento de (Adj(A))ᵗ entre |A| = ${det.toLatex()} y simplificamos todas las fracciones a irreducibles.',
        ),
      ],
      exactResultLatex: invMatrix.toLatex(),
      decimalApproxLatex: invMatrix.toDecimalLatex(),
    );
  }
}
