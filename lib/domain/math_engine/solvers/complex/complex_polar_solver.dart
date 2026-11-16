import 'dart:math' as math;
import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../radical_and_factor_solver.dart';
import '../../models/complex_models.dart';

/// Solver didáctico especializado en Forma Polar y Potencias de i
/// para 1.º de Bachillerato / PAU.
class ComplexPolarSolver {
  /// Análisis completo a Forma Polar `r_α` con deducción de cuadrante.
  static ComplexResult analyzeToPolar(RationalComplex z) {
    final a = z.real;
    final b = z.imaginary;

    if (a.isZero && b.isZero) {
      final steps = [
        MathStep(
          index: 1,
          shortTitle: 'Número complejo nulo',
          latexExpression: 'z = 0 + 0i \\implies r = 0, \\; \\alpha \\text{ indeterminado}',
          pedagogicalNote:
              'El origen de coordenadas tiene módulo 0 y su argumento no está definido.',
        ),
      ];
      return ComplexResult(
        binomial: z,
        polarModulusLatex: '0',
        polarAngleDegrees: 0,
        resolution: StepByStepResolution(
          originalInputLatex: '0',
          steps: steps,
          exactResultLatex: '0',
          decimalApproxLatex: '0',
        ),
      );
    }

    final steps = <MathStep>[];
    int stepIdx = 1;

    // 1. Cálculo del módulo r = sqrt(a^2 + b^2)
    final a2 = a * a;
    final b2 = b * b;
    final sum2 = a2 + b2;

    final String rLatex;
    final double rDouble;

    if (sum2.denominator == 1) {
      final radInt = sum2.numerator;
      final radRes = RadicalAndFactorSolver.simplifySquareRoot(radInt);
      rLatex = radRes.exactResultLatex;
      rDouble = math.sqrt(radInt.toDouble());
    } else {
      final numRad = RadicalAndFactorSolver.simplifySquareRoot(sum2.numerator);
      final denRad = RadicalAndFactorSolver.simplifySquareRoot(sum2.denominator);
      rLatex = '\\frac{${numRad.exactResultLatex}}{${denRad.exactResultLatex}}';
      rDouble = math.sqrt(sum2.toDouble());
    }

    steps.add(
      MathStep(
        index: stepIdx++,
        shortTitle: 'Paso 1: Cálculo del módulo r',
        latexExpression:
            'r = \\sqrt{a^2 + b^2} = \\sqrt{${_wrapNeg(a)}^2 + ${_wrapNeg(b)}^2} = \\sqrt{${sum2.toLatex()}} = $rLatex',
        pedagogicalNote:
            'El módulo r representa la distancia euclídea del afijo (a, b) al origen de coordenadas en el plano de Argand.',
      ),
    );

    // 2. Cálculo del argumento α con análisis de cuadrante
    final argInfo = _computeQuadrantArgument(a, b);

    steps.add(
      MathStep(
        index: stepIdx++,
        shortTitle: 'Paso 2: Argumento α (${argInfo.quadrantDesc})',
        latexExpression: argInfo.formulaLatex,
        pedagogicalNote:
            'Identificamos el cuadrante del afijo (${a.toLatex()}, ${b.toLatex()}) en el plano complejo y sumamos el desfase si es necesario.',
        warningTrick: argInfo.warning,
      ),
    );

    final angleLatex = argInfo.exactDeg != null
        ? '${argInfo.exactDeg}^{\\circ}'
        : '${_formatLatexDec(argInfo.deg, decimals: 2)}^{\\circ}';
    final polarLatex = '${rLatex}_{$angleLatex}';

    final decR = _formatLatexDec(rDouble, decimals: 4);
    final decDeg = _formatLatexDec(argInfo.deg, decimals: 2);

    steps.add(
      MathStep(
        index: stepIdx++,
        shortTitle: 'Paso 3: Expresión en forma polar y trigonométrica',
        latexExpression:
            'z = $polarLatex = $rLatex\\left(\\cos\\left($angleLatex\\right) + i\\sin\\left($angleLatex\\right)\\right)',
        pedagogicalNote:
            'Escribimos el número complejo en forma polar r_α y en su forma trigonométrica equivalente.',
      ),
    );

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

  /// Potencias de la unidad imaginaria `i^n` con reducción cíclica mod 4.
  static StepByStepResolution powerOfI(int n) {
    if (n < 0) {
      throw const FormatException('Las potencias de i deben tener exponente no negativo.');
    }
    final q = n ~/ 4;
    final r = n % 4;

    final String remainderValLatex = switch (r) {
      0 => '1',
      1 => 'i',
      2 => '-1',
      3 => '-i',
      _ => '1',
    };

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'División del exponente entre 4',
        latexExpression: '$n = 4 \\cdot $q + $r',
        pedagogicalNote:
            'Las potencias de la unidad imaginaria son ciclicas de periodo 4: i^0 = 1, i^1 = i, i^2 = -1, i^3 = -i. Dividimos el exponente entre 4 para obtener el cociente y el resto.',
      ),
      MathStep(
        index: 2,
        shortTitle: 'Reducción cíclica: i^n = (i^4)^q · i^r',
        latexExpression: 'i^{$n} = (i^4)^{$q} \\cdot i^{$r} = 1^{$q} \\cdot i^{$r} = i^{$r}',
        pedagogicalNote:
            'Como i^4 = 1, cualquier multiplo de 4 equivale a 1. El resultado depende unicamente del resto de la division.',
      ),
      MathStep(
        index: 3,
        shortTitle: 'Resultado exacto',
        latexExpression: 'i^{$n} = $remainderValLatex',
        pedagogicalNote:
            'Sustituimos el valor del resto: i^{$r} = $remainderValLatex.',
      ),
    ];

    return StepByStepResolution(
      originalInputLatex: 'i^{$n}',
      steps: steps,
      exactResultLatex: remainderValLatex,
      decimalApproxLatex: remainderValLatex,
    );
  }

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

  static String _wrapNeg(Rational r) {
    if (r.isNegative || !r.isInteger) {
      return '\\left(${r.toLatex()}\\right)';
    }
    return r.toLatex();
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
