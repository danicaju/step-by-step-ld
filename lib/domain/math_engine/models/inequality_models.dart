import '../solvers/inequality_solver.dart';

/// Representa un intervalo unidimensional en la recta real.
class InequalityInterval {
  final double start;
  final double end;
  final bool includeStart;
  final bool includeEnd;
  final String? startLabel;
  final String? endLabel;

  /// Indica si este intervalo satisface la inecuación (para tablas de signos SÍ / NO).
  final bool isSatisfied;

  const InequalityInterval({
    required this.start,
    required this.end,
    this.includeStart = false,
    this.includeEnd = false,
    this.startLabel,
    this.endLabel,
    this.isSatisfied = true,
  });

  bool get isLeftUnbounded => start == double.negativeInfinity;
  bool get isRightUnbounded => end == double.infinity;
  bool get isBounded => !isLeftUnbounded && !isRightUnbounded;

  String toIntervalLatex() {
    if (isLeftUnbounded && isRightUnbounded) {
      return r'(-\infty, +\infty)';
    }
    final leftBracket = includeStart ? '[' : '(';
    final rightBracket = includeEnd ? ']' : ')';
    final leftStr = isLeftUnbounded ? r'-\infty' : (startLabel ?? _formatDouble(start));
    final rightStr = isRightUnbounded ? r'+\infty' : (endLabel ?? _formatDouble(end));
    return '$leftBracket$leftStr, $rightStr$rightBracket';
  }

  static String _formatDouble(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}

/// Punto crítico en la recta real.
class CriticalPoint {
  final double value;
  final String label;
  final bool isClosed; // true = punto relleno [●], false = punto hueco (○)

  const CriticalPoint({
    required this.value,
    required this.label,
    required this.isClosed,
  });
}

/// Datos estructurados para la renderización visual en la recta real (1D).
class Inequality1DVisualData {
  /// Puntos críticos marcados sobre la recta.
  final List<CriticalPoint> criticalPoints;

  /// Intervalos solución de la inecuación primaria (o S_1).
  final List<InequalityInterval> primaryIntervals;

  /// Intervalos solución de la inecuación secundaria S_2 (para sistemas 1D).
  final List<InequalityInterval>? secondaryIntervals;

  /// Intervalo común S_f = S_1 ∩ S_2 con rayado cruzado / malla.
  final List<InequalityInterval>? intersectionIntervals;

  /// Todos los intervalos de la recta con indicador SÍ/NO (para 2.º grado y racionales).
  final List<InequalityInterval>? signTestIntervals;

  /// Título o leyenda (ej. "S: (-∞, 3)", "S₁ ∩ S₂ = [1, 4]").
  final String solutionLatex;

  final String? label1;
  final String? label2;

  const Inequality1DVisualData({
    required this.criticalPoints,
    required this.primaryIntervals,
    this.secondaryIntervals,
    this.intersectionIntervals,
    this.signTestIntervals,
    required this.solutionLatex,
    this.label1,
    this.label2,
  });

  bool get isSystem => secondaryIntervals != null && secondaryIntervals!.isNotEmpty;
}

/// Punto 2D para vértices de regiones en el plano.
class Point2D {
  final double x;
  final double y;
  final String? label;
  final bool isOpen;

  const Point2D(this.x, this.y, [this.label, this.isOpen = false]);

  String toLatex({bool useFraction = true}) {
    final xStr = _fmtCoord(x, useFraction);
    final yStr = _fmtCoord(y, useFraction);
    return '($xStr, $yStr)';
  }

  static String _fmtCoord(double v, bool useFraction) {
    if (v.isNaN || v.isInfinite) return '0';
    if ((v - v.roundToDouble()).abs() < 1e-6) {
      return v.round().toString();
    }
    if (useFraction) {
      for (int den = 2; den <= 12; den++) {
        final num = (v * den).round();
        if ((v - num / den).abs() < 1e-5) {
          final isNeg = num < 0;
          final absNum = num.abs();
          return isNeg ? '-\\frac{$absNum}{$den}' : '\\frac{$absNum}{$den}';
        }
      }
    }
    return v.toStringAsFixed(2);
  }

  @override
  String toString() => 'Point2D($x, $y${isOpen ? ", open" : ""})';
}

/// Inecuación lineal de 2 incógnitas normalizada a la forma estándar normA*x + normB*y <= normC.
class LinearInequality2D {
  final double a;
  final double b;
  final double c;
  final InequalitySign sign;
  final String rawInput;

  /// Coeficientes normalizados a la forma: normA * x + normB * y <= normC
  final double normA;
  final double normB;
  final double normC;

  /// Indica si la desigualdad original es estricta (< o >).
  final bool isStrict;

  const LinearInequality2D({
    required this.a,
    required this.b,
    required this.c,
    required this.sign,
    required this.rawInput,
    required this.normA,
    required this.normB,
    required this.normC,
    required this.isStrict,
  });

  /// Crea una inecuación 2D normalizando automáticamente a la forma <=.
  factory LinearInequality2D.create({
    required double a,
    required double b,
    required double c,
    required InequalitySign sign,
    required String rawInput,
  }) {
    final isStrict = sign.isStrict;
    // Si la desigualdad es >= o >, multiplicamos por -1 para invertirla a <=
    final invert = sign == InequalitySign.greater || sign == InequalitySign.greaterOrEqual;
    final normA = invert ? -a : a;
    final normB = invert ? -b : b;
    final normC = invert ? -c : c;

    return LinearInequality2D(
      a: a,
      b: b,
      c: c,
      sign: sign,
      rawInput: rawInput,
      normA: normA,
      normB: normB,
      normC: normC,
      isStrict: isStrict,
    );
  }

  /// Indica si la recta frontera es continua (<= o >=) o discontinua (< o >).
  bool get isBoundarySolid => !isStrict;

  /// Evalúa si el punto (x, y) cumple la inecuación en su forma normalizada.
  bool evaluatesTrue(double px, double py, {bool strictCheck = false}) {
    final val = normA * px + normB * py;
    const eps = 1e-7;
    if (strictCheck && isStrict) {
      return val < normC - eps;
    }
    return val <= normC + eps;
  }

  /// Evalúa en el punto de prueba (px, py) retornando diferencia y cumplimiento.
  ({double value, bool satisfied}) testPoint(double px, double py) {
    final origVal = a * px + b * py;
    const eps = 1e-7;
    final satisfied = switch (sign) {
      InequalitySign.less => origVal < c - eps,
      InequalitySign.lessOrEqual => origVal <= c + eps,
      InequalitySign.greater => origVal > c + eps,
      InequalitySign.greaterOrEqual => origVal >= c - eps,
    };
    return (value: origVal, satisfied: satisfied);
  }
}

/// Datos estructurados para la renderización de la región factible 2D.
class FeasibleRegion2DVisualData {
  final List<LinearInequality2D> inequalities;
  final List<Point2D> vertices;
  final bool isBounded;
  final bool isEmpty;
  final String solutionSummaryLatex;

  const FeasibleRegion2DVisualData({
    required this.inequalities,
    required this.vertices,
    required this.isBounded,
    required this.isEmpty,
    required this.solutionSummaryLatex,
  });
}
