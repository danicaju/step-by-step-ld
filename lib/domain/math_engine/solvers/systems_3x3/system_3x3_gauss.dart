import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../../models/system_3x3_models.dart';
import 'system_3x3_formatter.dart';

class System3x3GaussSolver {
  static System3x3Result solveByGauss(
    List<List<Rational>> inputRows,
    String originalInputLatex,
  ) {
    final m = [
      for (final r in inputRows) [for (final v in r) v],
    ];
    final List<MathStep> steps = [];

    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Matriz ampliada inicial (A | B)',
        latexExpression: '\\left(A \\mid B\\right) = ${System3x3Formatter.augmentedLatex(m)}',
        pedagogicalNote:
            'Escribimos el sistema 3x3 en forma de matriz ampliada (A | B) con los coeficientes de x, y, z a la izquierda y los términos independientes a la derecha.',
      ),
    );

    // Eliminación gaussiana por columnas pivote (garantiza forma escalonada exacta)
    final echelonSteps = reduceToEchelonWithDescriptions(m);
    const colVars = ['x', 'y', 'z'];
    for (final stepInfo in echelonSteps) {
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle:
              'Triangulación de Gauss: ceros en columna ${stepInfo.col + 1} (${colVars[stepInfo.col]})',
          latexExpression: '${stepInfo.ops.join(', \\; ')} \\implies ${stepInfo.matrixLatex}',
          pedagogicalNote:
              'Aplicamos combinaciones lineales elementales entre filas (manteniendo enteros siempre que es posible) para conseguir ceros debajo del pivote en ${colVars[stepInfo.col]}.',
        ),
      );
    }

    // Cálculo exacto de rangos rg(A) y rg(A*) sobre la matriz escalonada
    final (:rankA, :rankAb) = computeRanksFromEchelon(m);

    // S.I.: Sistema Incompatible (rg(A) < rg(A*))
    if (rankA < rankAb) {
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Teorema de Rouché-Frobenius: Sistema Incompatible',
          latexExpression:
              '\\text{rg}(A) = $rankA \\neq \\text{rg}(A^*) = $rankAb \\implies \\text{S.I.}',
          pedagogicalNote:
              'En la matriz escalonada aparece una ecuación imposible del tipo 0 = k (con k ≠ 0). Como rg(A) ≠ rg(A*), el sistema NO tiene solución.',
          warningTrick:
              'Por el teorema de Rouché-Frobenius, una fila [0 0 0 | k] con k ≠ 0 implica rg(A) < rg(A*) y sistema incompatible (S.I.).',
        ),
      );
      return System3x3Result(
        classification: System3x3Classification.si,
        rankA: rankA,
        rankAugmented: rankAb,
        x: null,
        y: null,
        z: null,
        resolution: StepByStepResolution(
          originalInputLatex: originalInputLatex,
          steps: steps,
          exactResultLatex: r'\text{Sin solucion (S.I.)}',
          decimalApproxLatex: r'\text{Sin sol}',
        ),
      );
    }

    // S.C.I.: Sistema Compatible Indeterminado (rg(A) == rg(A*) < 3)
    if (rankA < 3) {
      final freeParams = 3 - rankA;
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Teorema de Rouché-Frobenius: Sistema Compatible Indeterminado',
          latexExpression:
              '\\text{rg}(A) = \\text{rg}(A^*) = $rankA < 3 \\implies \\text{S.C.I.}',
          pedagogicalNote:
              'Al triangular aparece al menos una fila nula [0 0 0 | 0]. Los rangos coinciden pero son menores que el número de incógnitas (3), por lo que hay infinitas soluciones con $freeParams parámetro${freeParams > 1 ? 's libres' : ' libre (λ)'}.',
          warningTrick:
              'Una fila nula [0 0 0 | 0] indica una ecuación redundante y un Sistema Compatible Indeterminado (S.C.I.), no ausencia de solución.',
        ),
      );
      return System3x3Result(
        classification: System3x3Classification.sci,
        rankA: rankA,
        rankAugmented: rankAb,
        x: null,
        y: null,
        z: null,
        resolution: StepByStepResolution(
          originalInputLatex: originalInputLatex,
          steps: steps,
          exactResultLatex: r'\text{Infinitas soluciones (S.C.I.)}',
          decimalApproxLatex: r'\text{Infinitas}',
        ),
      );
    }

    // S.C.D.: Sistema Compatible Determinado (rg(A) = rg(A*) = 3)
    // Sustitución regresiva hacia arriba: z -> y -> x
    final z = m[2][3] / m[2][2];
    final yRhs = m[1][3] - m[1][2] * z;
    final y = yRhs / m[1][1];
    final xRhs = m[0][3] - m[0][1] * y - m[0][2] * z;
    final x = xRhs / m[0][0];

    final zEq = System3x3Formatter.formatZEquation(m[2][2], m[2][3]);
    final yEq = System3x3Formatter.formatYBackSub(m[1][1], m[1][2], z, m[1][3]);
    final xEq = System3x3Formatter.formatXBackSub(m[0][0], m[0][1], m[0][2], y, z, m[0][3]);

    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Rouché-Frobenius (S.C.D.) y sustitución regresiva',
        latexExpression:
            '\\text{rg}(A) = \\text{rg}(A^*) = 3 \\implies \\text{S.C.D.} \\quad \\begin{aligned} '
            '$zEq &\\implies z = ${z.toLatex()} \\\\ '
            '$yEq &\\implies y = ${y.toLatex()} \\\\ '
            '$xEq &\\implies x = ${x.toLatex()} '
            '\\end{aligned}',
        pedagogicalNote:
            'Por el Teorema de Rouché-Frobenius, rg(A) = rg(A*) = 3 = n.º incógnitas (Sistema Compatible Determinado). Despejamos de abajo hacia arriba: z → y → x.',
      ),
    );

    final exactLatex = 'x = ${x.toLatex()}, \\; y = ${y.toLatex()}, \\; z = ${z.toLatex()}';
    final decimalLatex = (x.isInteger && y.isInteger && z.isInteger)
        ? ''
        : 'x \\approx ${x.toDecimalLatex()}, \\; y \\approx ${y.toDecimalLatex()}, \\; z \\approx ${z.toDecimalLatex()}';

    return System3x3Result(
      classification: System3x3Classification.scd,
      rankA: rankA,
      rankAugmented: rankAb,
      x: x,
      y: y,
      z: z,
      resolution: StepByStepResolution(
        originalInputLatex: originalInputLatex,
        steps: steps,
        exactResultLatex: exactLatex,
        decimalApproxLatex: decimalLatex,
      ),
    );
  }

  static int findPivotRow(
    List<List<Rational>> m, {
    required int startRow,
    required int col,
  }) {
    for (int r = startRow; r < m.length; r++) {
      if (!m[r][col].isZero) return r;
    }
    return -1;
  }

  static void swapRows(List<List<Rational>> m, int r1, int r2) {
    final temp = m[r1];
    m[r1] = m[r2];
    m[r2] = temp;
  }

  static String eliminateRow(
    List<List<Rational>> m, {
    required int pivotRow,
    required int targetRow,
    required int col,
  }) {
    final p = m[pivotRow][col];
    final q = m[targetRow][col];

    if (p.isInteger && q.isInteger) {
      final g = Rational.gcd(p.numerator, q.numerator);
      int alpha = p.numerator ~/ g;
      int beta = q.numerator ~/ g;
      if (alpha < 0) {
        alpha = -alpha;
        beta = -beta;
      }

      for (int c = 0; c < 4; c++) {
        m[targetRow][c] = m[targetRow][c] * Rational(alpha) - m[pivotRow][c] * Rational(beta);
      }

      final fTarget = 'F_${targetRow + 1}';
      final fPivot = 'F_${pivotRow + 1}';
      final leftPart = alpha == 1 ? fTarget : '$alpha $fTarget';
      final betaAbs = beta.abs();
      final pivotTerm = betaAbs == 1 ? fPivot : '$betaAbs $fPivot';
      final opSign = beta >= 0 ? '-' : '+';
      return '$fTarget \\leftarrow $leftPart $opSign $pivotTerm';
    }

    // Caso general con coeficientes fraccionarios
    final factor = q / p;
    for (int c = 0; c < 4; c++) {
      m[targetRow][c] = m[targetRow][c] - m[pivotRow][c] * factor;
    }
    final fTarget = 'F_${targetRow + 1}';
    final fPivot = 'F_${pivotRow + 1}';
    final absFactor = factor.abs();
    final factorLatex = absFactor == Rational(1) ? fPivot : '${absFactor.toLatex()} $fPivot';
    final opSign = factor.isNegative ? '+' : '-';
    return '$fTarget \\leftarrow $fTarget $opSign $factorLatex';
  }

  static List<({int col, List<String> ops, String matrixLatex})>
      reduceToEchelonWithDescriptions(List<List<Rational>> m) {
    final recorded = <({int col, List<String> ops, String matrixLatex})>[];
    int pivotRow = 0;
    for (int col = 0; col < 3 && pivotRow < 3; col++) {
      final found = findPivotRow(m, startRow: pivotRow, col: col);
      if (found == -1) continue;

      final ops = <String>[];
      if (found != pivotRow) {
        swapRows(m, pivotRow, found);
        ops.add('F_${pivotRow + 1} \\leftrightarrow F_${found + 1}');
      }
      for (int r = pivotRow + 1; r < 3; r++) {
        if (!m[r][col].isZero) {
          ops.add(eliminateRow(m, pivotRow: pivotRow, targetRow: r, col: col));
        }
      }
      if (ops.isNotEmpty) {
        recorded.add((col: col, ops: ops, matrixLatex: System3x3Formatter.augmentedLatex(m)));
      }
      pivotRow++;
    }
    return recorded;
  }

  static void reduceToEchelonSilent(List<List<Rational>> m) {
    reduceToEchelonWithDescriptions(m);
  }

  static ({int rankA, int rankAb}) computeRanksFromEchelon(
    List<List<Rational>> echelon,
  ) {
    int rankA = 0;
    int rankAb = 0;
    for (int r = 0; r < 3; r++) {
      final hasLeft = !echelon[r][0].isZero ||
          !echelon[r][1].isZero ||
          !echelon[r][2].isZero;
      final hasAny = hasLeft || !echelon[r][3].isZero;
      if (hasLeft) rankA++;
      if (hasAny) rankAb++;
    }
    return (rankA: rankA, rankAb: rankAb);
  }
}
