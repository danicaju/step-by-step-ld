import 'dart:math' as math;

import '../core/number_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../solvers/calculus/integral_table.dart';
import '../solvers/calculus/sym_build.dart';
import '../solvers/calculus/sym_latex.dart';
import '../solvers/equations/eq_poly.dart';
import '../solvers/exact/exact_number.dart';
import '../solvers/exact/ext_expr.dart';

/// Familia clasica sin primitiva elemental.
class NonElementaryFamily {
  /// Nombre en texto plano (para `Text`).
  final String name;

  /// Primitiva con funcion especial (LaTeX, sin + C) o `null`.
  final String? special;

  /// Explicacion en texto plano de la funcion especial.
  final String note;
  const NonElementaryFamily(this.name, this.special, this.note);
}

/// Integrales sin primitiva elemental: explicacion didactica (indefinida) y
/// valor numerico con Simpson adaptativo (definida).
class NonElementaryIntegralHandler {
  const NonElementaryIntegralHandler._();

  static String _t(XNode n) => SymLatex.tex(n);

  // ---------------------------------------------------------- deteccion

  static NonElementaryFamily? detect(XNode f) {
    final (k, g) = _constSplit(f);
    final fam = _detect(g);
    if (fam == null || k == null || fam.special == null) return fam;
    return NonElementaryFamily(fam.name, '${_t(k)} \\cdot \\left(${fam.special}\\right)', fam.note);
  }

  static (XNode?, XNode) _constSplit(XNode f) {
    if (f is XNeg && Sx.hasX(f.a)) return (Sx.num(-1), f.a);
    if (f is XBin && f.op == '*') {
      if (!Sx.hasX(f.l)) return (f.l, f.r);
      if (!Sx.hasX(f.r)) return (f.r, f.l);
    }
    if (f is XBin && f.op == '/' && !Sx.hasX(f.r)) return (Sx.div(Sx.one, f.r), f.l);
    return (null, f);
  }

  /// e^(exp) -> exp
  static XNode? _expArg(XNode n) =>
      n is XPow && n.base is XConst && (n.base as XConst).kind == 'e' ? n.exp : null;

  /// c x^2 -> c
  static Rational? _cx2(XNode n) {
    final p = PolyOps.polyOf(n);
    if (p == null || p.length != 1 || !p.containsKey(2)) return null;
    return p[2];
  }

  /// a x -> a
  static Rational? _ax(XNode n) {
    final l = IntegralTable.linear(n);
    return l == null || !l.$2.isZero ? null : l.$1;
  }

  static bool _isX(XNode n) => n is XVar && n.name == 'X';

  static String _lin(Rational a) => a == Rational(1)
      ? 'x'
      : (a == Rational(-1) ? '-x' : '${Sx.rat(a).latex()}x');

  static const _gaussNote =
      'erf(x) es la función error de Gauss: (2/√π)·∫₀ˣ e^(−t²) dt. Es el área bajo la campana de Gauss y '
      'se usa constantemente en probabilidad y estadística.';

