import 'dart:math' as math;

import '../core/algebraic_latex_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';

/// Operaciones disponibles en el Modo 13 (Números Complejos: Binómica ⬄ Polar).
enum ComplexOperation {
  add('z₁ + z₂'),
  subtract('z₁ - z₂'),
  multiply('z₁ · z₂'),
  divide('z₁ / z₂'),
  toPolar('a+bi → r_α'),
  fromPolar('r_α → a+bi');

  final String shortLabel;
  const ComplexOperation(this.shortLabel);

  bool get needsSecondComplex =>
      this == ComplexOperation.add ||
      this == ComplexOperation.subtract ||
      this == ComplexOperation.multiply ||
      this == ComplexOperation.divide;
}

/// Número complejo exacto en forma binómica `a + bi` con coeficientes [Rational].
class RationalComplex {
  final Rational real;
  final Rational imag;

  const RationalComplex(this.real, this.imag);

  factory RationalComplex.fromInts(int real, int imag) =>
      RationalComplex(Rational(real), Rational(imag));

  bool get isZero => real.isZero && imag.isZero;

  RationalComplex conjugate() => RationalComplex(real, -imag);

  Rational normSquared() => real * real + imag * imag;

  RationalComplex operator +(RationalComplex other) =>
      RationalComplex(real + other.real, imag + other.imag);

  RationalComplex operator -(RationalComplex other) =>
      RationalComplex(real - other.real, imag - other.imag);

  RationalComplex operator *(RationalComplex other) => RationalComplex(
        real * other.real - imag * other.imag,
        real * other.imag + imag * other.real,
      );

  RationalComplex operator /(RationalComplex other) {
    final denom = other.normSquared();
    if (denom.isZero) {
      throw const FormatException('No se puede dividir entre 0 + 0i.');
    }
    final numProd = this * other.conjugate();
    return RationalComplex(numProd.real / denom, numProd.imag / denom);
  }

  /// Representación humana en LaTeX sin `0i`, `1i` ni signos dobles `+ -`.
  String toLatex() {
    if (real.isZero && imag.isZero) return '0';
    final imagPart = _formatImaginaryCore(imag.abs());
    if (real.isZero) {
      return imag.isNegative ? '-$imagPart' : imagPart;
    }
    if (imag.isZero) {
      return real.toLatex();
    }
    final sign = imag.isNegative ? ' - ' : ' + ';
    return '${real.toLatex()}$sign$imagPart';
  }

  String toDecimalLatex() {
    if (real.isZero && imag.isZero) return '0';
    final absIm = imag.abs();
    final imStr = absIm == Rational(1) ? 'i' : '${absIm.toDecimalLatex()}i';
    if (real.isZero) {
      return imag.isNegative ? '-$imStr' : imStr;
    }
    if (imag.isZero) return real.toDecimalLatex();
    final sign = imag.isNegative ? ' - ' : ' + ';
    return '${real.toDecimalLatex()}$sign$imStr';
  }

  static String _formatImaginaryCore(Rational absCoeff) {
    if (absCoeff == Rational(1)) return 'i';
    return '${absCoeff.toLatex()}i';
  }

  @override
  bool operator ==(Object other) =>
      other is RationalComplex && other.real == real && other.imag == imag;

  @override
  int get hashCode => Object.hash(real, imag);
}

/// Resultado estructurado para operaciones con números complejos.
class ComplexResult {
  final RationalComplex? binomial;
  final String? polarModulusLatex;
  final double? polarAngleDegrees;
  final StepByStepResolution resolution;

  const ComplexResult({
    this.binomial,
    this.polarModulusLatex,
    this.polarAngleDegrees,
    required this.resolution,
  });
}

/// Solver paso a paso de Números Complejos (Binómica y Polar) para 1.º de Bachillerato.
class ComplexSolver {
  static StepByStepResolution solve({
    required ComplexOperation operation,
    required RationalComplex z1,
    RationalComplex? z2,
    Rational? polarModulus,
    double? polarAngleDegrees,
  }) {
    final second = z2 ?? RationalComplex.fromInts(1, 0);
    return switch (operation) {
      ComplexOperation.add => add(z1, second),
      ComplexOperation.subtract => subtract(z1, second),
      ComplexOperation.multiply => multiply(z1, second),
      ComplexOperation.divide => divide(z1, second),
      ComplexOperation.toPolar => toPolar(z1),
      ComplexOperation.fromPolar => fromPolar(
          modulus: polarModulus ?? Rational(1),
          angleDegrees: polarAngleDegrees ?? 0,
        ),
    };
  }

