import '../../core/rational.dart';

/// Sentido de una desigualdad matemática.
/// Sentido de una desigualdad matemática.
enum InequalitySign {
  less('<'),
  lessOrEqual(r'\le'),
  greater('>'),
  greaterOrEqual(r'\ge');

  final String latex;
  const InequalitySign(this.latex);

  /// Símbolo legible en botones y vistas rápidas.
  String get symbol => switch (this) {
        InequalitySign.less => '<',
        InequalitySign.lessOrEqual => '≤',
        InequalitySign.greater => '>',
        InequalitySign.greaterOrEqual => '≥',
      };

  /// Indica si la desigualdad es estricta (extremos abiertos con paréntesis).
  bool get isStrict => switch (this) {
        InequalitySign.less || InequalitySign.greater => true,
        InequalitySign.lessOrEqual || InequalitySign.greaterOrEqual => false,
      };

  /// Devuelve el sentido opuesto al multiplicar o dividir por un número negativo.
  InequalitySign flipped() => switch (this) {
        InequalitySign.less => InequalitySign.greater,
        InequalitySign.lessOrEqual => InequalitySign.greaterOrEqual,
        InequalitySign.greater => InequalitySign.less,
        InequalitySign.greaterOrEqual => InequalitySign.lessOrEqual,
      };

  /// Comprueba si un signo (`-1`, `0`, `+1`) respecto a `0` satisface la desigualdad.
  bool matchesSign(int sign) => switch (this) {
        InequalitySign.less => sign < 0,
        InequalitySign.lessOrEqual => sign <= 0,
        InequalitySign.greater => sign > 0,
        InequalitySign.greaterOrEqual => sign >= 0,
      };

  /// Compara dos racionales `lhs` y `rhs` según el sentido de la desigualdad.
  bool compareRationals(Rational lhs, Rational rhs) {
    final diff = lhs - rhs;
    return matchesSign(diff.numerator.sign);
  }

  /// Parsea un operador de desigualdad (`<`, `<=`, `≤`, `\le`, `>`, `>=`, `≥`, `\ge`).
  static InequalitySign? tryParse(String token) => switch (token.trim()) {
        '<' => InequalitySign.less,
        '<=' || '≤' || r'\le' || r'\leq' => InequalitySign.lessOrEqual,
        '>' => InequalitySign.greater,
        '>=' || '≥' || r'\ge' || r'\geq' => InequalitySign.greaterOrEqual,
        _ => null,
      };
}

