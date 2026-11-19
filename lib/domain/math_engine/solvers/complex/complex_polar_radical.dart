import 'dart:math' as math;

import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../radical_and_factor_solver.dart';

/// Parte real o imaginaria con radical: `k·√n` (n = 1 es un racional `k`).
class RadicalPart {
  final Rational k;
  final int n;
  const RadicalPart(this.k, [this.n = 1]);

  bool get isZero => k.isZero;
  double get value => k.toDouble() * math.sqrt(n.toDouble());

  /// `√3`, `-2\sqrt{3}`, `1/2`...
  String get latex {
    if (n == 1) return k.toLatex();
    final root = '\\sqrt{$n}';
    if (k == Rational(1)) return root;
    if (k == Rational(-1)) return '-$root';
    return '${k.toLatex()}$root';
  }

  /// Cuadrado como racional: `k^2 · n`.
  Rational get squared => k * k * Rational(n);

  /// Texto entre parentesis si es negativo.
  String get wrapped => k.isNegative ? '\\left($latex\\right)' : latex;

  /// `-2√3`, `√3`, `3/4` desde el texto de una celda (`null` si no es valido).
  static RadicalPart? parse(String raw) {
    final s = raw.trim().replaceAll(',', '.');
    if (s.isEmpty || s == '-') return RadicalPart(Rational(0));
    final i = s.indexOf('√');
    if (i < 0) return null;
    final coefText = s.substring(0, i);
    final radText = s.substring(i + 1);
    final n = int.tryParse(radText);
    if (n == null || n < 1) return null;
    Rational k;
    if (coefText.isEmpty) {
      k = Rational(1);
    } else if (coefText == '-') {
      k = Rational(-1);
    } else {
      final slash = coefText.split('/');
      final num = int.tryParse(slash[0]);
      final den = slash.length > 1 ? int.tryParse(slash[1]) : 1;
      if (num == null || den == null || den == 0) return null;
      k = Rational(num, den);
    }
    return RadicalPart(k, n);
  }
}

/// Binomica `a + bi` con radicales (`-1 + √3 i`) a polar `r_α` con modulo y angulo exactos.
class ComplexPolarRadical {
  const ComplexPolarRadical._();

  static String _dec(double v, int d) => v.toStringAsFixed(d).replaceAll('.', '{,}');

  static String _binomial(RadicalPart a, RadicalPart b) {
    final bAbs = RadicalPart(b.k.abs(), b.n);
    final bTxt = b.k == Rational(1) && b.n == 1 ? 'i' : '${bAbs.latex}i';
    if (a.isZero) return b.k.isNegative ? '-$bTxt' : bTxt;
    if (b.isZero) return a.latex;
    return '${a.latex} ${b.k.isNegative ? '-' : '+'} ${b.n == 1 && bAbs.k == Rational(1) ? 'i' : '${bAbs.latex}i'}';
  }

