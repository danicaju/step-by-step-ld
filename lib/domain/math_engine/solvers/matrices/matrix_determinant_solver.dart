import '../../core/rational.dart';
import '../../models/matrix_models.dart';
import '../../models/step_resolution.dart';
import 'matrix_helpers.dart';

class MatrixDeterminantSolver {
  /// Determinante `|A|` (2x2 directo, 3x3 por Regla de Sarrus o 4x4 por Laplace).
  static StepByStepResolution determinant(RationalMatrix a) {
    if (!a.isSquare || a.rowCount < 2 || a.rowCount > 4) {
      throw const FormatException('El determinante guiado admite matrices 2x2, 3x3 o 4x4.');
    }

    final det = a.determinantValue();
    final detLatex = det.toLatex();
    final invertibleTag = det.isZero
        ? '\\left|A\\right| = 0 \\implies \\text{Singular, } \\nexists A^{-1}'
        : '\\left|A\\right| = $detLatex \\neq 0 \\implies \\text{Invertible, rg}(A) = ${a.rowCount}';

    if (a.rowCount == 2) {
      final p1 = a.at(0, 0) * a.at(1, 1);
      final p2 = a.at(0, 1) * a.at(1, 0);
      final step1Expr =
          '\\left|A\\right| = ${MatrixHelpers.wrapNegative(a.at(0, 0))} \\cdot ${MatrixHelpers.wrapNegative(a.at(1, 1))} - ${MatrixHelpers.wrapNegative(a.at(0, 1))} \\cdot ${MatrixHelpers.wrapNegative(a.at(1, 0))} = ${p1.toLatex()} ${MatrixHelpers.formatSignedOperand(-p2)}';

      return StepByStepResolution(
        originalInputLatex: a.toDeterminantLatex(),
        steps: [
          MathStep(
            index: 1,
            shortTitle: 'Diagonal principal menos diagonal secundaria',
            latexExpression: step1Expr,
            pedagogicalNote:
                'Multiplicamos los elementos de la diagonal principal (a₁₁·a₂₂) y restamos el producto de la diagonal secundaria (a₁₂·a₂₁).',
            warningTrick: p2.isNegative
                ? 'Al restar el producto negativo (${p2.toLatex()}) pasa a sumarse: -(${p2.toLatex()}) = +${p2.abs().toLatex()}.'
                : null,
          ),
          MathStep(
            index: 2,
            shortTitle: 'Determinante e invertibilidad',
            latexExpression: invertibleTag,
            pedagogicalNote: det.isZero
                ? 'Como |A| = 0, las dos filas son linealmente dependientes: el rango es menor que 2 y la matriz no tiene inversa.'
                : 'Como |A| ≠ 0, la matriz tiene rango máximo (rg(A) = 2) y admite matriz inversa A⁻¹.',
          ),
        ],
        exactResultLatex: '\\left|A\\right| = $detLatex',
        decimalApproxLatex: det.denominator == 1 ? '' : '\\left|A\\right| \\approx ${det.toDecimalLatex()}',
      );
    }

    if (a.rowCount == 3) {
      final pos1 = a.at(0, 0) * a.at(1, 1) * a.at(2, 2);
      final pos2 = a.at(0, 1) * a.at(1, 2) * a.at(2, 0);
      final pos3 = a.at(0, 2) * a.at(1, 0) * a.at(2, 1);
      final posSum = pos1 + pos2 + pos3;

      final neg1 = a.at(0, 2) * a.at(1, 1) * a.at(2, 0);
      final neg2 = a.at(0, 0) * a.at(1, 2) * a.at(2, 1);
      final neg3 = a.at(0, 1) * a.at(1, 0) * a.at(2, 2);
      final negSum = neg1 + neg2 + neg3;

      final posProductsExpr =
          '${MatrixHelpers.tripleProduct(a.at(0, 0), a.at(1, 1), a.at(2, 2))} + '
          '${MatrixHelpers.tripleProduct(a.at(0, 1), a.at(1, 2), a.at(2, 0))} + '
          '${MatrixHelpers.tripleProduct(a.at(0, 2), a.at(1, 0), a.at(2, 1))}';

      final negProductsExpr =
          '${MatrixHelpers.tripleProduct(a.at(0, 2), a.at(1, 1), a.at(2, 0))} + '
          '${MatrixHelpers.tripleProduct(a.at(0, 0), a.at(1, 2), a.at(2, 1))} + '
          '${MatrixHelpers.tripleProduct(a.at(0, 1), a.at(1, 0), a.at(2, 2))}';

      final step1Latex =
          'S_+ = \\left($posProductsExpr\\right) = ${MatrixHelpers.formatSignedSumTerms([pos1, pos2, pos3])} = ${posSum.toLatex()}';

      final negBlockVal = -negSum;
      final step2Latex =
          '-S_- = -\\left($negProductsExpr\\right) = -\\left(${MatrixHelpers.formatSignedSumTerms([neg1, neg2, neg3])}\\right) = -\\left(${negSum.toLatex()}\\right) = ${negBlockVal.toLatex()}';

      final step3Latex =
          '\\left|A\\right| = ${posSum.toLatex()} ${MatrixHelpers.formatSignedOperand(-negSum)} = $detLatex \\implies ${det.isZero ? r'\text{Singular (}\nexists A^{-1}\text{)}' : r'\text{Invertible, rg}(A)=3'}';

      return StepByStepResolution(
        originalInputLatex: a.toDeterminantLatex(),
        steps: [
          MathStep(
            index: 1,
            shortTitle: 'Regla de Sarrus: 3 diagonales positivas',
            latexExpression: step1Latex,
            pedagogicalNote:
                'Sumamos el producto de la diagonal principal y sus dos triángulos paralelos con sentido positivo: (a₁₁·a₂₂·a₃₃ + a₁₂·a₂₃·a₃₁ + a₁₃·a₂₁·a₃₂).',
          ),
          MathStep(
            index: 2,
            shortTitle: 'Regla de Sarrus: 3 diagonales negativas',
            latexExpression: step2Latex,
            pedagogicalNote:
                'Calculamos los tres productos de las diagonales secundarias y cambiamos el signo del bloque completo precedido de menos.',
            warningTrick:
                'Todo el paréntesis de las diagonales secundarias lleva signo menos delante: cambia el signo de la suma interior.',
          ),
          MathStep(
            index: 3,
            shortTitle: 'Suma final y clasificación (rango / inversa)',
            latexExpression: step3Latex,
            pedagogicalNote: det.isZero
                ? 'Sumamos ambos bloques: |A| = 0. La matriz es singular, su rango es menor que 3 y NO existe inversa A⁻¹.'
                : 'Sumamos ambos bloques: |A| = $detLatex ≠ 0. La matriz es regular/invertible y tiene rango máximo 3.',
          ),
        ],
        exactResultLatex: '\\left|A\\right| = $detLatex',
        decimalApproxLatex: det.denominator == 1 ? '' : '\\left|A\\right| \\approx ${det.toDecimalLatex()}',
      );
    }

    // 4x4 -> Desarrollo de Laplace por la primera fila
    final subDets = <Rational>[];
    final laplaceTerms = <String>[];
    for (int c = 0; c < 4; c++) {
      final coeff = a.at(0, c);
      final minor = a.minorSubmatrix(0, c);
      final minorDet = minor.determinantValue();
      subDets.add(minorDet);
      final sign = (c % 2 == 0) ? '+' : '-';
      laplaceTerms.add('$sign ${MatrixHelpers.wrapNegative(coeff)} \\cdot |M_{1${c + 1}}|');
    }

    final step1Latex = '\\left|A\\right| = ${laplaceTerms.join(" ")}';
    final step2Latex = [
      for (int c = 0; c < 4; c++)
        '|M_{1${c + 1}}| = ${subDets[c].toLatex()}',
    ].join(', \\quad ');

    final step3Latex =
        '\\left|A\\right| = $detLatex \\implies ${det.isZero ? r'\text{Singular (}\nexists A^{-1}\text{)}' : r'\text{Invertible, rg}(A)=4'}';

    return StepByStepResolution(
      originalInputLatex: a.toDeterminantLatex(),
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Desarrollo de Laplace por la fila 1',
          latexExpression: step1Latex,
          pedagogicalNote:
              'Desarrollamos el determinante 4x4 mediante el teorema de Laplace a lo largo de la primera fila, alternando los signos (+ - + -).',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Determinantes de los menores complementarios 3x3',
          latexExpression: step2Latex,
          pedagogicalNote:
              'Calculamos cada uno de los cuatro menores complementarios de orden 3 aplicando la Regla de Sarrus.',
        ),
        MathStep(
          index: 3,
          shortTitle: 'Combinación final y clasificación',
          latexExpression: step3Latex,
          pedagogicalNote: det.isZero
              ? 'La suma ponderada da |A| = 0. La matriz es singular, su rango es menor que 4 y no admite inversa.'
              : 'La suma ponderada da |A| = $detLatex ≠ 0. La matriz es regular, su rango es 4 y admite inversa.',
        ),
      ],
      exactResultLatex: '\\left|A\\right| = $detLatex',
      decimalApproxLatex: det.denominator == 1 ? '' : '\\left|A\\right| \\approx ${det.toDecimalLatex()}',
    );
  }
}
