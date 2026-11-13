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

/// Solver paso a paso de Derivadas, Recta Tangente e Integrales por Regla de Barrow (1.º y 2.º Bachillerato).
class CalculusSolver {
  static StepByStepResolution solve({
    required CalculusOperation operation,
    required String expressionRaw,
    Rational? tangentX0,
    Rational? integralLowerA,
    Rational? integralUpperB,
  }) {
    final poly = RationalPolynomial.parseExpression(expressionRaw);
    return switch (operation) {
      CalculusOperation.derivative => derivative(poly),
      CalculusOperation.tangentLine =>
        tangentLine(poly, tangentX0 ?? Rational(0)),
      CalculusOperation.indefiniteIntegral => indefiniteIntegral(poly),
      CalculusOperation.definiteIntegral => definiteIntegralBarrow(
          poly,
          integralLowerA ?? Rational(0),
          integralUpperB ?? Rational(1),
        ),
    };
  }

  /// Derivada término a término `f'(x)` aplicando `(a·xⁿ)' = n·a·xⁿ⁻¹`.
  static CalculusAnalysisResult analyzeDerivative(RationalPolynomial f) {
    final df = f.derivative();
    final fLatex = f.toLatex();

    if (f.isZero || f.degree == 0) {
      final res = StepByStepResolution(
        originalInputLatex: '\\frac{d}{dx}\\left($fLatex\\right)',
        steps: [
          MathStep(
            index: 1,
            shortTitle: 'Derivada de una función constante',
            latexExpression: "f(x) = $fLatex \\implies f'(x) = 0",
            pedagogicalNote:
                'La derivada de cualquier número constante es siempre 0, ya que su pendiente no varía en ningún punto.',
          ),
        ],
        exactResultLatex: "f'(x) = 0",
        decimalApproxLatex: "f'(x) = 0",
      );
      return CalculusAnalysisResult(resultPolynomial: df, resolution: res);
    }

    final ruleTerms = _derivativeRuleExpansionLatex(f);
    final dfLatex = df.toLatex();

    final res = StepByStepResolution(
      originalInputLatex: "f(x) = $fLatex",
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Paso 1: Regla de derivación término a término',
          latexExpression: "f'(x) = $ruleTerms",
          pedagogicalNote:
              'Aplicamos la derivada de una potencia (a·xⁿ)\' = n·a·xⁿ⁻¹ a cada sumando. La derivada de los términos constantes independientes es 0.',
          warningTrick: f.coeffOf(0) != Rational(0)
              ? 'El término independiente (${f.coeffOf(0).toLatex()}) se anula al derivar porque (c)\' = 0.'
              : null,
        ),
        MathStep(
          index: 2,
          shortTitle: 'Paso 2: Simplificar coeficientes y potencias',
          latexExpression: "f'(x) = $dfLatex",
          pedagogicalNote:
              'Multiplicamos cada exponente por su coeficiente y restamos 1 al exponente para obtener la función derivada f\'(x).',
        ),
      ],
      exactResultLatex: "f'(x) = $dfLatex",
      decimalApproxLatex: "f'(x) = $dfLatex",
    );

    return CalculusAnalysisResult(resultPolynomial: df, resolution: res);
  }

  static StepByStepResolution derivative(RationalPolynomial f) =>
      analyzeDerivative(f).resolution;

  /// Recta tangente a `f(x)` en `x = x₀`: `y - f(x₀) = f'(x₀)(x - x₀)`.
  static CalculusAnalysisResult analyzeTangentLine(
    RationalPolynomial f,
    Rational x0,
  ) {
    final df = f.derivative();
    final y0 = f.evaluate(x0);
    final m = df.evaluate(x0);
    // y = m*x + (y0 - m*x0)
    final n = y0 - m * x0;
    final linePoly = RationalPolynomial.fromMap({1: m, 0: n});

    final x0Latex = x0.toLatex();
    final y0Latex = y0.toLatex();
    final mLatex = m.toLatex();
    final lineLatex = 'y = ${linePoly.toLatex()}';

    final substFx0 = _substitutionLatex(f, x0);
    final substDfx0 = df.isZero ? '0' : _substitutionLatex(df, x0);

    final ySide = y0.isZero
        ? 'y'
        : (y0.isNegative ? 'y + ${(-y0).toLatex()}' : 'y - $y0Latex');
    final xFactor = x0.isZero
        ? 'x'
        : (x0.isNegative ? '\\left(x + ${(-x0).toLatex()}\\right)' : '\\left(x - $x0Latex\\right)');
    final pointSlope = m.isZero
        ? '$ySide = 0'
        : (m == Rational(1)
            ? '$ySide = $xFactor'
            : (m == Rational(-1)
                ? '$ySide = -$xFactor'
                : '$ySide = $mLatex \\cdot $xFactor'));

    final res = StepByStepResolution(
      originalInputLatex: 'f(x) = ${f.toLatex()},\\; x_{0} = $x0Latex',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Paso 1: Calcular ordenada del punto f($x0Latex)',
          latexExpression: 'f($x0Latex) = $substFx0 = $y0Latex \\implies P\\left($x0Latex, $y0Latex\\right)',
          pedagogicalNote:
              'Evaluamos la función original en x₀ = $x0Latex para hallar el punto de tangencia P(x₀, f(x₀)).',
        ),
        MathStep(
          index: 2,
          shortTitle: "Paso 2: Derivar f'(x) y hallar pendiente m = f'($x0Latex)",
          latexExpression: "f'(x) = ${df.toLatex()} \\implies m = f'($x0Latex) = $substDfx0 = $mLatex",
          pedagogicalNote:
              'La derivada evaluada en x₀ nos da exactamente la pendiente m de la recta tangente en ese punto.',
        ),
        MathStep(
          index: 3,
          shortTitle: 'Paso 3: Ecuación punto-pendiente y explícita',
          latexExpression: '$pointSlope \\implies $lineLatex',
          pedagogicalNote:
              'Sustituimos en y - f(x₀) = f\'(x₀)·(x - x₀) y despejamos y para obtener la forma explícita y = mx + n.',
          warningTrick: x0.isNegative || y0.isNegative
              ? 'Atención a la regla de los signos: si x₀ o f(x₀) es negativo, x - (-a) pasa a ser x + a.'
              : null,
        ),
      ],
      exactResultLatex: lineLatex,
      decimalApproxLatex:
          'y = ${m.toDecimalLatex()}x ${n.isZero ? '' : (n.isNegative ? '- ${(-n).toDecimalLatex()}' : '+ ${n.toDecimalLatex()}')}'.trim(),
    );

    return CalculusAnalysisResult(
      resultPolynomial: linePoly,
      slopeM: m,
      interceptN: n,
      resolution: res,
    );
  }

  static StepByStepResolution tangentLine(RationalPolynomial f, Rational x0) =>
      analyzeTangentLine(f, x0).resolution;

  /// Integral indefinida `\int P(x)\,dx` término a término con `+ C`.
  static CalculusAnalysisResult analyzeIndefiniteIntegral(RationalPolynomial f) {
    final fLatex = f.toLatex();
    final antideriv = f.antiderivative();

    if (f.isZero) {
      final res = StepByStepResolution(
        originalInputLatex: '\\int 0\\,dx',
        steps: const [
          MathStep(
            index: 1,
            shortTitle: 'Integral de la función nula',
            latexExpression: '\\int 0\\,dx = C',
            pedagogicalNote:
                'La única familia de funciones cuya derivada es 0 son las constantes arbitrarias C.',
          ),
        ],
        exactResultLatex: 'C',
        decimalApproxLatex: 'C',
      );
      return CalculusAnalysisResult(resultPolynomial: antideriv, resolution: res);
    }

    final expansion = _integralRuleExpansionLatex(f);
    final primitiveLatex = antideriv.toLatex();

    final res = StepByStepResolution(
      originalInputLatex: '\\int \\left($fLatex\\right)\\,dx',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Paso 1: Integrar término a término',
          latexExpression: '\\int \\left($fLatex\\right)\\,dx = $expansion',
          pedagogicalNote:
              'Aplicamos la regla de la potencia inversa ∫ a·xⁿ dx = a · xⁿ⁺¹/(n+1) a cada término (y ∫ c dx = c·x).',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Paso 2: Simplificar primitiva y añadir + C',
          latexExpression: 'F(x) = $primitiveLatex + C',
          pedagogicalNote:
              'Simplificamos todas las fracciones resultantes a irreducibles y añadimos la constante de integración C.',
          warningTrick:
              'Es necesario incluir siempre la constante de integración + C en una integral indefinida.',
        ),
      ],
      exactResultLatex: '$primitiveLatex + C',
      decimalApproxLatex: '$primitiveLatex + C',
    );

    return CalculusAnalysisResult(resultPolynomial: antideriv, resolution: res);
  }

  static StepByStepResolution indefiniteIntegral(RationalPolynomial f) =>
      analyzeIndefiniteIntegral(f).resolution;

  /// Integral definida `\int_a^b P(x)\,dx` usando la Regla de Barrow `[F(x)]_a^b = F(b) - F(a)`.
  static CalculusAnalysisResult analyzeDefiniteIntegralBarrow(
    RationalPolynomial f,
    Rational a,
    Rational b,
  ) {
    final fLatex = f.toLatex();
    final aLatex = a.toLatex();
    final bLatex = b.toLatex();
    final antideriv = f.antiderivative();
    final fUpper = antideriv.evaluate(b);
    final fLower = antideriv.evaluate(a);
    final total = fUpper - fLower;

    final primLatex = antideriv.toLatex();
    final substB = antideriv.isZero ? '0' : _substitutionLatex(antideriv, b);
    final substA = antideriv.isZero ? '0' : _substitutionLatex(antideriv, a);

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Paso 1: Hallar la primitiva F(x)',
        latexExpression: f.isZero
            ? 'F(x) = 0'
            : 'F(x) = \\int \\left($fLatex\\right)\\,dx = ${_integralRuleExpansionLatex(f)} = $primLatex',
        pedagogicalNote:
            'Integramos término a término con ∫ a·xⁿ dx = a·xⁿ⁺¹/(n+1). En integrales definidas la constante C se anula al restar F(b) - F(a).',
      ),
      MathStep(
        index: 2,
        shortTitle: 'Paso 2: Aplicar Regla de Barrow F(b) - F(a)',
        latexExpression:
            '\\left[$primLatex\\right]_{$aLatex}^{$bLatex} = \\left($substB\\right) - \\left($substA\\right)',
        pedagogicalNote:
            'Sustituimos primero el límite superior x = $bLatex en F(x) y restamos la sustitución del límite inferior x = $aLatex encerrada entre paréntesis.',
        warningTrick:
            'Encierra todo F(a) entre paréntesis tras el signo menos: F(b) - (F(a)), cambiando el signo a todos los términos interiores.',
      ),
      MathStep(
        index: 3,
        shortTitle: 'Paso 3: Operar valores exactos y simplificar',
        latexExpression:
            'F($bLatex) - F($aLatex) = ${fUpper.toLatex()} - ${_wrapNeg(fLower)} = ${total.toLatex()}',
        pedagogicalNote: a > b
            ? 'Como el límite inferior a = $aLatex es mayor que b = $bLatex, el resultado cambia de signo según ∫ₐᵇ = -∫_bᵃ.'
            : 'Restamos las dos fracciones exactas y simplificamos el resultado final a irreducible.',
      ),
    ];

    return CalculusAnalysisResult(
      resultPolynomial: antideriv,
      definiteValue: total,
      resolution: StepByStepResolution(
        originalInputLatex: '\\int_{$aLatex}^{$bLatex} \\left($fLatex\\right)\\,dx',
        steps: steps,
        exactResultLatex: total.toLatex(),
        decimalApproxLatex: total.toDecimalLatex(),
      ),
    );
  }

  static StepByStepResolution definiteIntegralBarrow(
    RationalPolynomial f,
    Rational a,
    Rational b,
  ) =>
      analyzeDefiniteIntegralBarrow(f, a, b).resolution;

  static String _derivativeRuleExpansionLatex(RationalPolynomial f) {
    final parts = <String>[];
    bool first = true;
    for (final deg in f.descendingDegrees) {
      final c = f.coeffOf(deg);
      if (c.isZero) continue;
      if (deg == 0) {
        parts.add(first ? '0' : ' + 0');
        first = false;
        continue;
      }
      final absC = c.abs();
      final coeffPart = absC == Rational(1) ? '' : '${absC.toLatex()} \\cdot ';
      final powPart = switch (deg) {
        1 => '1',
        2 => '2x',
        _ => '$deg x^{${deg - 1}}',
      };
      final expr = deg == 1
          ? (absC == Rational(1) ? '1' : '${absC.toLatex()} \\cdot 1')
          : '$coeffPart$powPart';
      if (first) {
        parts.add(c.isNegative ? '-$expr' : expr);
        first = false;
      } else {
        parts.add(c.isNegative ? ' - $expr' : ' + $expr');
      }
    }
    return parts.isEmpty ? '0' : parts.join();
  }

  static String _integralRuleExpansionLatex(RationalPolynomial f) {
    final parts = <String>[];
    bool first = true;
    for (final deg in f.descendingDegrees) {
      final c = f.coeffOf(deg);
      if (c.isZero) continue;
      final absC = c.abs();
      final newDeg = deg + 1;
      final expr = deg == 0
          ? '${absC.toLatex()}x'
          : (absC == Rational(1)
              ? '\\frac{x^{$newDeg}}{$newDeg}'
              : '${absC.toLatex()} \\cdot \\frac{x^{$newDeg}}{$newDeg}');
      if (first) {
        parts.add(c.isNegative ? '-$expr' : expr);
        first = false;
      } else {
        parts.add(c.isNegative ? ' - $expr' : ' + $expr');
      }
    }
    return parts.isEmpty ? '0' : parts.join();
  }

  static String _substitutionLatex(RationalPolynomial f, Rational xVal) {
    if (f.isZero) return '0';
    final parts = <String>[];
    bool first = true;
    final xWrapped = _wrapNeg(xVal);
    for (final deg in f.descendingDegrees) {
      final c = f.coeffOf(deg);
      if (c.isZero) continue;
      final absC = c.abs();
      final core = switch (deg) {
        0 => absC.toLatex(),
        1 => absC == Rational(1) ? xWrapped : '${absC.toLatex()} \\cdot $xWrapped',
        _ => absC == Rational(1)
            ? '$xWrapped^{$deg}'
            : '${absC.toLatex()} \\cdot $xWrapped^{$deg}',
      };
      if (first) {
        parts.add(c.isNegative ? '-$core' : core);
        first = false;
      } else {
        parts.add(c.isNegative ? ' - $core' : ' + $core');
      }
    }
    return parts.isEmpty ? '0' : parts.join();
  }

  static String _wrapNeg(Rational r) {
    if (r.isNegative || !r.isInteger) {
      return '\\left(${r.toLatex()}\\right)';
    }
    return r.toLatex();
  }
}

extension _RationalCompare on Rational {
  bool operator >(Rational other) => (this - other).isPositive;
}
