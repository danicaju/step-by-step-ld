import '../core/rational.dart';

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

/// Matriz inmutable de números racionales exactos ([Rational]) para dimensiones 2x2, 3x3 y 4x4.
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