  static ComplexResult analyzeOperation({
    required ComplexOperation operation,
    required RationalComplex z1,
    RationalComplex? z2,
  }) {
    final second = z2 ?? RationalComplex.fromInts(1, 0);
    return switch (operation) {
      ComplexOperation.add =>
        ComplexResult(binomial: z1 + second, resolution: add(z1, second)),
      ComplexOperation.subtract =>
        ComplexResult(binomial: z1 - second, resolution: subtract(z1, second)),
      ComplexOperation.multiply =>
        ComplexResult(binomial: z1 * second, resolution: multiply(z1, second)),
      ComplexOperation.divide =>
        ComplexResult(binomial: z1 / second, resolution: divide(z1, second)),
      ComplexOperation.toPolar => analyzeToPolar(z1),
      ComplexOperation.fromPolar =>
        ComplexResult(resolution: fromPolar(modulus: z1.real, angleDegrees: z1.imag.toDouble())),
    };
  }

  static StepByStepResolution add(RationalComplex z1, RationalComplex z2) {
    final res = z1 + z2;
    final realExpr = '${z1.real.toLatex()} ${_signedTail(z2.real)}';
    final imagExpr = '${z1.imag.toLatex()} ${_signedTail(z2.imag)}';

    return StepByStepResolution(
      originalInputLatex: '\\left(${z1.toLatex()}\\right) + \\left(${z2.toLatex()}\\right)',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Paso 1: Agrupar parte real y parte imaginaria',
          latexExpression:
              '\\left($realExpr\\right) + \\left($imagExpr\\right)i = ${res.toLatex()}',
          pedagogicalNote:
              'Sumamos las partes reales entre sí y las partes imaginarias entre sí por separado.',
        ),
      ],
      exactResultLatex: res.toLatex(),
      decimalApproxLatex: res.toDecimalLatex(),
    );
  }

  static StepByStepResolution subtract(RationalComplex z1, RationalComplex z2) {
    final res = z1 - z2;
    final realExpr = '${z1.real.toLatex()} - ${_wrapNeg(z2.real)}';
    final imagExpr = '${z1.imag.toLatex()} - ${_wrapNeg(z2.imag)}';

    return StepByStepResolution(
      originalInputLatex: '\\left(${z1.toLatex()}\\right) - \\left(${z2.toLatex()}\\right)',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Paso 1: Restar partes reales e imaginarias',
          latexExpression:
              '\\left($realExpr\\right) + \\left($imagExpr\\right)i = ${res.toLatex()}',
          pedagogicalNote:
              'El signo menos delante de z₂ cambia el signo tanto de su parte real como de su parte imaginaria.',
          warningTrick:
              'El signo menos delante del paréntesis afecta a ambos términos: -(c + di) = -c - di.',
        ),
      ],
      exactResultLatex: res.toLatex(),
      decimalApproxLatex: res.toDecimalLatex(),
    );
  }

  /// Multiplicación `(a + bi)(c + di)` mostrando la distributiva y el reemplazo explícito `i² = -1`.
  static StepByStepResolution multiply(RationalComplex z1, RationalComplex z2) {
    final a = z1.real;
    final b = z1.imag;
    final c = z2.real;
    final d = z2.imag;

    final ac = a * c;
    final ad = a * d;
    final bc = b * c;
    final bd = b * d;
    final res = z1 * z2;

    final distLatex = _distributiveExpandedLatex(ac, ad, bc, bd);
    final i2ReplacedLatex = _afterISquaredReplacedLatex(ac, ad + bc, -bd);

    return StepByStepResolution(
      originalInputLatex: '\\left(${z1.toLatex()}\\right) \\cdot \\left(${z2.toLatex()}\\right)',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Paso 1: Aplicar propiedad distributiva',
          latexExpression:
              '\\left(${z1.toLatex()}\\right)\\left(${z2.toLatex()}\\right) = $distLatex',
          pedagogicalNote:
              'Multiplicamos cada término del primer número complejo por cada término del segundo (todos contra todos).',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Paso 2: Sustituir i² = -1',
          latexExpression:
              '$distLatex = $i2ReplacedLatex',
          pedagogicalNote:
              'Por definición de la unidad imaginaria, i² = -1, lo que convierte el término en i² en un número real de signo contrario.',
          warningTrick:
              'Recuerda que i² = -1, por lo que el término bd·i² cambia de signo y pasa a ser parte real: -bd.',
        ),
        MathStep(
          index: 3,
          shortTitle: 'Paso 3: Agrupar parte real e imaginaria',
          latexExpression: res.toLatex(),
          pedagogicalNote:
              'Sumamos los términos reales (${ac.toLatex()} ${_signedTail(-bd)}) por un lado y los imaginarios por otro.',
        ),
      ],
      exactResultLatex: res.toLatex(),
      decimalApproxLatex: res.toDecimalLatex(),
    );
  }

  /// División `(a + bi) / (c + di)` multiplicando numerador y denominador por el conjugado `(c - di)`.
  static StepByStepResolution divide(RationalComplex z1, RationalComplex z2) {
    if (z2.isZero) {
      throw const FormatException('No se puede dividir entre 0 + 0i.');
    }
    final a = z1.real;
    final b = z1.imag;
    final c = z2.real;
    final d = z2.imag;

    final conj = z2.conjugate();
    final denomSq = z2.normSquared(); // c^2 + d^2

    final ac = a * c;
    final adMinus = a * (-d);
    final bc = b * c;
    final bdMinus = b * (-d);
    final numProd = z1 * conj;
    final finalComplex = z1 / z2;

    final step1Latex =
        '\\frac{${z1.toLatex()}}{${z2.toLatex()}} = '
        '\\frac{\\left(${z1.toLatex()}\\right)\\left(${conj.toLatex()}\\right)}'
        '{\\left(${z2.toLatex()}\\right)\\left(${conj.toLatex()}\\right)}';

    final numDist = _distributiveExpandedLatex(ac, adMinus, bc, bdMinus);
    final step2Latex =
        '\\frac{$numDist}{${_wrapNeg(c)}^{2} - \\left(${_wrapNeg(d)}i\\right)^{2}} = '
        '\\frac{${numProd.toLatex()}}{${(c * c).toLatex()} + ${(d * d).toLatex()}} = '
        '\\frac{${numProd.toLatex()}}{${denomSq.toLatex()}}';

    final rawRealFrac = numProd.real.toLatex();
    final rawImagFrac = numProd.imag.toLatex();
    final step3Sep = denomSq == Rational(1)
        ? finalComplex.toLatex()
        : '\\frac{$rawRealFrac}{${denomSq.toLatex()}} + \\frac{$rawImagFrac}{${denomSq.toLatex()}}i = ${finalComplex.toLatex()}';

    return StepByStepResolution(
      originalInputLatex: '\\frac{${z1.toLatex()}}{${z2.toLatex()}}',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Paso 1: Multiplicar por el conjugado (${conj.toLatex()})',
          latexExpression: step1Latex,
          pedagogicalNote:
              'Multiplicamos numerador y denominador por el conjugado del denominador (${conj.toLatex()}) para eliminar la i de abajo.',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Paso 2: Suma por diferencia y sustitución i² = -1',
          latexExpression: step2Latex,
          pedagogicalNote:
              'En el denominador aplicamos (c+di)(c-di) = c² - d²i² = c² + d² y en el numerador sustituimos i² = -1.',
          warningTrick:
              'En el denominador, como i² = -1, (c+di)(c-di) equivale siempre a la suma c² + d².',
        ),
        MathStep(
          index: 3,
          shortTitle: 'Paso 3: Separar real e imaginaria y simplificar',
          latexExpression: step3Sep,
          pedagogicalNote:
              'Dividimos tanto la parte real como la imaginaria entre ${denomSq.toLatex()} simplificando a fracciones irreducibles.',
        ),
      ],
      exactResultLatex: finalComplex.toLatex(),
      decimalApproxLatex: finalComplex.toDecimalLatex(),
    );
  }

  /// Paso de forma binómica `a + bi` a forma polar `r_α` analizando cuadrante.
  static ComplexResult analyzeToPolar(RationalComplex z) {
    final a = z.real;
    final b = z.imag;
    final modSq = z.normSquared();
    final rLatex = AlgebraicLatexFormatter.rationalSqrtLatex(modSq);
    final rDouble = math.sqrt(modSq.toDouble());

    if (z.isZero) {
      final res = StepByStepResolution(
        originalInputLatex: z.toLatex(),
        steps: const [
          MathStep(
            index: 1,
            shortTitle: 'Origen (0 + 0i)',
            latexExpression: 'r = \\sqrt{0^{2} + 0^{2}} = 0',
            pedagogicalNote:
                'El número complejo 0 + 0i tiene módulo 0 y su argumento no está determinado.',
          ),
        ],
        exactResultLatex: '0_{0^{\\circ}}',
        decimalApproxLatex: '0',
      );
      return ComplexResult(
        binomial: z,
        polarModulusLatex: '0',
        polarAngleDegrees: 0,
        resolution: res,
      );
    }

    final step1Latex =
        'r = \\left|z\\right| = \\sqrt{${_wrapNeg(a)}^{2} + ${_wrapNeg(b)}^{2}} = \\sqrt{${modSq.toLatex()}} = $rLatex';

    final ({double deg, int? exactDeg, String quadrantDesc, String formulaLatex, String? warning})
        argInfo = _computeQuadrantArgument(a, b);

    final angleLabelLatex = argInfo.exactDeg != null
        ? '${argInfo.exactDeg}^{\\circ}'
        : '${_formatLatexDec(argInfo.deg, decimals: 2)}^{\\circ}';

    final wrappedR = (rLatex.contains(r'\sqrt') || rLatex.contains(r'\frac'))
        ? '\\left($rLatex\\right)'
        : rLatex;
    final polarLatex = '${wrappedR}_{$angleLabelLatex}';
    final trigLatex =
        '$rLatex \\cdot \\left(\\cos\\left($angleLabelLatex\\right) + i\\sin\\left($angleLabelLatex\\right)\\right)';

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Paso 1: Calcular el módulo r = √(a² + b²)',
        latexExpression: step1Latex,
        pedagogicalNote:
            'El módulo r es la distancia desde el origen hasta el afijo (${a.toLatex()}, ${b.toLatex()}) en el plano complejo.',
      ),
      MathStep(
        index: 2,
        shortTitle: 'Paso 2: Argumento α (${argInfo.quadrantDesc})',
        latexExpression: argInfo.formulaLatex,
        pedagogicalNote:
            'Representamos (${a.toLatex()}, ${b.toLatex()}) en el plano complejo para ajustar el cuadrante correcto de α ∈ [0°, 360°).',
        warningTrick: argInfo.warning,
      ),
      MathStep(
        index: 3,
        shortTitle: 'Paso 3: Forma polar y trigonométrica',
        latexExpression: '$polarLatex = $trigLatex',
        pedagogicalNote:
            'Escribimos el complejo como r_α (forma polar) junto a su expresión trigonométrica equivalente.',
      ),
    ];

    final decR = _formatLatexDec(rDouble, decimals: 4);
    final decDeg = _formatLatexDec(argInfo.deg, decimals: 2);

    return ComplexResult(
      binomial: z,
      polarModulusLatex: rLatex,
      polarAngleDegrees: argInfo.deg,
      resolution: StepByStepResolution(
        originalInputLatex: z.toLatex(),
        steps: steps,
        exactResultLatex: polarLatex,
        decimalApproxLatex: '${decR}_$decDeg^{\\circ}',
      ),
    );
  }

  static StepByStepResolution toPolar(RationalComplex z) =>
      analyzeToPolar(z).resolution;

  /// Conversión inversa de Forma Polar `r_α` a Forma Binómica `a + bi`.
  static StepByStepResolution fromPolar({
    required Rational modulus,
    required double angleDegrees,
  }) {
    if (modulus.isNegative) {
      throw const FormatException('El módulo r de un complejo polar debe ser >= 0.');
    }
    final normAngle = ((angleDegrees % 360) + 360) % 360;
    final angleInt = (normAngle - normAngle.roundToDouble()).abs() < 1e-6
        ? normAngle.round()
        : null;
    final rad = normAngle * math.pi / 180.0;

    final angleLatex = angleInt != null
        ? '$angleInt^{\\circ}'
        : '${_formatLatexDec(normAngle, decimals: 2)}^{\\circ}';

    // Valores exactos para ángulos múltiples de 30° o 45°
    final exactTrig = angleInt != null ? _notableCosSinLatex(angleInt) : null;

    final String exactLatex;
    final String step2Latex;
    if (exactTrig != null && exactTrig.rationalCos != null && exactTrig.rationalSin != null) {
      final res = RationalComplex(
        modulus * exactTrig.rationalCos!,
        modulus * exactTrig.rationalSin!,
      );
      exactLatex = res.toLatex();
      step2Latex = 'z = ${modulus.toLatex()}\\left(${exactTrig.cosLatex} + (${exactTrig.sinLatex})i\\right) = $exactLatex';
    } else if (exactTrig != null) {
      final aStr = _multiplyRationalByRadicalExpr(modulus, exactTrig.cosRadCoeff, exactTrig.cosRad);
      final bStr = _multiplyRationalByRadicalExpr(modulus, exactTrig.sinRadCoeff, exactTrig.sinRad);
      exactLatex = bStr.startsWith('-') ? '$aStr - ${bStr.substring(1)}i' : '$aStr + ${bStr}i';
      step2Latex = 'z = ${modulus.toLatex()}\\left(${exactTrig.cosLatex} + (${exactTrig.sinLatex})i\\right) = $exactLatex';
    } else {
      final rD = modulus.toDouble();
      final aDec = rD * math.cos(rad);
      final bDec = rD * math.sin(rad);
      final bSign = bDec < 0 ? '-' : '+';
      exactLatex = '${_formatLatexDec(aDec, decimals: 4)} $bSign ${_formatLatexDec(bDec.abs(), decimals: 4)}i';
      step2Latex = 'z = ${modulus.toLatex()} \\cdot \\cos($angleLatex) + ${modulus.toLatex()} \\cdot \\sin($angleLatex)i = $exactLatex';
    }

    final rD = modulus.toDouble();
    final aD = rD * math.cos(rad);
    final bD = rD * math.sin(rad);
    final decStr = '${_formatDecimalStr(aD, 4)} ${bD < 0 ? '-' : '+'} ${_formatDecimalStr(bD.abs(), 4)}i';

    return StepByStepResolution(
      originalInputLatex: '${modulus.toLatex()}_{$angleLatex}',
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Paso 1: Pasar a forma trigonométrica',
          latexExpression:
              'z = ${modulus.toLatex()}\\left(\\cos\\left($angleLatex\\right) + i\\sin\\left($angleLatex\\right)\\right)',
          pedagogicalNote:
              'Aplicamos las relaciones a = r · cos(α) y b = r · sen(α) desde la forma trigonométrica.',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Paso 2: Obtener forma binómica a + bi',
          latexExpression: step2Latex,
          pedagogicalNote:
              'Calculamos las razones trigonométricas de $angleLatex y multiplicamos por el módulo r = ${modulus.toLatex()}.',
        ),
      ],
      exactResultLatex: exactLatex,
      decimalApproxLatex: decStr,
    );
  }

  static ({
    double deg,
    int? exactDeg,
    String quadrantDesc,
    String formulaLatex,
    String? warning,
  }) _computeQuadrantArgument(Rational a, Rational b) {
    if (b.isZero) {
      if (a.isPositive) {
        return (
          deg: 0,
          exactDeg: 0,
          quadrantDesc: 'Semieje real positivo',
          formulaLatex: '\\alpha = 0^{\\circ}',
          warning: null,
        );
      } else {
        return (
          deg: 180,
          exactDeg: 180,
          quadrantDesc: 'Semieje real negativo',
          formulaLatex: '\\alpha = 180^{\\circ}',
          warning: 'Un número real negativo tiene argumento 180° (o π rad), no 0°.',
        );
      }
    }
    if (a.isZero) {
      if (b.isPositive) {
        return (
          deg: 90,
          exactDeg: 90,
          quadrantDesc: 'Semieje imaginario positivo',
          formulaLatex: '\\alpha = 90^{\\circ}',
          warning: null,
        );
      } else {
        return (
          deg: 270,
          exactDeg: 270,
          quadrantDesc: 'Semieje imaginario negativo',
          formulaLatex: '\\alpha = 270^{\\circ}',
          warning: 'Un imaginario puro negativo (-bi) apunta hacia abajo: su ángulo positivo es 270°.',
        );
      }
    }

    final ratio = b / a;
    final rawRad = math.atan(ratio.toDouble());
    final rawDeg = rawRad * 180.0 / math.pi;
    final exactBaseDeg = _notableAtanDeg(ratio);

    if (a.isPositive && b.isPositive) {
      // I Cuadrante
      final d = exactBaseDeg?.toDouble() ?? rawDeg;
      final aStr = exactBaseDeg != null ? '$exactBaseDeg^{\\circ}' : '${_formatLatexDec(d, decimals: 2)}^{\\circ}';
      return (
        deg: d,
        exactDeg: exactBaseDeg,
        quadrantDesc: 'I Cuadrante',
        formulaLatex: '\\alpha = \\arctan\\left(${ratio.toLatex()}\\right) = $aStr',
        warning: null,
      );
    }

    if (a.isNegative && b.isPositive) {
      // II Cuadrante (ratio < 0, rawDeg in (-90, 0))
      final d = exactBaseDeg != null ? (180 + exactBaseDeg).toDouble() : (180.0 + rawDeg);
      final exactD = exactBaseDeg != null ? 180 + exactBaseDeg : null;
      final aStr = exactD != null ? '$exactD^{\\circ}' : '${_formatLatexDec(d, decimals: 2)}^{\\circ}';
      return (
        deg: d,
        exactDeg: exactD,
        quadrantDesc: 'II Cuadrante',
        formulaLatex: '\\alpha = 180^{\\circ} + \\arctan\\left(${ratio.toLatex()}\\right) = $aStr',
        warning:
            'Como a < 0 y b > 0, el afijo está en el II Cuadrante: sumamos 180° al ángulo negativo de arctan.',
      );
    }

    if (a.isNegative && b.isNegative) {
      // III Cuadrante (ratio > 0, rawDeg in (0, 90))
      final d = exactBaseDeg != null ? (180 + exactBaseDeg).toDouble() : (180.0 + rawDeg);
      final exactD = exactBaseDeg != null ? 180 + exactBaseDeg : null;
      final aStr = exactD != null ? '$exactD^{\\circ}' : '${_formatLatexDec(d, decimals: 2)}^{\\circ}';
      return (
        deg: d,
        exactDeg: exactD,
        quadrantDesc: 'III Cuadrante',
        formulaLatex: '\\alpha = 180^{\\circ} + \\arctan\\left(${ratio.toLatex()}\\right) = $aStr',
        warning:
            'Al ser a < 0 y b < 0, el cociente b/a es positivo pero el afijo está en el III Cuadrante: sumamos 180°.',
      );
    }

    // IV Cuadrante (a > 0, b < 0 -> rawDeg in (-90, 0))
    final d = exactBaseDeg != null ? (360 + exactBaseDeg).toDouble() : (360.0 + rawDeg);
    final exactD = exactBaseDeg != null ? 360 + exactBaseDeg : null;
    final aStr = exactD != null ? '$exactD^{\\circ}' : '${_formatLatexDec(d, decimals: 2)}^{\\circ}';
    return (
      deg: d,
      exactDeg: exactD,
      quadrantDesc: 'IV Cuadrante',
      formulaLatex: '\\alpha = 360^{\\circ} + \\arctan\\left(${ratio.toLatex()}\\right) = $aStr',
      warning:
          'Al estar en el IV Cuadrante (a > 0, b < 0), el ángulo estándar positivo se obtiene sumando 360°.',
    );
  }

  static int? _notableAtanDeg(Rational ratio) {
    if (ratio == Rational(1)) return 45;
    if (ratio == Rational(-1)) return -45;
    return null;
  }

  static ({
    Rational? rationalCos,
    Rational? rationalSin,
    String cosLatex,
    String sinLatex,
    Rational cosRadCoeff,
    int cosRad,
    Rational sinRadCoeff,
    int sinRad,
  })? _notableCosSinLatex(int deg) {
    switch (deg % 360) {
      case 0:
        return (
          rationalCos: Rational(1),
          rationalSin: Rational(0),
          cosLatex: '1',
          sinLatex: '0',
          cosRadCoeff: Rational(1),
          cosRad: 1,
          sinRadCoeff: Rational(0),
          sinRad: 1,
        );
      case 90:
        return (
          rationalCos: Rational(0),
          rationalSin: Rational(1),
          cosLatex: '0',
          sinLatex: '1',
          cosRadCoeff: Rational(0),
          cosRad: 1,
          sinRadCoeff: Rational(1),
          sinRad: 1,
        );
      case 180:
        return (
          rationalCos: Rational(-1),
          rationalSin: Rational(0),
          cosLatex: '-1',
          sinLatex: '0',
          cosRadCoeff: Rational(-1),
          cosRad: 1,
          sinRadCoeff: Rational(0),
          sinRad: 1,
        );
      case 270:
        return (
          rationalCos: Rational(0),
          rationalSin: Rational(-1),
          cosLatex: '0',
          sinLatex: '-1',
          cosRadCoeff: Rational(0),
          cosRad: 1,
          sinRadCoeff: Rational(-1),
          sinRad: 1,
        );
      case 45:
        return (
          rationalCos: null,
          rationalSin: null,
          cosLatex: r'\frac{\sqrt{2}}{2}',
          sinLatex: r'\frac{\sqrt{2}}{2}',
          cosRadCoeff: Rational(1, 2),
          cosRad: 2,
          sinRadCoeff: Rational(1, 2),
          sinRad: 2,
        );
      case 30:
        return (
          rationalCos: null,
          rationalSin: Rational(1, 2),
          cosLatex: r'\frac{\sqrt{3}}{2}',
          sinLatex: r'\frac{1}{2}',
          cosRadCoeff: Rational(1, 2),
          cosRad: 3,
          sinRadCoeff: Rational(1, 2),
          sinRad: 1,
        );
      case 60:
        return (
          rationalCos: Rational(1, 2),
          rationalSin: null,
          cosLatex: r'\frac{1}{2}',
          sinLatex: r'\frac{\sqrt{3}}{2}',
          cosRadCoeff: Rational(1, 2),
          cosRad: 1,
          sinRadCoeff: Rational(1, 2),
          sinRad: 3,
        );
      default:
        return null;
    }
  }

  static String _multiplyRationalByRadicalExpr(Rational m, Rational coeff, int rad) {
    final prod = m * coeff;
    if (prod.isZero) return '0';
    if (rad == 1) return prod.toLatex();
    final absP = prod.abs();
    final sign = prod.isNegative ? '-' : '';
    if (absP == Rational(1)) return '$sign\\sqrt{$rad}';
    if (absP.denominator == 1) return '$sign${absP.numerator}\\sqrt{$rad}';
    final numStr = absP.numerator == 1 ? '' : '${absP.numerator}';
    return '$sign\\frac{$numStr\\sqrt{$rad}}{${absP.denominator}}';
  }

  static String _distributiveExpandedLatex(
    Rational ac,
    Rational ad,
    Rational bc,
    Rational bd,
  ) {
    final buf = StringBuffer();
    buf.write(ac.toLatex());
    buf.write(_signedImagTerm(ad));
    buf.write(_signedImagTerm(bc));
    buf.write(_signedISquaredTerm(bd));
    return buf.toString();
  }

  static String _afterISquaredReplacedLatex(
    Rational ac,
    Rational imSum,
    Rational minusBd,
  ) {
    final buf = StringBuffer();
    buf.write(ac.toLatex());
    if (!imSum.isZero) {
      buf.write(_signedImagTerm(imSum));
    }
    buf.write(' ${_signedTail(minusBd)}');
    return buf.toString();
  }

  static String _signedImagTerm(Rational coeff) {
    final abs = coeff.abs();
    final core = abs == Rational(1) ? 'i' : '${abs.toLatex()}i';
    return coeff.isNegative ? ' - $core' : ' + $core';
  }

  static String _signedISquaredTerm(Rational coeff) {
    final abs = coeff.abs();
    final core = abs == Rational(1) ? 'i^{2}' : '${abs.toLatex()}i^{2}';
    return coeff.isNegative ? ' - $core' : ' + $core';
  }

  static String _wrapNeg(Rational r) {
    if (r.isNegative || !r.isInteger) {
      return '\\left(${r.toLatex()}\\right)';
    }
    return r.toLatex();
  }

  static String _signedTail(Rational r) {
    if (r.isNegative) {
      return '- ${(-r).toLatex()}';
    }
    return '+ ${r.toLatex()}';
  }

  static String _formatLatexDec(double val, {int decimals = 2}) {
    final s = val
        .toStringAsFixed(decimals)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return s.replaceAll('.', '{,}');
  }

  static String _formatDecimalStr(double val, int decimals) {
    final s = val
        .toStringAsFixed(decimals)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return s.replaceAll('.', ',');
  }
}
