import '../core/rational.dart';
import '../models/step_resolution.dart';

/// Operaciones matriciales disponibles en el Modo 10 (Bachillerato / EBAU).
enum MatrixOperation {
  determinant('|A| (Sarrus)'),
  inverse('A⁻¹ (Inversa)'),
  adjoint('Adj(A)'),
  multiply('A·B'),
  add('A+B'),
  subtract('A-B'),
  scalarMultiply('k·A');

  final String shortLabel;
  const MatrixOperation(this.shortLabel);

  bool get needsMatrixB =>
      this == MatrixOperation.multiply ||
      this == MatrixOperation.add ||
      this == MatrixOperation.subtract;
}

/// Matriz inmutable de números racionales exactos ([Rational]) para dimensiones 2x2 y 3x3.
class RationalMatrix {
  final int rowCount;
  final int colCount;
  final List<List<Rational>> _rows;

  RationalMatrix._(this.rowCount, this.colCount, List<List<Rational>> rows)
      : _rows = List<List<Rational>>.unmodifiable(
          rows.map((r) => List<Rational>.unmodifiable(r)),
        );

  /// Construye una matriz a partir de coeficientes [Rational].
  factory RationalMatrix.fromRationals(List<List<Rational>> rows) {
    if (rows.isEmpty || rows.first.isEmpty) {
      throw const FormatException('La matriz no puede estar vacía.');
    }
    final rCount = rows.length;
    final cCount = rows.first.length;
    for (final row in rows) {
      if (row.length != cCount) {
        throw const FormatException('Todas las filas de la matriz deben tener igual longitud.');
      }
    }
    return RationalMatrix._(rCount, cCount, rows);
  }

  /// Construye una matriz exacta a partir de enteros.
  factory RationalMatrix.fromInts(List<List<int>> rows) {
    return RationalMatrix.fromRationals(
      rows.map((r) => r.map((v) => Rational(v)).toList()).toList(),
    );
  }

  Rational at(int r, int c) => _rows[r][c];

  bool get isSquare => rowCount == colCount;

  /// Devuelve una copia de los valores como lista inmutable de filas.
  List<List<Rational>> get rows => _rows;

  /// Traspuesta A^t.
  RationalMatrix transpose() {
    final result = List.generate(
      colCount,
      (r) => List.generate(rowCount, (c) => _rows[c][r]),
    );
    return RationalMatrix.fromRationals(result);
  }

  /// Submatriz obtenida al suprimir la fila [omitRow] y la columna [omitCol].
  RationalMatrix minorSubmatrix(int omitRow, int omitCol) {
    final result = <List<Rational>>[];
    for (int r = 0; r < rowCount; r++) {
      if (r == omitRow) continue;
      final row = <Rational>[];
      for (int c = 0; c < colCount; c++) {
        if (c == omitCol) continue;
        row.add(_rows[r][c]);
      }
      result.add(row);
    }
    return RationalMatrix.fromRationals(result);
  }

  /// Calcula el determinante exacto para matrices cuadradas 1x1, 2x2 o 3x3.
  Rational determinantValue() {
    if (!isSquare) {
      throw const FormatException('El determinante solo existe para matrices cuadradas.');
    }
    if (rowCount == 1) {
      return _rows[0][0];
    }
    if (rowCount == 2) {
      return _rows[0][0] * _rows[1][1] - _rows[0][1] * _rows[1][0];
    }
    if (rowCount == 3) {
      final pos1 = _rows[0][0] * _rows[1][1] * _rows[2][2];
      final pos2 = _rows[0][1] * _rows[1][2] * _rows[2][0];
      final pos3 = _rows[0][2] * _rows[1][0] * _rows[2][1];
      final neg1 = _rows[0][2] * _rows[1][1] * _rows[2][0];
      final neg2 = _rows[0][0] * _rows[1][2] * _rows[2][1];
      final neg3 = _rows[0][1] * _rows[1][0] * _rows[2][2];
      return (pos1 + pos2 + pos3) - (neg1 + neg2 + neg3);
    }
    throw FormatException('Dimensión $rowCount×$colCount no soportada para determinante directo.');
  }

