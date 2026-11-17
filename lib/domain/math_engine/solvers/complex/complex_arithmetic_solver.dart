import '../../core/rational.dart';
import '../../models/complex_models.dart';
import '../../models/step_resolution.dart';

class ComplexArithmeticSolver {
  static StepByStepResolution add(RationalComplex z1, RationalComplex z2) {
    final res = z1 + z2;
    final realExpr = '${z1.real.toLatex()} ${signedTail(z2.real)}';
    final imagExpr = '${z1.imag.toLatex()} ${signedTail(z2.imag)}';

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
    final realExpr = '${z1.real.toLatex()} - ${wrapNeg(z2.real)}';
    final imagExpr = '${z1.imag.toLatex()} - ${wrapNeg(z2.imag)}';

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

    final distLatex = distributiveExpandedLatex(ac, ad, bc, bd);
    final i2ReplacedLatex = afterISquaredReplacedLatex(ac, ad + bc, -bd);

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
              'Sumamos los términos reales (${ac.toLatex()} ${signedTail(-bd)}) por un lado y los imaginarios por otro.',
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

    final numDist = distributiveExpandedLatex(ac, adMinus, bc, bdMinus);
    final step2Latex =
        '\\frac{$numDist}{${wrapNeg(c)}^{2} - \\left(${d == Rational(1) ? '' : (d == Rational(-1) ? '-' : wrapNeg(d))}i\\right)^{2}} = '
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

  /// Potencias de la unidad imaginaria `i^n` con reducción cíclica mod 4.
  static StepByStepResolution powerOfI(int n) {
    if (n < 0) {
      throw const FormatException('Las potencias de i deben tener exponente no negativo.');
    }
    final q = n ~/ 4;
    final r = n % 4;

    final String remainderValLatex;
    switch (r) {
      case 0:
        remainderValLatex = '1';
        break;
      case 1:
        remainderValLatex = 'i';
        break;
      case 2:
        remainderValLatex = '-1';
        break;
      case 3:
        remainderValLatex = '-i';
        break;
      default:
        remainderValLatex = '1';
    }

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'División del exponente entre 4',
        latexExpression: '$n = 4 \\cdot $q + $r',
        pedagogicalNote:
            'Las potencias de la unidad imaginaria son cíclicas de periodo 4: i^0 = 1, i^1 = i, i^2 = -1, i^3 = -i. Dividimos el exponente entre 4 para obtener el cociente y el resto.',
      ),
      MathStep(
        index: 2,
        shortTitle: 'Reducción cíclica: i^n = (i^4)^q · i^r',
        latexExpression: 'i^{$n} = (i^4)^{$q} \\cdot i^{$r} = 1^{$q} \\cdot i^{$r} = i^{$r}',
        pedagogicalNote:
            'Como i^4 = 1, cualquier múltiplo de 4 equivale a 1. El resultado depende únicamente del resto de la división.',
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

  static String distributiveExpandedLatex(
    Rational ac,
    Rational ad,
    Rational bc,
    Rational bd,
  ) {
    final buf = StringBuffer();
    buf.write(ac.toLatex());
    buf.write(signedImagTerm(ad));
    buf.write(signedImagTerm(bc));
    buf.write(signedISquaredTerm(bd));
    return buf.toString();
  }

  static String afterISquaredReplacedLatex(
    Rational ac,
    Rational imSum,
    Rational minusBd,
  ) {
    final buf = StringBuffer();
    buf.write(ac.toLatex());
    if (!imSum.isZero) {
      buf.write(signedImagTerm(imSum));
    }
    buf.write(' ${signedTail(minusBd)}');
    return buf.toString();
  }

  static String signedImagTerm(Rational coeff) {
    final abs = coeff.abs();
    final core = abs == Rational(1) ? 'i' : '${abs.toLatex()}i';
    return coeff.isNegative ? ' - $core' : ' + $core';
  }

  static String signedISquaredTerm(Rational coeff) {
    final abs = coeff.abs();
    final core = abs == Rational(1) ? 'i^{2}' : '${abs.toLatex()}i^{2}';
    return coeff.isNegative ? ' - $core' : ' + $core';
  }

  static String wrapNeg(Rational r) {
    if (r.isNegative || !r.isInteger) {
      return '\\left(${r.toLatex()}\\right)';
    }
    return r.toLatex();
  }

  static String signedTail(Rational r) {
    if (r.isNegative) {
      return '- ${(-r).toLatex()}';
    }
    return '+ ${r.toLatex()}';
  }
}
