import '../core/rational.dart';
import '../models/step_resolution.dart';

/// Operaciones matriciales disponibles en el Modo 8 (Bachillerato / EBAU).
enum MatrixOperation {
  determinant('|A| (Det)'),
  inverse('A⁻¹ (Inversa)'),
  adjoint('Adj(A)'),
  transpose('Aᵀ (Transpuesta)'),
  scalarMultiply('k·A'),
  gauss('Gauss / Rango'),
  cramer('Cramer (AX=B)'),
  multiply('A·B'),
  add('A+B'),
  subtract('A-B');

  final String shortLabel;
  const MatrixOperation(this.shortLabel);

  bool get needsMatrixB =>
      this == MatrixOperation.multiply ||
      this == MatrixOperation.add ||
      this == MatrixOperation.subtract ||
      this == MatrixOperation.cramer;
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

  /// Calcula el determinante exacto para matrices cuadradas (hasta 4x4).
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
    if (rowCount == 4) {
      // Desarrollo de Laplace por la primera fila
      var det = Rational(0);
      for (int c = 0; c < 4; c++) {
        final coeff = _rows[0][c];
        if (coeff.isZero) continue;
        final minor = minorSubmatrix(0, c);
        final minorDet = minor.determinantValue();
        final sign = (c % 2 == 0) ? Rational(1) : Rational(-1);
        det = det + (sign * coeff * minorDet);
      }
      return det;
    }
    throw FormatException('Dimensión $rowCount×$colCount no soportada para determinante directo.');
  }

  /// Calcula la matriz de adjuntos Adj(A) aplicando A_ij = (-1)^(i+j) * M_ij.
  RationalMatrix cofactorMatrix() {
    if (!isSquare || (rowCount != 2 && rowCount != 3 && rowCount != 4)) {
      throw const FormatException('La matriz adjunta requiere matriz cuadrada 2x2, 3x3 o 4x4.');
    }
    if (rowCount == 2) {
      return RationalMatrix.fromRationals([
        [_rows[1][1], -_rows[1][0]],
        [-_rows[0][1], _rows[0][0]],
      ]);
    }
    final dim = rowCount;
    final result = List.generate(dim, (r) {
      return List.generate(dim, (c) {
        final minor = minorSubmatrix(r, c).determinantValue();
        final sign = ((r + c) % 2 == 0) ? 1 : -1;
        return sign == 1 ? minor : -minor;
      });
    });
    return RationalMatrix.fromRationals(result);
  }

  /// Reemplaza una columna por un vector dado (utilizado en la Regla de Cramer).
  RationalMatrix replaceColumn(int colIdx, List<Rational> newCol) {
    if (newCol.length != rowCount) {
      throw const FormatException('El vector columna debe tener la misma longitud que las filas de A.');
    }
    final newRows = <List<Rational>>[];
    for (int r = 0; r < rowCount; r++) {
      final row = <Rational>[];
      for (int c = 0; c < colCount; c++) {
        row.add(c == colIdx ? newCol[r] : _rows[r][c]);
      }
      newRows.add(row);
    }
    return RationalMatrix.fromRationals(newRows);
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
      case MatrixOperation.transpose:
        return transpose(a);
      case MatrixOperation.gauss:
        return gauss(a, b);
      case MatrixOperation.cramer:
        if (b == null) {
          throw const FormatException('Se necesita el vector B para la Regla de Cramer.');
        }
        return cramer(a, b);
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

  /// Producto por un escalar `k · A` con visualización en la LCD en 3 pasos exactos.
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

    if (a.rowCount == 3) {
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

    // 4x4 -> Desarrollo de Laplace por la primera fila
    final subDets = <Rational>[];
    final laplaceTerms = <String>[];
    for (int c = 0; c < 4; c++) {
      final coeff = a.at(0, c);
      final minor = a.minorSubmatrix(0, c);
      final minorDet = minor.determinantValue();
      subDets.add(minorDet);
      final sign = (c % 2 == 0) ? '+' : '-';
      laplaceTerms.add('$sign ${_wrapNegative(coeff)} \\cdot |M_{1${c + 1}}|');
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

    final detRes = determinant(a);
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

  /// Regla de Cramer para resolver el sistema matricial A · X = B.
  static StepByStepResolution cramer(RationalMatrix a, RationalMatrix b) {
    if (!a.isSquare || a.rowCount < 2 || a.rowCount > 4) {
      throw const FormatException('La Regla de Cramer requiere una matriz cuadrada de orden 2, 3 o 4.');
    }
    // Vector b puede ser n x 1 o 1 x n
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
        latexExpression: _matrixRowsToLatex(rows),
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

    final echelonLatex = _matrixRowsToLatex(rows);
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

  static String _matrixRowsToLatex(List<List<Rational>> rows) {
    if (rows.isEmpty || rows.first.isEmpty) return '()';
    final colSpec = List.filled(rows.first.length, 'c').join();
    final rowLines = rows
        .map((r) => r.map((v) => v.toLatex()).join(' & '))
        .join(' \\\\\n');
    return '\\left(\\begin{array}{$colSpec}\n$rowLines\n\\end{array}\\right)';
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