  /// Calcula la matriz de adjuntos Adj(A) aplicando A_ij = (-1)^(i+j) * M_ij.
  RationalMatrix cofactorMatrix() {
    if (!isSquare || (rowCount != 2 && rowCount != 3)) {
      throw const FormatException('La matriz adjunta requiere matriz cuadrada 2x2 o 3x3.');
    }
    if (rowCount == 2) {
      return RationalMatrix.fromRationals([
        [_rows[1][1], -_rows[1][0]],
        [-_rows[0][1], _rows[0][0]],
      ]);
    }
    final result = List.generate(3, (r) {
      return List.generate(3, (c) {
        final minor = minorSubmatrix(r, c).determinantValue();
        final sign = ((r + c) % 2 == 0) ? 1 : -1;
        return sign == 1 ? minor : -minor;
      });
    });
    return RationalMatrix.fromRationals(result);
  }

  /// Calcula la matriz inversa A⁻¹ = (1 / |A|) · (Adj(A))^t.
  RationalMatrix inverseMatrix() {
    final det = determinantValue();
    if (det.isZero) {
      throw const FormatException('Matriz singular (|A| = 0): no tiene inversa.');
    }
    final invDet = Rational(1) / det;
    return cofactorMatrix().transpose().scale(invDet);
  }

  RationalMatrix operator +(RationalMatrix other) {
    if (rowCount != other.rowCount || colCount != other.colCount) {
      throw const FormatException('Para sumar matrices deben tener la misma dimensión.');
    }
    return RationalMatrix.fromRationals([
      for (int r = 0; r < rowCount; r++)
        [for (int c = 0; c < colCount; c++) _rows[r][c] + other._rows[r][c]],
    ]);
  }

  RationalMatrix operator -(RationalMatrix other) {
    if (rowCount != other.rowCount || colCount != other.colCount) {
      throw const FormatException('Para restar matrices deben tener la misma dimensión.');
    }
    return RationalMatrix.fromRationals([
      for (int r = 0; r < rowCount; r++)
        [for (int c = 0; c < colCount; c++) _rows[r][c] - other._rows[r][c]],
    ]);
  }

  RationalMatrix scale(Rational k) {
    return RationalMatrix.fromRationals([
      for (int r = 0; r < rowCount; r++)
        [for (int c = 0; c < colCount; c++) _rows[r][c] * k],
    ]);
  }

  RationalMatrix operator *(RationalMatrix other) {
    if (colCount != other.rowCount) {
      throw const FormatException(
        'Para multiplicar A·B, las columnas de A deben coincidir con las filas de B.',
      );
    }
    return RationalMatrix.fromRationals([
      for (int r = 0; r < rowCount; r++)
        [
          for (int c = 0; c < other.colCount; c++)
            List.generate(colCount, (k) => _rows[r][k] * other._rows[k][c])
                .fold<Rational>(Rational(0), (acc, v) => acc + v),
        ],
    ]);
  }

  String _colSpec() => List.filled(colCount, 'c').join();

  /// Representa la matriz con `\left(\begin{array}{...}...\end{array}\right)`.
  String toLatex() {
    final rowsLatex = _rows
        .map((row) => row.map((v) => v.toLatex()).join(' & '))
        .join(' \\\\\n');
    return '\\left(\\begin{array}{${_colSpec()}}\n$rowsLatex\n\\end{array}\\right)';
  }

  /// Representa el determinante con `\left|\begin{array}{...}...\end{array}\right|`.
  String toDeterminantLatex() {
    final rowsLatex = _rows
        .map((row) => row.map((v) => v.toLatex()).join(' & '))
        .join(' \\\\\n');
    return '\\left|\\begin{array}{${_colSpec()}}\n$rowsLatex\n\\end{array}\\right|';
  }