  static NonElementaryFamily? _detect(XNode g) {
    final e = _expArg(g);
    if (e != null) {
      final c = _cx2(e);
      if (c != null) {
        final kk = c.abs();
        final one = kk == Rational(1);
        final sk = one ? '' : '\\sqrt{${Sx.rat(kk).latex()}}';
        final fn = c.isNegative ? '\\mathrm{erf}' : '\\mathrm{erfi}';
        final arg = one ? 'x' : '$sk\\,x';
        final den = one ? '2' : '2$sk';
        return NonElementaryFamily(
          'Gaussiana e^(${c.isNegative ? '−' : '+'}x²)',
          '\\frac{\\sqrt{\\pi}}{$den}$fn\\left($arg\\right)',
          c.isNegative ? _gaussNote : 'erfi(x) = −i·erf(ix) es la función error imaginaria, prima de erf.',
        );
      }
    }
    if (g is XBin && g.op == '*') {
      for (final (m, ex) in [(g.l, g.r), (g.r, g.l)]) {
        final arg = _expArg(ex);
        final p = PolyOps.polyOf(m);
        if (arg == null || _cx2(arg) == null || p == null || p.length != 1) continue;
        final n = p.keys.first;
        if (n >= 2 && n.isEven) {
          return const NonElementaryFamily(
            'Potencia par por gaussiana x²ᵏ·e^(±x²)',
            null,
            'Integrando por partes k veces se reduce siempre a ∫e^(±x²)dx, que solo se expresa con la función error erf.',
          );
        }
      }
    }
    if (g is XBin && g.op == '/' && _isX(g.r)) {
      final num = g.l;
      if (num is XFn && (num.name == 'sin' || num.name == 'cos')) {
        final a = _ax(num.arg);
        if (a != null) {
          final si = num.name == 'sin';
          return NonElementaryFamily(
            si ? 'Seno integral sin(ax)/x' : 'Coseno integral cos(ax)/x',
            '\\mathrm{${si ? 'Si' : 'Ci'}}\\left(${_lin(si ? a : a.abs())}\\right)',
            si
                ? 'Si(x) = ∫₀ˣ sin(t)/t dt es el seno integral; aparece en óptica y en el análisis de señales.'
                : 'Ci(x) es el coseno integral, pariente del seno integral Si(x).',
          );
        }
      }
      final ea = _expArg(num);
      if (ea != null && _ax(ea) != null) {
        return NonElementaryFamily(
          'Exponencial integral e^(ax)/x',
          '\\mathrm{Ei}\\left(${_lin(_ax(ea)!)}\\right)',
          'Ei(x) es la exponencial integral, una función especial definida precisamente como esta primitiva.',
        );
      }
    }
    if (g is XBin && g.op == '/' && Sx.isNum(g.l, 1)) {
      final d = g.r;
      if (d is XFn && d.name == 'ln' && _isX(d.arg)) {
        return const NonElementaryFamily(
          'Logaritmo integral 1/ln(x)',
          '\\mathrm{li}\\left(x\\right)',
          'li(x) es el logaritmo integral; estima cuántos números primos hay menores que x.',
        );
      }
    }
    if (g is XFn && (g.name == 'sin' || g.name == 'cos') && _cx2(g.arg) != null) {
      final s = g.name == 'sin';
      final unit = _cx2(g.arg) == Rational(1);
      return NonElementaryFamily(
        'Integral de Fresnel ${g.name}(x²)',
        unit
            ? '\\sqrt{\\frac{\\pi}{2}}\\,${s ? 'S' : 'C'}\\left(\\sqrt{\\frac{2}{\\pi}}\\,x\\right)'
            : null,
        'S(x) y C(x) son las integrales de Fresnel; describen la difracción de la luz y el trazado de curvas de carretera (clotoides).',
      );
    }
    final rad = switch (g) {
      XRoot(:final index, :final rad) when index == null || Sx.isNum(index, 2) => rad,
      XPow(:final base, :final exp) when Sx.numVal(exp) == Rational(1, 2) => base,
      _ => null,
    };
    if (rad != null) {
      final p = PolyOps.polyOf(rad);
      final n = p == null ? 0 : PolyOps.degree(p);
      if (p != null && (n == 3 || n == 4) && p.length == 2 && p.containsKey(0)) {
        return NonElementaryFamily(
          'Integral elíptica √(1 ± x^$n)',
          null,
          'Es una integral elíptica: su primitiva requiere las funciones elípticas de Legendre, que no son elementales.',
        );
      }
    }
    return null;
  }

  // ------------------------------------------------------- numerico

  /// f(x) con tratamiento de singularidades evitables; `null` si no es finita.
  static double? _value(XNode f, double x) {
    final v = Sx.numAt(f, x);
    if (v != null) return v;
    const h = 1e-9;
    final a = Sx.numAt(f, x - h);
    final b = Sx.numAt(f, x + h);
    if (a == null || b == null || a.abs() > 1e8 || b.abs() > 1e8) return null;
    return (a + b) / 2;
  }

  /// Simpson adaptativo con tolerancia [tol]; lanza [ExMathError] si es impropia.
  static double numericValue(XNode f, double a, double b, {double tol = 1e-9}) {
    final lo = math.min(a, b);
    final hi = math.max(a, b);
    for (var i = 0; i <= 200; i++) {
      final v = _value(f, lo + (hi - lo) * i / 200);
      if (v == null || v.abs() > 1e8) {
        throw const ExMathError('Integral impropia: la función no es finita en todo [a, b]');
      }
    }
    if (a == b) return 0;
    var evals = 0;
    double fx(double x) {
      evals++;
      return _value(f, x) ?? 0;
    }

    double rec(double l, double r, double eps, double whole, double fl, double fm, double fr, int depth) {
      final m = (l + r) / 2;
      final lm = (l + m) / 2;
      final rm = (m + r) / 2;
      final flm = fx(lm);
      final frm = fx(rm);
      final left = (m - l) / 6 * (fl + 4 * flm + fm);
      final right = (r - m) / 6 * (fm + 4 * frm + fr);
      final delta = left + right - whole;
      if (depth <= 0 || evals > 200000 || delta.abs() <= 15 * eps) return left + right + delta / 15;
      return rec(l, m, math.max(eps / 2, 1e-15), left, fl, flm, fm, depth - 1) +
          rec(m, r, math.max(eps / 2, 1e-15), right, fm, frm, fr, depth - 1);
    }

    final fa = fx(a);
    final fb = fx(b);
    final fm = fx((a + b) / 2);
    return rec(a, b, tol, (b - a) / 6 * (fa + 4 * fm + fb), fa, fm, fb, 50);
  }

