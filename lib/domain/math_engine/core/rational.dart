class Rational {
  final int numerator;
  final int denominator;

  const Rational._(this.numerator, this.denominator);

  /// Crea una fracción normalizando el signo en el numerador (sin simplificar aún
  /// si queremos mostrar primero el paso de simplificación al alumno).
  factory Rational.raw(int num, [int den = 1]) {
    if (den == 0) {
      throw ArgumentError('División por cero no permitida en el motor.');
    }
    if (den < 0) {
      return Rational._(-num, -den);
    }
    return Rational._(num, den);
  }

  /// Crea una fracción irreducible automáticamente.
  factory Rational(int num, [int den = 1]) {
    final raw = Rational.raw(num, den);
    return raw.simplify();
  }

  /// Crea una aproximación racional a partir de un número double.
  factory Rational.fromDouble(double val, [int precision = 10000]) {
    final num = (val * precision).round();
    return Rational(num, precision);
  }

  /// Crea una fracción EXACTA desde una cadena decimal finita (ej: "3.2" -> 16/5).
  factory Rational.fromDecimalString(String raw) {
    final clean = raw.trim().replaceAll(',', '.');
    if (clean.isEmpty) {
      throw ArgumentError('Cadena decimal vacia.');
    }
    final isNeg = clean.startsWith('-');
    final unsigned = (isNeg || clean.startsWith('+')) ? clean.substring(1) : clean;
    final parts = unsigned.split('.');
    if (parts.length > 2) {
      throw FormatException('Numero decimal invalido: $raw');
    }
    final intPart = parts[0].isEmpty ? '0' : parts[0];
    final fracPart = parts.length == 2 ? parts[1] : '';
    final digits = '$intPart$fracPart';
    final intVal = int.parse(digits);
    int den = 1;
    for (int i = 0; i < fracPart.length; i++) {
      den *= 10;
    }
    return Rational(isNeg ? -intVal : intVal, den);
  }

  bool get isInteger => denominator == 1;
  bool get isZero => numerator == 0;
  bool get isPositive => numerator > 0;
  bool get isNegative => numerator < 0;
  bool get isReducible => gcd(numerator.abs(), denominator.abs()) > 1;

  Rational abs() => numerator < 0 ? Rational._(-numerator, denominator) : this;

  Rational operator -() => Rational._(-numerator, denominator);

  double toDouble() => numerator / denominator;

  /// Máximo Común Divisor (Algoritmo de Euclides)
  static int gcd(int a, int b) {
    int x = a.abs();
    int y = b.abs();
    while (y != 0) {
      final t = y;
      y = x % y;
      x = t;
    }
    return x == 0 ? 1 : x;
  }

  /// Máximo Común Divisor de 2 o más enteros
  static int gcdMany(List<int> nums) {
    if (nums.isEmpty) return 1;
    int acc = nums.first.abs();
    for (int i = 1; i < nums.length; i++) {
      acc = gcd(acc, nums[i]);
    }
    return acc == 0 ? 1 : acc;
  }

  /// Mínimo Común Múltiplo
  static int lcm(int a, int b) {
    if (a == 0 || b == 0) return 0;
    return ((a.abs() ~/ gcd(a, b)) * b.abs());
  }

  /// Mínimo Común Múltiplo de 2 o más enteros
  static int lcmMany(List<int> nums) {
    if (nums.isEmpty) return 0;
    int acc = nums.first.abs();
    for (int i = 1; i < nums.length; i++) {
      acc = lcm(acc, nums[i]);
    }
    return acc;
  }

  /// Mapa ordenado `{primo: exponente}` para un entero positivo.
  static Map<int, int> primeFactorsMap(int n) {
    int value = n.abs();
    final Map<int, int> factors = {};
    if (value <= 1) return factors;

    int divisor = 2;
    while (value > 1) {
      while (value % divisor == 0) {
        factors[divisor] = (factors[divisor] ?? 0) + 1;
        value ~/= divisor;
      }
      divisor++;
      if (divisor * divisor > value && value > 1) {
        factors[value] = (factors[value] ?? 0) + 1;
        break;
      }
    }
    return factors;
  }

  /// Convierte un mapa `{primo: exponente}` a LaTeX (`2^{2} \cdot 3`).
  static String factorMapToLatex(Map<int, int> factors) {
    if (factors.isEmpty) return '1';
    final sortedKeys = factors.keys.toList()..sort();
    return sortedKeys.map((prime) {
      final exp = factors[prime]!;
      return exp > 1 ? '$prime^{$exp}' : '$prime';
    }).join(r' \cdot ');
  }

  /// Descomposición en factores primos en formato LaTeX (ej: 12 -> "2^{2} \cdot 3")
  static String primeFactorizationLatex(int n) {
    final value = n.abs();
    if (value <= 1) return value.toString();
    return factorMapToLatex(primeFactorsMap(value));
  }

  Rational simplify() {
    if (numerator == 0) return const Rational._(0, 1);
    final common = gcd(numerator, denominator);
    return Rational._(numerator ~/ common, denominator ~/ common);
  }

  Rational operator +(Rational other) => Rational(
        numerator * other.denominator + other.numerator * denominator,
        denominator * other.denominator,
      );

  Rational operator -(Rational other) => Rational(
        numerator * other.denominator - other.numerator * denominator,
        denominator * other.denominator,
      );

  Rational operator *(Rational other) => Rational(
        numerator * other.numerator,
        denominator * other.denominator,
      );

  Rational operator /(Rational other) {
    if (other.numerator == 0) {
      throw ArgumentError('No se puede dividir entre una fracción nula.');
    }
    return Rational(
      numerator * other.denominator,
      denominator * other.numerator,
    );
  }

  Rational pow(int exponent) {
    if (exponent == 0) return const Rational._(1, 1);
    int powInt(int base, int exp) {
      int result = 1;
      for (int i = 0; i < exp; i++) {
        result *= base;
      }
      return result;
    }

    if (exponent > 0) {
      return Rational(powInt(numerator, exponent), powInt(denominator, exponent));
    } else {
      final posExp = exponent.abs();
      return Rational(powInt(denominator, posExp), powInt(numerator, posExp));
    }
  }

  /// Formato LaTeX exacto para Natural Textbook Display
  String toLatex() {
    if (denominator == 1) return '$numerator';
    if (numerator < 0) {
      return '-\\frac{${numerator.abs()}}{$denominator}';
    }
    return '\\frac{$numerator}{$denominator}';
  }

  /// Formato decimal para la tecla S<=>D
  String toDecimalLatex({int maxDecimals = 6}) {
    final value = numerator / denominator;
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    String formatted = value.toStringAsFixed(maxDecimals);
    formatted = formatted.replaceFirst(RegExp(r'0+$'), '');
    formatted = formatted.replaceFirst(RegExp(r'\.$'), '');
    return formatted.replaceAll('.', ','); // Coma decimal española
  }

  @override
  bool operator ==(Object other) =>
      other is Rational &&
      other.numerator == numerator &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);
}
