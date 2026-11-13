import '../core/rational.dart';
import '../models/step_resolution.dart';
import 'matrix_solver.dart';

/// Métodos de resolución disponibles en el Modo 11 (Sistemas 3x3).
enum System3x3Method {
  gauss('Gauss'),
  cramer('Cramer');

  final String displayName;
  const System3x3Method(this.displayName);
}

/// Clasificación del sistema lineal según el Teorema de Rouché-Frobenius.
enum System3x3Classification {
  scd, // Sistema Compatible Determinado (solución única)
  sci, // Sistema Compatible Indeterminado (infinitas soluciones)
  si,  // Sistema Incompatible (sin solución)
}

/// Resultado estructurado del análisis de un sistema 3x3.
class System3x3Result {
  final System3x3Classification classification;
  final int rankA;
  final int rankAugmented;
  final Rational? x;
  final Rational? y;
  final Rational? z;
  final StepByStepResolution resolution;

  const System3x3Result({
    required this.classification,
    required this.rankA,
    required this.rankAugmented,
    required this.x,
    required this.y,
    required this.z,
    required this.resolution,
  });
}

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
        _formatEquationLatex(row[0], row[1], row[2], row[3]),
    ];
    final originalInputLatex = '\\begin{cases} ${eqLines.join(' \\\\ ')} \\end{cases}';

    if (method == System3x3Method.cramer) {
      return _solveByCramer(augmentedRows, originalInputLatex);
    }
    return _solveByGauss(augmentedRows, originalInputLatex);
  }

  // ---------------------------------------------------------------------------
  // MÉTODO A: ELIMINACIÓN GAUSSIANA Y ROUCHÉ-FROBENIUS
  // ---------------------------------------------------------------------------
  static System3x3Result _solveByGauss(
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
        latexExpression: '\\left(A \\mid B\\right) = ${_augmentedLatex(m)}',
        pedagogicalNote:
            'Escribimos el sistema 3x3 en forma de matriz ampliada (A | B) con los coeficientes de x, y, z a la izquierda y los términos independientes a la derecha.',
      ),
    );

    // Eliminación gaussiana por columnas pivote (garantiza forma escalonada exacta)
    final echelonSteps = _reduceToEchelonWithDescriptions(m);
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
    final (:rankA, :rankAb) = _computeRanksFromEchelon(m);

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

    final zEq = _formatZEquation(m[2][2], m[2][3]);
    final yEq = _formatYBackSub(m[1][1], m[1][2], z, m[1][3]);
    final xEq = _formatXBackSub(m[0][0], m[0][1], m[0][2], y, z, m[0][3]);

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

  // ---------------------------------------------------------------------------
  // MÉTODO B: REGLA DE CRAMER
  // ---------------------------------------------------------------------------
  static System3x3Result _solveByCramer(
    List<List<Rational>> rows,
    String originalInputLatex,
  ) {
    final matA = RationalMatrix.fromRationals([
      [rows[0][0], rows[0][1], rows[0][2]],
      [rows[1][0], rows[1][1], rows[1][2]],
      [rows[2][0], rows[2][1], rows[2][2]],
    ]);
    final det = matA.determinantValue();

    final List<MathStep> steps = [];
    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Determinante del sistema (Δ = |A|)',
        latexExpression: '\\Delta = ${matA.toDeterminantLatex()} = ${det.toLatex()}',
        pedagogicalNote:
            'Calculamos el determinante de la matriz de coeficientes A por la Regla de Sarrus. Si Δ ≠ 0, podemos aplicar Cramer para hallar solución única.',
      ),
    );

    if (det.isZero) {
      // Clasificamos internamente mediante rangos de Gauss para no confundir SCI y SI
      final echelonCopy = [for (final r in rows) [for (final v in r) v]];
      _reduceToEchelonSilent(echelonCopy);
      final (:rankA, :rankAb) = _computeRanksFromEchelon(echelonCopy);
      final isSi = rankA < rankAb;

      final matX = _replaceCol(matA, 0, [rows[0][3], rows[1][3], rows[2][3]]);
      final matY = _replaceCol(matA, 1, [rows[0][3], rows[1][3], rows[2][3]]);
      final matZ = _replaceCol(matA, 2, [rows[0][3], rows[1][3], rows[2][3]]);
      final dx = matX.determinantValue();
      final dy = matY.determinantValue();
      final dz = matZ.determinantValue();

      steps.add(
        MathStep(
          index: 2,
          shortTitle: isSi
              ? 'Δ = 0 → Cramer no aplicable (Sistema Incompatible)'
              : 'Δ = 0 → Cramer no aplicable (Sistema Compatible Indeterminado)',
          latexExpression:
              '\\Delta = 0, \\; \\Delta_x = ${dx.toLatex()}, \\; \\Delta_y = ${dy.toLatex()}, \\; \\Delta_z = ${dz.toLatex()} \\implies '
              '\\text{rg}(A) = $rankA${isSi ? ' < ' : ' = '}\\text{rg}(A^*) = $rankAb \\implies ${isSi ? r'\text{S.I.}' : r'\text{S.C.I.}'}',
          pedagogicalNote: isSi
              ? 'Al ser Δ = 0 la Regla de Cramer no se puede aplicar (no se puede dividir por cero). Al comprobar rangos por Rouché-Frobenius resulta rg(A) < rg(A*): Sistema Incompatible (sin solución).'
              : 'Al ser Δ = 0 no existe solución única. Mediante rangos por Rouché-Frobenius se comprueba rg(A) = rg(A*) = $rankA < 3: Sistema Compatible Indeterminado (infinitas soluciones).',
          warningTrick:
              'Que Δ = Δx = Δy = Δz = 0 no garantiza por sí solo que el sistema sea S.C.I. (podrían ser planos paralelos o secantes 2 a 2). Comprueba siempre rg(A) y rg(A*) mediante Gauss.',
        ),
      );

      return System3x3Result(
        classification:
            isSi ? System3x3Classification.si : System3x3Classification.sci,
        rankA: rankA,
        rankAugmented: rankAb,
        x: null,
        y: null,
        z: null,
        resolution: StepByStepResolution(
          originalInputLatex: originalInputLatex,
          steps: steps,
          exactResultLatex: isSi
              ? r'\text{Sin solucion (S.I.)}'
              : r'\text{Infinitas soluciones (S.C.I.)}',
          decimalApproxLatex: isSi ? r'\text{Sin sol}' : r'\text{Infinitas}',
        ),
      );
    }

    final rhs = [rows[0][3], rows[1][3], rows[2][3]];
    final matX = _replaceCol(matA, 0, rhs);
    final matY = _replaceCol(matA, 1, rhs);
    final matZ = _replaceCol(matA, 2, rhs);

    final dx = matX.determinantValue();
    final dy = matY.determinantValue();
    final dz = matZ.determinantValue();

    final x = dx / det;
    final y = dy / det;
    final z = dz / det;

    steps.add(
      MathStep(
        index: 2,
        shortTitle: 'Cálculo de Δx y valor de x',
        latexExpression:
            '\\Delta_x = ${matX.toDeterminantLatex()} = ${dx.toLatex()} \\implies '
            'x = \\frac{\\Delta_x}{\\Delta} = ${_fractionLatex(dx, det, x)}',
        pedagogicalNote:
            'Sustituimos la 1.ª columna de A (coeficientes de x) por la columna de términos independientes B y dividimos Δx entre Δ = ${det.toLatex()}.',
      ),
    );

    steps.add(
      MathStep(
        index: 3,
        shortTitle: 'Cálculo de Δy y valor de y',
        latexExpression:
            '\\Delta_y = ${matY.toDeterminantLatex()} = ${dy.toLatex()} \\implies '
            'y = \\frac{\\Delta_y}{\\Delta} = ${_fractionLatex(dy, det, y)}',
        pedagogicalNote:
            'Sustituimos la 2.ª columna de A (coeficientes de y) por la columna B y dividimos Δy entre Δ = ${det.toLatex()}.',
      ),
    );

    steps.add(
      MathStep(
        index: 4,
        shortTitle: 'Cálculo de Δz y solución final (x, y, z)',
        latexExpression:
            '\\Delta_z = ${matZ.toDeterminantLatex()} = ${dz.toLatex()} \\implies '
            'z = \\frac{\\Delta_z}{\\Delta} = ${_fractionLatex(dz, det, z)}',
        pedagogicalNote:
            'Sustituimos la 3.ª columna de A (coeficientes de z) por la columna B y dividimos Δz entre Δ = ${det.toLatex()}.',
      ),
    );

    final exactLatex = 'x = ${x.toLatex()}, \\; y = ${y.toLatex()}, \\; z = ${z.toLatex()}';
    final decimalLatex = (x.isInteger && y.isInteger && z.isInteger)
        ? ''
        : 'x \\approx ${x.toDecimalLatex()}, \\; y \\approx ${y.toDecimalLatex()}, \\; z \\approx ${z.toDecimalLatex()}';

    return System3x3Result(
      classification: System3x3Classification.scd,
      rankA: 3,
      rankAugmented: 3,
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

  // ---------------------------------------------------------------------------
  // HELPERS ALGEBRAICOS Y DE MATRICES
  // ---------------------------------------------------------------------------
  static RationalMatrix _replaceCol(
    RationalMatrix mat,
    int colIndex,
    List<Rational> colValues,
  ) {
    return RationalMatrix.fromRationals([
      for (int r = 0; r < 3; r++)
        [
          for (int c = 0; c < 3; c++) c == colIndex ? colValues[r] : mat.at(r, c),
        ],
    ]);
  }

  static int _findPivotRow(
    List<List<Rational>> m, {
    required int startRow,
    required int col,
  }) {
    for (int r = startRow; r < m.length; r++) {
      if (!m[r][col].isZero) return r;
    }
    return -1;
  }

  static void _swapRows(List<List<Rational>> m, int r1, int r2) {
    final temp = m[r1];
    m[r1] = m[r2];
    m[r2] = temp;
  }

  /// Realiza `F_target <- alpha * F_target - beta * F_pivot` evitando fracciones
  /// cuando los pivotes son enteros y devolviendo la expresión LaTeX de la transformación.
  static String _eliminateRow(
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
      _reduceToEchelonWithDescriptions(List<List<Rational>> m) {
    final recorded = <({int col, List<String> ops, String matrixLatex})>[];
    int pivotRow = 0;
    for (int col = 0; col < 3 && pivotRow < 3; col++) {
      final found = _findPivotRow(m, startRow: pivotRow, col: col);
      if (found == -1) continue;

      final ops = <String>[];
      if (found != pivotRow) {
        _swapRows(m, pivotRow, found);
        ops.add('F_${pivotRow + 1} \\leftrightarrow F_${found + 1}');
      }
      for (int r = pivotRow + 1; r < 3; r++) {
        if (!m[r][col].isZero) {
          ops.add(_eliminateRow(m, pivotRow: pivotRow, targetRow: r, col: col));
        }
      }
      if (ops.isNotEmpty) {
        recorded.add((col: col, ops: ops, matrixLatex: _augmentedLatex(m)));
      }
      pivotRow++;
    }
    return recorded;
  }

  static void _reduceToEchelonSilent(List<List<Rational>> m) {
    _reduceToEchelonWithDescriptions(m);
  }

  static ({int rankA, int rankAb}) _computeRanksFromEchelon(
    List<List<Rational>> echelon,
  ) {
    int rankA = 0;
    int rankAb = 0;
    // Evaluamos filas de matriz escalonada comprobando además posible dependencia si col 0 == 0
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

  static String _augmentedLatex(List<List<Rational>> m) {
    final rowsStr = m
        .map((r) => '${r[0].toLatex()} & ${r[1].toLatex()} & ${r[2].toLatex()} & ${r[3].toLatex()}')
        .join(' \\\\\n');
    return '\\left(\\begin{array}{ccc|c}\n$rowsStr\n\\end{array}\\right)';
  }

  static String _fractionLatex(Rational num, Rational den, Rational simplified) {
    if (den == Rational(1)) return simplified.toLatex();
    if (num.isInteger && den.isInteger) {
      final raw = '\\frac{${num.numerator}}{${den.numerator}}';
      if (raw == simplified.toLatex()) return raw;
      return '$raw = ${simplified.toLatex()}';
    }
    return simplified.toLatex();
  }

  static String _formatTerm(Rational coeff, String varName, {required bool isFirst}) {
    if (coeff.isZero) return '';
    final absVal = coeff.abs();
    final absCore = absVal == Rational(1) ? varName : '${absVal.toLatex()}$varName';
    if (isFirst) {
      return coeff.isNegative ? '-$absCore' : absCore;
    }
    return coeff.isNegative ? ' - $absCore' : ' + $absCore';
  }

  static String _formatEquationLatex(
    Rational a,
    Rational b,
    Rational c,
    Rational d,
  ) {
    final buf = StringBuffer();
    bool hasWritten = false;
    for (final (coeff, v) in [(a, 'x'), (b, 'y'), (c, 'z')]) {
      final piece = _formatTerm(coeff, v, isFirst: !hasWritten);
      if (piece.isNotEmpty) {
        buf.write(piece);
        hasWritten = true;
      }
    }
    final lhs = hasWritten ? buf.toString() : '0';
    return '$lhs = ${d.toLatex()}';
  }

  static String _formatZEquation(Rational c3, Rational d3) {
    return '${_formatTerm(c3, 'z', isFirst: true)} = ${d3.toLatex()}';
  }

  static String _formatYBackSub(Rational b2, Rational c2, Rational z, Rational d2) {
    final left = _formatTerm(b2, 'y', isFirst: true);
    if (c2.isZero) return '$left = ${d2.toLatex()}';
    final prod = c2 * z;
    if (prod.isZero) return '$left = ${d2.toLatex()}';
    final op = prod.isNegative ? ' - ' : ' + ';
    return '$left$op${prod.abs().toLatex()} = ${d2.toLatex()}';
  }

  static String _formatXBackSub(
    Rational a1,
    Rational b1,
    Rational c1,
    Rational y,
    Rational z,
    Rational d1,
  ) {
    final buf = StringBuffer(_formatTerm(a1, 'x', isFirst: true));
    final by = b1 * y;
    final cz = c1 * z;
    if (!by.isZero) {
      buf.write(by.isNegative ? ' - ${by.abs().toLatex()}' : ' + ${by.toLatex()}');
    }
    if (!cz.isZero) {
      buf.write(cz.isNegative ? ' - ${cz.abs().toLatex()}' : ' + ${cz.toLatex()}');
    }
    return '${buf.toString()} = ${d1.toLatex()}';
  }
}
