import '../core/rational.dart';
import '../models/calculus_models.dart';
import '../models/step_resolution.dart';
import 'symbolic_derivative_solver.dart';
import 'symbolic_integral_solver.dart';

export '../models/calculus_models.dart';

/// Solver paso a paso de Derivadas, Recta Tangente e Integrales por Regla de Barrow (1.º y 2.º Bachillerato).
class CalculusSolver {
  /// `y = mx + n` en decimales, sin `1x`, `-1x` ni `+ -`.
  static String _tangentDecimalLatex(Rational m, Rational n) {
    final nPart = n.isZero
        ? ''
        : (n.isNegative ? '- ${(-n).toDecimalLatex()}' : '+ ${n.toDecimalLatex()}');
    if (m.isZero) {
      return n.isZero ? 'y = 0' : 'y = ${n.toDecimalLatex()}';
    }
    final mPart = m == Rational(1)
        ? 'x'
        : (m == Rational(-1) ? '-x' : '${m.toDecimalLatex()}x');
    return 'y = $mPart $nPart'.trim();
  }

  static StepByStepResolution solve({
    required CalculusOperation operation,
    required String expressionRaw,
    Rational? tangentX0,
    Rational? integralLowerA,
    Rational? integralUpperB,
  }) {
    RationalPolynomial? poly;
    try {
      poly = RationalPolynomial.parseExpression(expressionRaw);
    } catch (_) {
      poly = null;
    }
    // Potencias altas de un parentesis: mejor sustitucion/cadena que expandir.
    final isIntegral = operation == CalculusOperation.indefiniteIntegral ||
        operation == CalculusOperation.definiteIntegral;
    if (isIntegral && RegExp(r'\)\^\{?([3-9]|\d\d)').hasMatch(expressionRaw)) {
      poly = null;
    }
    if (poly == null) {
      // No es un polinomio: calculo simbolico sobre el AST completo.
      return switch (operation) {
        CalculusOperation.derivative =>
          SymbolicDerivativeSolver.derivative(expressionRaw),
        CalculusOperation.tangentLine =>
          SymbolicDerivativeSolver.tangentLine(expressionRaw, tangentX0 ?? Rational(0)),
        CalculusOperation.indefiniteIntegral =>
          SymbolicIntegralSolver.indefinite(expressionRaw),
        CalculusOperation.definiteIntegral => SymbolicIntegralSolver.definite(
            expressionRaw,
            integralLowerA ?? Rational(0),
            integralUpperB ?? Rational(1),
          ),
      };
    }
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
      decimalApproxLatex: _tangentDecimalLatex(m, n),
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
