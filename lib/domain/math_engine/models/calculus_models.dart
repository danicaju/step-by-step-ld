import '../ast/ast_nodes.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../parser/expression_parser.dart';

/// Operaciones de Cálculo Infinitesimal disponibles en el Modo 14 (1.º y 2.º Bachillerato).
enum CalculusOperation {
  derivative("f'(x)"),
  tangentLine('Tangente'),
  indefiniteIntegral('∫ f(x)dx'),
  definiteIntegral('∫ₐᵇ Barrow');

  final String shortLabel;
  const CalculusOperation(this.shortLabel);
}

/// Polinomio exacto en una variable `x` con coeficientes racionales ([Rational]).
class RationalPolynomial {
  /// Mapa `{exponente: coeficiente}` manteniendo solo términos con exponente >= 0.
  final Map<int, Rational> coeffsByDegree;

  RationalPolynomial._(Map<int, Rational> map)
      : coeffsByDegree = Map.unmodifiable({
          for (final e in map.entries)
            if (!e.value.isZero) e.key: e.value,
        });

  /// Construye un polinomio a partir de `{grado: coeficiente}`.
  factory RationalPolynomial.fromMap(Map<int, Rational> map) =>
      RationalPolynomial._(map);

  /// Construye un polinomio desde coeficientes ordenados de mayor a menor grado (`[aₙ, ..., a₁, a₀]`).
  factory RationalPolynomial.fromDescendingRationals(List<Rational> coeffs) {
    final map = <int, Rational>{};
    final maxDeg = coeffs.length - 1;
    for (int i = 0; i < coeffs.length; i++) {
      final deg = maxDeg - i;
      if (!coeffs[i].isZero) {
        map[deg] = coeffs[i];
      }
    }
    return RationalPolynomial._(map);
  }

  factory RationalPolynomial.fromDescendingInts(List<int> coeffs) =>
      RationalPolynomial.fromDescendingRationals(
        coeffs.map((c) => Rational(c)).toList(),
      );

  /// Parsea una expresión polinómica introducida en la calculadora (ej. `x^3 - 3x^2 + 2`, `3x^2`, `(1/2)x^2 - 1`).
  factory RationalPolynomial.parseExpression(String raw) {
    final clean = raw
        .trim()
        .replaceAll('²', '^2')
        .replaceAll('³', '^3')
        .replaceAll('·', '*')
        .replaceAll('−', '-')
        .replaceAll(',', '.');
    if (clean.isEmpty) {
      throw const FormatException('Introduce una función polinómica en x.');
    }
    final node = ExpressionParser().parse(clean);
    return _astToPolynomial(node);
  }

  static RationalPolynomial _astToPolynomial(ExprNode node) {
    return switch (node) {
      IntNode(value: final v) => RationalPolynomial.fromMap({0: Rational(v)}),
      FractionNode() => RationalPolynomial.fromMap({0: node.toRawRational().simplify()}),
      ResolvedRationalNode(value: final r) => RationalPolynomial.fromMap({0: r}),
      DecimalNode() => RationalPolynomial.fromMap({0: node.toRational()}),
      VariableNode(name: final name) when name.toLowerCase() == 'x' =>
        RationalPolynomial.fromMap({1: Rational(1)}),
      UnaryMinusNode(operand: final inner) => _astToPolynomial(inner).scale(Rational(-1)),
      PowerNode(base: final b, exponent: final exp) => _powerPoly(b, exp),
      BinaryOpNode(left: final l, op: final op, right: final r) =>
        _binaryPoly(l, op, r),
      _ => throw const FormatException(
          'Este modo admite polinomios y potencias en x (ej. x^3 - 3x^2 + 2).',
        ),
    };
  }

  static RationalPolynomial _powerPoly(ExprNode base, int exp) {
    if (exp < 0) {
      final basePoly = _astToPolynomial(base);
      if (basePoly.degree == 0) {
        return RationalPolynomial.fromMap({0: basePoly.evaluate(Rational(0)).pow(exp)});
      }
      throw const FormatException('Introduce exponentes enteros no negativos en x.');
    }
    var acc = RationalPolynomial.fromMap({0: Rational(1)});
    final p = _astToPolynomial(base);
    for (int i = 0; i < exp; i++) {
      acc = acc * p;
    }
    return acc;
  }

  static RationalPolynomial _binaryPoly(ExprNode l, BinaryOperator op, ExprNode r) {
    final lp = _astToPolynomial(l);
    final rp = _astToPolynomial(r);
    return switch (op) {
      BinaryOperator.add => lp + rp,
      BinaryOperator.subtract => lp - rp,
      BinaryOperator.multiply => lp * rp,
      BinaryOperator.divide => _divideByConstantPoly(lp, rp),
    };
  }

