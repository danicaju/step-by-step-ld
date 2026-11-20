import 'dart:math' as math;

import '../../core/number_formatter.dart';
import '../../core/rational.dart';
import '../../models/complex_models.dart';
import '../../models/step_resolution.dart';
import '../exact/exact_number.dart';
import '../exact/ext_math.dart';
import '../exact/ext_trig.dart';
import '../trig_and_angles_solver.dart';

/// Exponencial compleja (formula de Euler) y logaritmo complejo principal.
///
/// Las partes `a` y `b` son [ExNum] porque pueden ser irracionales (`b = π`).
class ComplexEulerSolver {
  const ComplexEulerSolver._();

  static const AngleUnit _rad = AngleUnit.rad;

  // ---- LaTeX de apoyo -------------------------------------------------------

  static String _w(ExNum n) {
    final t = n.toLatex();
    final compound = t.contains(' + ') || t.contains(' - ');
    return compound ? '\\left($t\\right)' : t;
  }

  /// `a + bi` con los casos `0`, `bi`, `a - bi` resueltos.
  static String _bin(ExNum re, ExNum im) {
    final reZero = re.isZero;
    if (im.isZero) return re.toLatex();
    final neg = im.approx < 0;
    final abs = neg ? -im : im;
    final c = _w(abs);
    // `\pi` seguido de `i` se uniria en `\pii`: se separa con un espacio.
    final coef = abs.asRational == Rational(1) ? 'i' : (RegExp(r'\\[a-zA-Z]+$').hasMatch(c) ? '$c i' : '${c}i');
    if (reZero) return neg ? '-$coef' : coef;
    return '${re.toLatex()} ${neg ? '-' : '+'} $coef';
  }

  static String _decimalBin(double re, double im) {
    String f(double v) => NumberFormatter.decimal(v);
    if (im.abs() < 1e-12) return f(re);
    final coef = (im.abs() - 1).abs() < 1e-12 ? 'i' : '${f(im.abs())}i';
    if (re.abs() < 1e-12) return im < 0 ? '-$coef' : coef;
    return '${f(re)} ${im < 0 ? '-' : '+'} $coef';
  }

  static String _z(ExNum a, ExNum b) => _bin(a, b);

  static ExNum _ePow(ExNum a) {
    if (a.isZero) return ExNum.integer(1);
    final k = a.asInt;
    if (k != null && k.abs() <= 30) return ExNum.fromTerms({(1, 0, k): Rational(1)});
    return ExNum.opaque('e^{${a.toLatex()}}', math.exp(a.approx));
  }

  static ExNum _ln(ExNum x) {
    if (x.asRational == Rational(1)) return ExNum.integer(0);
    return ExNum.opaque('\\ln\\left(${x.toLatex()}\\right)', math.log(x.approx));
  }

  // ---- e^z --------------------------------------------------------------------