  /// Representación decimal de toda la matriz (tecla S<=>D).
  String toDecimalLatex() {
    final rowsLatex = _rows
        .map((row) => row.map((v) => v.toDecimalLatex()).join(' & '))
        .join(' \\\\\n');
    return '\\left(\\begin{array}{${_colSpec()}}\n$rowsLatex\n\\end{array}\\right)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RationalMatrix) return false;
    if (rowCount != other.rowCount || colCount != other.colCount) return false;
    for (int r = 0; r < rowCount; r++) {
      for (int c = 0; c < colCount; c++) {
        if (_rows[r][c] != other._rows[r][c]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        rowCount,
        colCount,
        Object.hashAll(_rows.expand((r) => r)),
      );
}

class MatrixSolver {
  /// Despacha cualquier operación matricial al método paso a paso correspondiente.
  static StepByStepResolution solve({
    required MatrixOperation operation,
    required RationalMatrix a,
    RationalMatrix? b,
    Rational? scalar,
  }) {
    switch (operation) {
      case MatrixOperation.determinant:
        return determinant(a);
      case MatrixOperation.inverse:
        return inverse(a);
      case MatrixOperation.adjoint:
        return adjoint(a);
      case MatrixOperation.multiply:
        if (b == null) {
          throw const FormatException('Se necesita la matriz B para calcular A·B.');
        }
        return multiply(a, b);
      case MatrixOperation.add:
        if (b == null) {
          throw const FormatException('Se necesita la matriz B para calcular A + B.');
        }
        return add(a, b);
      case MatrixOperation.subtract:
        if (b == null) {
          throw const FormatException('Se necesita la matriz B para calcular A - B.');
        }
        return subtract(a, b);
      case MatrixOperation.scalarMultiply:
        return scalarMultiply(scalar ?? Rational(1), a);
    }
  }

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
            _formatBinarySumCell(a.at(r, c), b.at(r, c), isSubtract: false),
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
            _formatBinarySumCell(a.at(r, c), b.at(r, c), isSubtract: true),
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

  /// Producto por un escalar `k · A`.
  static StepByStepResolution scalarMultiply(Rational k, RationalMatrix a) {
    final result = a.scale(k);
    final colSpec = List.filled(a.colCount, 'c').join();
    final kLatex = k.toLatex();
    final multRows = [
      for (int r = 0; r < a.rowCount; r++)
        [
          for (int c = 0; c < a.colCount; c++)
            '$kLatex \\cdot ${_wrapNegative(a.at(r, c))}',
        ].join(' & '),
    ].join(' \\\\\n');

    return StepByStepResolution(
      originalInputLatex: '${_wrapNegative(k)} \\cdot ${a.toLatex()}',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Multiplicar todos los elementos por $kLatex',
          latexExpression:
              '$kLatex \\cdot A = \\left(\\begin{array}{$colSpec}\n$multRows\n\\end{array}\\right)',
          pedagogicalNote:
              'Para multiplicar una matriz por un escalar k, multiplicamos CADA uno de los elementos de A por $kLatex.',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Resultado simplificado',
          latexExpression: '$kLatex \\cdot A = ${result.toLatex()}',
          pedagogicalNote:
              'Simplificamos cada producto a su fracción irreducible.',
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
              (k) => '${_wrapNegative(a.at(r, k))} \\cdot ${_wrapNegative(b.at(k, c))}',
            ).join(' + '),
        ].join(' & '),
    ].join(' \\\\\n');

    final partialSumRows = [
      for (int r = 0; r < a.rowCount; r++)
        [
          for (int c = 0; c < b.colCount; c++)
            _formatSignedSumTerms([
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

  /// Determinante `|A|` (2x2 directo o 3x3 por Regla de Sarrus en 3 pasos).
  static StepByStepResolution determinant(RationalMatrix a) {
    if (!a.isSquare || (a.rowCount != 2 && a.rowCount != 3)) {
      throw const FormatException('El determinante guiado admite matrices 2x2 o 3x3.');
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
          '\\left|A\\right| = ${_wrapNegative(a.at(0, 0))} \\cdot ${_wrapNegative(a.at(1, 1))} - ${_wrapNegative(a.at(0, 1))} \\cdot ${_wrapNegative(a.at(1, 0))} = ${p1.toLatex()} ${_formatSignedOperand(-p2)}';

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

    // 3x3 -> Regla de Sarrus en 3 pasos exactos
    final pos1 = a.at(0, 0) * a.at(1, 1) * a.at(2, 2);
    final pos2 = a.at(0, 1) * a.at(1, 2) * a.at(2, 0);
    final pos3 = a.at(0, 2) * a.at(1, 0) * a.at(2, 1);
    final posSum = pos1 + pos2 + pos3;

    final neg1 = a.at(0, 2) * a.at(1, 1) * a.at(2, 0);
    final neg2 = a.at(0, 0) * a.at(1, 2) * a.at(2, 1);
    final neg3 = a.at(0, 1) * a.at(1, 0) * a.at(2, 2);
    final negSum = neg1 + neg2 + neg3;

    final posProductsExpr =
        '${_tripleProduct(a.at(0, 0), a.at(1, 1), a.at(2, 2))} + '
        '${_tripleProduct(a.at(0, 1), a.at(1, 2), a.at(2, 0))} + '
        '${_tripleProduct(a.at(0, 2), a.at(1, 0), a.at(2, 1))}';

    final negProductsExpr =
        '${_tripleProduct(a.at(0, 2), a.at(1, 1), a.at(2, 0))} + '
        '${_tripleProduct(a.at(0, 0), a.at(1, 2), a.at(2, 1))} + '
        '${_tripleProduct(a.at(0, 1), a.at(1, 0), a.at(2, 2))}';

    final step1Latex =
        'S_+ = \\left($posProductsExpr\\right) = ${_formatSignedSumTerms([pos1, pos2, pos3])} = ${posSum.toLatex()}';

    final negBlockVal = -negSum;
    final step2Latex =
        '-S_- = -\\left($negProductsExpr\\right) = -\\left(${_formatSignedSumTerms([neg1, neg2, neg3])}\\right) = -\\left(${negSum.toLatex()}\\right) = ${negBlockVal.toLatex()}';

    final step3Latex =
        '\\left|A\\right| = ${posSum.toLatex()} ${_formatSignedOperand(-negSum)} = $detLatex \\implies ${det.isZero ? r'\text{Singular (}\nexists A^{-1}\text{)}' : r'\text{Invertible, rg}(A)=3'}';

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

  /// Matriz Adjunta `Adj(A)` calculada mediante menores complementarios y tablero de signos.
  static StepByStepResolution adjoint(RationalMatrix a) {
    if (!a.isSquare || (a.rowCount != 2 && a.rowCount != 3)) {
      throw const FormatException('La matriz adjunta solo está disponible para 2x2 o 3x3.');
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

    // 3x3: Paso 1 signo board + menores 2x2 detallados, Paso 2 Matriz Adj(A) final
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

  /// Matriz Inversa `A⁻¹ = (1/|A|) · (Adj(A))^t` paso a paso estilo PAU/EBAU.
  static StepByStepResolution inverse(RationalMatrix a) {
    if (!a.isSquare || (a.rowCount != 2 && a.rowCount != 3)) {
      throw const FormatException('La inversa solo está disponible para matrices 2x2 o 3x3.');
    }

    final detRes = determinant(a);
    final det = a.determinantValue();

    // Paso 1: Comprobar determinante
    if (det.isZero) {
      final step1Expr = a.rowCount == 3
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

    final detSummary = a.rowCount == 3
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
          warningTrick:
              'Aplica el signo menos en las posiciones impares (1,2), (2,1), (2,3) y (3,2).',
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

  static String _wrapNegative(Rational r) {
    final l = r.toLatex();
    if (r.isNegative || !r.isInteger) return '\\left($l\\right)';
    return l;
  }

  static String _tripleProduct(Rational x, Rational y, Rational z) {
    return '${_wrapNegative(x)} \\cdot ${_wrapNegative(y)} \\cdot ${_wrapNegative(z)}';
  }

  static String _formatBinarySumCell(
    Rational a,
    Rational b, {
    required bool isSubtract,
  }) {
    final left = a.toLatex();
    if (!isSubtract) {
      if (b.isNegative) {
        return '$left - ${b.abs().toLatex()}';
      }
      return '$left + ${b.toLatex()}';
    } else {
      if (b.isNegative) {
        return '$left + ${b.abs().toLatex()}';
      }
      return '$left - ${b.toLatex()}';
    }
  }

  static String _formatSignedOperand(Rational r) {
    if (r.isNegative) return '- ${r.abs().toLatex()}';
    return '+ ${r.toLatex()}';
  }

  static String _formatSignedSumTerms(List<Rational> terms) {
    if (terms.isEmpty) return '0';
    final buf = StringBuffer();
    for (int i = 0; i < terms.length; i++) {
      final t = terms[i];
      if (i == 0) {
        buf.write(t.toLatex());
      } else {
        buf.write(t.isNegative ? ' - ${t.abs().toLatex()}' : ' + ${t.toLatex()}');
      }
    }
    return buf.toString();
  }
}