  static RationalPolynomial _divideByConstantPoly(
    RationalPolynomial numPoly,
    RationalPolynomial denPoly,
  ) {
    if (denPoly.isZero) {
      throw const FormatException('División por cero en la expresión.');
    }
    if (denPoly.degree > 0) {
      throw const FormatException('El denominador de un término polinómico debe ser numérico constante.');
    }
    final c = denPoly.coeffOf(0);
    return numPoly.scale(Rational(1) / c);
  }

  bool get isZero => coeffsByDegree.isEmpty;

  int get degree {
    if (coeffsByDegree.isEmpty) return 0;
    return coeffsByDegree.keys.reduce((a, b) => a > b ? a : b);
  }

  List<int> get descendingDegrees {
    final list = coeffsByDegree.keys.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  Rational coeffOf(int deg) => coeffsByDegree[deg] ?? Rational(0);

  Rational evaluate(Rational x) {
    Rational total = Rational(0);
    for (final entry in coeffsByDegree.entries) {
      final termVal = entry.value * x.pow(entry.key);
      total = total + termVal;
    }
    return total;
  }

  RationalPolynomial derivative() {
    final map = <int, Rational>{};
    for (final entry in coeffsByDegree.entries) {
      if (entry.key == 0) continue;
      map[entry.key - 1] = entry.value * Rational(entry.key);
    }
    return RationalPolynomial._(map);
  }

  RationalPolynomial antiderivative() {
    final map = <int, Rational>{};
    for (final entry in coeffsByDegree.entries) {
      map[entry.key + 1] = entry.value / Rational(entry.key + 1);
    }
    return RationalPolynomial._(map);
  }

  RationalPolynomial scale(Rational k) {
    if (k.isZero) return RationalPolynomial._({});
    return RationalPolynomial._({
      for (final e in coeffsByDegree.entries) e.key: e.value * k,
    });
  }

  RationalPolynomial operator +(RationalPolynomial other) {
    final map = Map<int, Rational>.from(coeffsByDegree);
    for (final e in other.coeffsByDegree.entries) {
      map[e.key] = (map[e.key] ?? Rational(0)) + e.value;
    }
    return RationalPolynomial._(map);
  }

  RationalPolynomial operator -(RationalPolynomial other) =>
      this + other.scale(Rational(-1));

  RationalPolynomial operator *(RationalPolynomial other) {
    final map = <int, Rational>{};
    for (final e1 in coeffsByDegree.entries) {
      for (final e2 in other.coeffsByDegree.entries) {
        final deg = e1.key + e2.key;
        map[deg] = (map[deg] ?? Rational(0)) + (e1.value * e2.value);
      }
    }
    return RationalPolynomial._(map);
  }

  /// Formatea el polinomio al estilo humano (omite coeficientes 0 y 1 delante de x, sin `+ -`).
  String toLatex({String variable = 'x'}) {
    if (isZero) return '0';
    final buf = StringBuffer();
    bool first = true;
    for (final deg in descendingDegrees) {
      final c = coeffOf(deg);
      if (c.isZero) continue;
      final absC = c.abs();
      final core = switch (deg) {
        0 => absC.toLatex(),
        1 => absC == Rational(1) ? variable : '${absC.toLatex()}$variable',
        _ => absC == Rational(1)
            ? '$variable^{$deg}'
            : '${absC.toLatex()}$variable^{$deg}',
      };
      if (first) {
        buf.write(c.isNegative ? '-$core' : core);
        first = false;
      } else {
        buf.write(c.isNegative ? ' - $core' : ' + $core');
      }
    }
    return buf.isEmpty ? '0' : buf.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RationalPolynomial) return false;
    if (coeffsByDegree.length != other.coeffsByDegree.length) return false;
    for (final e in coeffsByDegree.entries) {
      if (other.coeffsByDegree[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        descendingDegrees.map((d) => Object.hash(d, coeffsByDegree[d])),
      );
}

/// Resultado estructurado para Cálculo (Derivadas, Recta Tangente e Integrales).
class CalculusAnalysisResult {
  final RationalPolynomial? resultPolynomial;
  final Rational? definiteValue;
  final Rational? slopeM;
  final Rational? interceptN;
  final StepByStepResolution resolution;

  const CalculusAnalysisResult({
    this.resultPolynomial,
    this.definiteValue,
    this.slopeM,
    this.interceptN,
    required this.resolution,
  });
}