  /// `e^(a+bi) = e^a (cos b + i sen b)` con `b` en radianes.
  static ComplexResult exp(ExNum a, ExNum b) {
    final cosB = ExtTrig.direct('cos', b, _rad);
    final sinB = ExtTrig.direct('sin', b, _rad);
    final ea = _ePow(a);
    final re = ea * cosB;
    final im = ea * sinB;
    final zl = _z(a, b);
    final exact = _bin(re, im);
    final isEuler = a.isZero && b.terms.length == 1 && b.terms.containsKey((1, 1, 0)) &&
        b.terms.values.first == Rational(1);
    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Fórmula de Euler',
        latexExpression:
            'e^{$zl} = e^{${a.toLatex()}}\\left(\\cos\\left(${b.toLatex()}\\right) + i\\sin\\left(${b.toLatex()}\\right)\\right)',
        pedagogicalNote:
            'Para z = a + bi, e^z = e^a · (cos b + i·sen b). El ángulo b se mide siempre en radianes, '
            'sin importar si la calculadora está en DEG o RAD.',
      ),
      MathStep(
        index: 2,
        shortTitle: 'Valores de e^a, cos b y sen b',
        latexExpression:
            'e^{${a.toLatex()}} = ${ea.toLatex()},\\quad \\cos\\left(${b.toLatex()}\\right) = ${cosB.toLatex()},\\quad \\sin\\left(${b.toLatex()}\\right) = ${sinB.toLatex()}',
        pedagogicalNote:
            'Calculamos el módulo e^a y las razones trigonométricas del ángulo b (en radianes).',
      ),
      MathStep(
        index: 3,
        shortTitle: 'Resultado en forma binómica',
        latexExpression:
            'e^{$zl} = ${_w(ea)}\\cdot\\left(${_bin(cosB, sinB)}\\right) = $exact',
        pedagogicalNote: isEuler
            ? 'Caso notable: e^(iπ) = -1, la identidad de Euler (e^(iπ) + 1 = 0).'
            : 'Multiplicamos e^a por la parte real e imaginaria de cos b + i·sen b.',
        warningTrick: isEuler
            ? null
            : 'No uses grados para b: en la fórmula de Euler el ángulo va en radianes.',
      ),
    ];
    return ComplexResult(
      resolution: StepByStepResolution(
        originalInputLatex: 'e^{$zl}',
        steps: steps,
        exactResultLatex: exact,
        decimalApproxLatex: _decimalBin(re.approx, im.approx),
      ),
    );
  }

  // ---- Ln z -------------------------------------------------------------------

  static ExNum _arg(ExNum a, ExNum b) {
    final av = a.approx;
    final bv = b.approx;
    final half = ExNum.fromTerms({(1, 1, 0): Rational(1, 2)});
    if (av.abs() < 1e-15) return bv > 0 ? half : -half;
    final base = ExtTrig.inverse('atan', b / a, _rad);
    if (av > 0) return base;
    if (bv.abs() < 1e-15) return ExNum.pi();
    return bv > 0 ? base + ExNum.pi() : base - ExNum.pi();
  }

  /// `Ln(z) = ln|z| + i·arg(z)` con `arg(z)` en `(-π, π]`.
  static ComplexResult ln(ExNum a, ExNum b) {
    final av = a.approx;
    final bv = b.approx;
    if (av.abs() < 1e-15 && bv.abs() < 1e-15) throw const ExMathError(ExMathError.lnZero);
    final zl = _z(a, b);
    final norm2 = a * a + b * b;
    final r2 = norm2.asRational;
    final modulus = r2 != null
        ? ExtMath.nthRoot(r2, 2)
        : ExNum.opaque('\\sqrt{${norm2.toLatex()}}', math.sqrt(norm2.approx));
    final lnR = _ln(modulus);
    final arg = _arg(a, b);
    final quadrant = av.abs() < 1e-15
        ? 'z está sobre el eje imaginario: arg(z) = ±π/2.'
        : av > 0
            ? 'Parte real positiva (cuadrantes I y IV): arg(z) = arctan(b/a).'
            : (bv.abs() < 1e-15
                ? 'z es un real negativo: arg(z) = π.'
                : 'Parte real negativa (cuadrantes II y III): arg(z) = arctan(b/a) ± π.');
    final exact = _bin(lnR, arg);
    final decimalRe = 0.5 * math.log(norm2.approx);
    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Módulo |z|',
        latexExpression:
            '\\left|$zl\\right| = \\sqrt{a^{2} + b^{2}} = \\sqrt{${norm2.toLatex()}} = ${modulus.toLatex()}',
        pedagogicalNote: 'El módulo es la distancia de z al origen: |z| = raíz de (a² + b²).',
      ),
      MathStep(
        index: 2,
        shortTitle: 'Argumento principal',
        latexExpression: '\\arg\\left($zl\\right) = ${arg.toLatex()}',
        pedagogicalNote: '$quadrant El argumento principal se toma en el intervalo (-π, π].',
        warningTrick: 'arctan(b/a) solo da el cuadrante correcto si a > 0: revisa siempre el signo de a.',
      ),
      MathStep(
        index: 3,
        shortTitle: 'Logaritmo complejo principal',
        latexExpression:
            '\\mathrm{Ln}\\left($zl\\right) = \\ln\\left|z\\right| + i\\arg(z) = ${lnR.toLatex()} + i\\left(${arg.toLatex()}\\right) = $exact',
        pedagogicalNote: 'Ln(z) = ln|z| + i·arg(z). La parte real es el logaritmo neperiano del módulo.',
      ),
    ];
    return ComplexResult(
      resolution: StepByStepResolution(
        originalInputLatex: '\\mathrm{Ln}\\left($zl\\right)',
        steps: steps,
        exactResultLatex: exact,
        decimalApproxLatex: _decimalBin(decimalRe, arg.approx),
      ),
    );
  }
}