  // --------------------------------------------------------- pasos

  static MathStep _identify(XNode f, NonElementaryFamily fam) => MathStep(
        index: 0,
        shortTitle: '1. Identificar el integrando',
        latexExpression: 'f(x) = ${_t(f)}',
        pedagogicalNote: 'Pertenece a una familia clásica de integrales sin primitiva elemental: ${fam.name}.',
      );

  static const _liouville =
      'El teorema de Liouville demuestra que su primitiva no se puede escribir combinando un número finito de '
      'polinomios, raíces, exponenciales, logaritmos y funciones trigonométricas. No es falta de técnica: '
      'sustitución, partes o fracciones simples nunca terminan.';

  static StepByStepResolution? indefinite(XNode f) {
    final fam = detect(f);
    if (fam == null) return null;
    final integral = '\\int ${_t(f)}\\,dx';
    final steps = <MathStep>[
      _identify(f, fam),
      MathStep(
        index: 0,
        shortTitle: '2. ¿Tiene primitiva elemental?',
        latexExpression: '$integral \\;\\rightarrow\\; \\text{sin primitiva elemental}',
        pedagogicalNote: _liouville,
      ),
      if (fam.special != null)
        MathStep(
          index: 0,
          shortTitle: '3. Función especial asociada',
          latexExpression: '$integral = ${fam.special} + C',
          pedagogicalNote: fam.note,
        )
      else
        MathStep(
          index: 0,
          shortTitle: '3. Qué se puede hacer',
          latexExpression: '$integral \\;\\rightarrow\\; \\text{funcion especial}',
          pedagogicalNote: fam.note,
        ),
      MathStep(
        index: 0,
        shortTitle: '4. Para obtener un número: Integral Definida',
        latexExpression: '\\int_{a}^{b} ${_t(f)}\\,dx \\approx \\text{valor numerico}',
        pedagogicalNote: 'Usa la Integral Definida ∫ₐᵇ: la calculadora obtiene su valor con la regla de '
            'Simpson adaptativa (error menor que 10⁻⁹).',
        warningTrick: 'No es un error de la calculadora: esta primitiva no existe con funciones elementales.',
      ),
    ];
    final res = fam.special == null ? '\\text{Sin primitiva elemental}' : '${fam.special} + C';
    return StepByStepResolution(
      originalInputLatex: integral,
      steps: _reindex(steps),
      exactResultLatex: res,
      decimalApproxLatex: res,
    );
  }

  static StepByStepResolution? definite(XNode f, Rational a, Rational b) {
    final fam = detect(f);
    if (fam == null) return null;
    final v = numericValue(f, a.toDouble(), b.toDouble());
    final aL = a.toLatex();
    final bL = b.toLatex();
    final integral = '\\int_{$aL}^{$bL} ${_t(f)}\\,dx';
    final val = NumberFormatter.decimal(v);
    final steps = <MathStep>[
      _identify(f, fam),
      MathStep(
        index: 0,
        shortTitle: '2. Barrow no es aplicable',
        latexExpression: '\\int ${_t(f)}\\,dx \\;\\rightarrow\\; \\text{sin primitiva elemental}',
        pedagogicalNote: '$_liouville Sin una F(x) elemental no podemos calcular F(b) − F(a), así que integramos numéricamente.',
      ),
      MathStep(
        index: 0,
        shortTitle: '3. Simpson adaptativo',
        latexExpression: '\\int_{l}^{r} f\\,dx \\approx \\frac{r - l}{6}\\left[f(l) + 4f\\left(\\frac{l + r}{2}\\right) + f(r)\\right]',
        pedagogicalNote: 'En cada subintervalo [l, r] aproximamos f(x) por una parábola (regla de Simpson). Si al '
            'partirlo en dos mitades el resultado cambia más que la tolerancia, seguimos subdividiendo solo '
            'ahí (adaptativo) hasta un error menor que 10⁻⁹.',
      ),
      MathStep(
        index: 0,
        shortTitle: '4. Resultado numérico',
        latexExpression: '$integral \\approx $val',
        pedagogicalNote: 'Valor aproximado con 6 decimales.${fam.special != null ? ' ${fam.note}' : ''}',
      ),
    ];
    return StepByStepResolution(
      originalInputLatex: integral,
      steps: _reindex(steps),
      exactResultLatex: val,
      decimalApproxLatex: val,
    );
  }

  static List<MathStep> _reindex(List<MathStep> s) => [
        for (var i = 0; i < s.length; i++)
          MathStep(
            index: i + 1,
            shortTitle: s[i].shortTitle,
            latexExpression: s[i].latexExpression,
            pedagogicalNote: s[i].pedagogicalNote,
            warningTrick: s[i].warningTrick,
          ),
      ];
}