  static StepByStepResolution toPolar(RadicalPart a, RadicalPart b) {
    if (a.isZero && b.isZero) {
      throw const FormatException('El número complejo nulo no tiene forma polar (módulo 0).');
    }
    final sum2 = a.squared + b.squared;
    final String rLatex;
    if (sum2.isInteger) {
      rLatex = RadicalAndFactorSolver.simplifySquareRoot(sum2.numerator).exactResultLatex;
    } else {
      rLatex =
          '\\frac{${RadicalAndFactorSolver.simplifySquareRoot(sum2.numerator).exactResultLatex}}{${RadicalAndFactorSolver.simplifySquareRoot(sum2.denominator).exactResultLatex}}';
    }
    final rDouble = math.sqrt(sum2.toDouble());
    final av = a.value, bv = b.value;
    final ref = (av == 0 || bv == 0) ? 0.0 : math.atan(bv.abs() / av.abs()) * 180 / math.pi;
    final refExact = (ref - ref.roundToDouble()).abs() < 1e-9 ? ref.round() : null;
    final refTxt = refExact != null ? '$refExact^{\\circ}' : '${_dec(ref, 2)}^{\\circ}';

    double deg;
    String quadrant;
    String formula;
    if (bv == 0) {
      deg = av > 0 ? 0 : 180;
      quadrant = av > 0 ? 'Semieje real positivo' : 'Semieje real negativo';
      formula = '\\alpha = ${deg.round()}^{\\circ}';
    } else if (av == 0) {
      deg = bv > 0 ? 90 : 270;
      quadrant = bv > 0 ? 'Semieje imaginario positivo' : 'Semieje imaginario negativo';
      formula = '\\alpha = ${deg.round()}^{\\circ}';
    } else if (av > 0 && bv > 0) {
      deg = ref;
      quadrant = 'I Cuadrante';
      formula = '\\tan\\alpha = \\frac{${b.latex}}{${a.wrapped}} \\Rightarrow \\alpha = $refTxt';
    } else if (av < 0 && bv > 0) {
      deg = 180 - ref;
      quadrant = 'II Cuadrante';
      formula = '\\tan\\alpha_{0} = \\left|\\frac{${b.latex}}{${a.wrapped}}\\right| \\Rightarrow \\alpha_{0} = $refTxt \\Rightarrow \\alpha = 180^{\\circ} - $refTxt';
    } else if (av < 0 && bv < 0) {
      deg = 180 + ref;
      quadrant = 'III Cuadrante';
      formula = '\\tan\\alpha_{0} = \\left|\\frac{${b.wrapped}}{${a.wrapped}}\\right| \\Rightarrow \\alpha_{0} = $refTxt \\Rightarrow \\alpha = 180^{\\circ} + $refTxt';
    } else {
      deg = 360 - ref;
      quadrant = 'IV Cuadrante';
      formula = '\\tan\\alpha_{0} = \\left|\\frac{${b.wrapped}}{${a.latex}}\\right| \\Rightarrow \\alpha_{0} = $refTxt \\Rightarrow \\alpha = 360^{\\circ} - $refTxt';
    }
    final exactDeg = (deg - deg.roundToDouble()).abs() < 1e-9 ? deg.round() : null;
    final angleLatex = exactDeg != null ? '$exactDeg^{\\circ}' : '${_dec(deg, 2)}^{\\circ}';
    if (bv != 0 && av != 0 && !(av > 0 && bv > 0)) formula = '$formula = $angleLatex';
    final polar = '${rLatex}_{$angleLatex}';

    return StepByStepResolution(
      originalInputLatex: _binomial(a, b),
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Paso 1: Cálculo del módulo r',
          latexExpression:
              'r = \\sqrt{a^2 + b^2} = \\sqrt{${a.wrapped}^2 + ${b.wrapped}^2} = \\sqrt{${a.squared.toLatex()} + ${b.squared.toLatex()}} = \\sqrt{${sum2.toLatex()}} = $rLatex',
          pedagogicalNote:
              'El cuadrado de una raíz cuadrada es el radicando: (√n)² = n. Sumamos y simplificamos la raíz del módulo.',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Paso 2: Argumento α ($quadrant)',
          latexExpression: formula,
          pedagogicalNote:
              'Con el afijo (${a.latex}, ${b.latex}) identificamos el cuadrante y usamos el ángulo de referencia α₀ = arctan|b/a| para obtener α entre 0° y 360°.',
          warningTrick: av < 0 ? 'Si a < 0, arctan(b/a) por sí solo da un ángulo del cuadrante equivocado: hay que corregirlo con 180°.' : null,
        ),
        MathStep(
          index: 3,
          shortTitle: 'Paso 3: Expresión en forma polar y trigonométrica',
          latexExpression:
              'z = $polar = $rLatex\\left(\\cos\\left($angleLatex\\right) + i\\sin\\left($angleLatex\\right)\\right)',
          pedagogicalNote: 'Escribimos el número en forma polar r_α y en forma trigonométrica.',
        ),
      ],
      exactResultLatex: polar,
      decimalApproxLatex: '${_dec(rDouble, 4)}_{${_dec(deg, 2)}^{\\circ}}',
    );
  }
}
