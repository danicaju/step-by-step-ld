import 'dart:math' as math;

import '../core/number_formatter.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../solvers/calculus/sym_latex.dart';
import '../solvers/equations/eq_poly.dart';
import '../solvers/exact/exact_number.dart';
import '../solvers/exact/ext_expr.dart';
import 'polynomial_real_factorizer.dart';
import 'rational_primitive_terms.dart';
import 'real_coef.dart';

/// Fraccion simple numer(x) / factor^power.
class PartialFraction {
  final CPoly numer;
  final RealFactor factor;
  final int power;
  const PartialFraction(this.numer, this.factor, this.power);

  String latex({required bool first}) {
    if (numer.degree <= 0) return overFactor(numer[0], factor.poly, power, first: first);
    final base = factor.poly.latex();
    final den = power == 1 ? base : RealFactor(factor.poly, power).latex();
    return '${first ? '' : ' + '}\\frac{${numer.latex()}}{$den}';
  }
}

/// Resultado completo de ∫ P(x)/Q(x) dx.
class RationalIntegration {
  final Poly p;
  final Poly q;
  final Poly quotient;
  final Poly remainder;
  final bool simplified;
  final RealFactorization factorization;
  final List<PartialFraction> fractions;
  final RationalPrimitive primitive;
  const RationalIntegration({
    required this.p,
    required this.q,
    required this.quotient,
    required this.remainder,
    required this.simplified,
    required this.factorization,
    required this.fractions,
    required this.primitive,
  });

  double f(double x) => _ev(p, x) / _ev(q, x);

  static double _ev(Poly p, double x) => p.entries.fold(0.0, (s, e) => s + e.value.toDouble() * math.pow(x, e.key));
}

/// Integrador racional universal: division, factorizacion real, fracciones
/// simples (Gauss con pivoteo parcial) e integracion termino a termino.
class UniversalRationalIntegrator {
  const UniversalRationalIntegrator._();

  static Coef _c(Rational r) => Coef.rat(r);
  static CPoly _cp(Poly p) => CPoly([for (var k = 0; k <= math.max(0, PolyOps.degree(p)); k++) _c(PolyOps.coeff(p, k))]);

  static RationalIntegration? integrate(Poly p0, Poly q0) {
    if (PolyOps.degree(q0) < 1) return null;
    try {
      return _integrate(p0, q0, forceDec: false) ?? _integrate(p0, q0, forceDec: true);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  static RationalIntegration? _integrate(Poly p0, Poly q0, {required bool forceDec}) {
    var p = PolyOps.clean(p0);
    var q = PolyOps.clean(q0);
    final g = PolynomialRealFactorizer.gcd(p, q);
    final simplified = PolyOps.degree(g) > 0;
    if (simplified) {
      p = PolynomialRealFactorizer.divMod(p, g).$1;
      q = PolynomialRealFactorizer.divMod(q, g).$1;
    }
    if (PolyOps.degree(q) < 1) return null;
    final (quot, rem) = PolyOps.degree(p) >= PolyOps.degree(q)
        ? PolynomialRealFactorizer.divMod(p, q)
        : (<int, Rational>{}, p);
    var fac = PolynomialRealFactorizer.factor(q);
    if (forceDec) {
      fac = RealFactorization(
        fac.leading,
        [for (final f in fac.factors) RealFactor(f.poly.asDec, f.multiplicity)],
        FactorLevel.numeric,
        fac.methodNote,
      );
    }
    final n = PolyOps.degree(q);
    final rm = _cp(rem).scale(Coef.one / fac.leading);
    // Columnas del sistema: cada incognita multiplica a un polinomio.
    final cols = <CPoly>[];
    final slots = <(int, int, bool)>[]; // (factor, potencia, esLaB)
    final fs = fac.factors;
    for (var i = 0; i < fs.length; i++) {
      for (var j = 1; j <= fs[i].multiplicity; j++) {
        var cof = CPoly.constant(Coef.one);
        for (var l = 0; l < fs.length; l++) {
          final e = l == i ? fs[l].multiplicity - j : fs[l].multiplicity;
          for (var t = 0; t < e; t++) {
            cof = cof * fs[l].poly;
          }
        }
        if (fs[i].isLinear) {
          cols.add(cof);
          slots.add((i, j, false));
        } else {
          cols.add(cof * CPoly([Coef.zero, Coef.one]));
          slots.add((i, j, true));
          cols.add(cof);
          slots.add((i, j, false));
        }
      }
    }
    if (cols.length != n) return null;
    final sol = CoefLinearSolver.solve(
      [for (var row = 0; row < n; row++) [for (final c in cols) c[row]]],
      [for (var row = 0; row < n; row++) rm[row]],
    );
    if (sol == null) return null;
    final fractions = <PartialFraction>[];
    final terms = <PrimTerm>[];
    if (quot.isNotEmpty) {
      final anti = <Coef>[Coef.zero];
      for (var k = 0; k <= PolyOps.degree(quot); k++) {
        anti.add(_c(PolyOps.coeff(quot, k) / Rational(k + 1)));
      }
      terms.add(PolyPrim(CPoly(anti)));
    }
    for (var s = 0; s < slots.length; s++) {
      final (i, j, isB) = slots[s];
      final f = fs[i];
      if (f.isLinear) {
        final a = sol[s];
        if (a.isZero) continue;
        fractions.add(PartialFraction(CPoly.constant(a), f, j));
        terms.add(j == 1 ? LnLinear(a, f.root) : PowLinear(-a / Coef.integer(j - 1), f.root, j - 1));
      } else if (isB) {
        final b = sol[s];
        final c = sol[s + 1];
        if (b.isZero && c.isZero) continue;
        fractions.add(PartialFraction(CPoly([c, b]), f, j));
        _quadTerms(terms, b, c, f.poly, j);
      }
    }
    final prim = RationalPrimitive(terms);
    final res = RationalIntegration(
      p: p,
      q: q,
      quotient: quot,
      remainder: rem,
      simplified: simplified,
      factorization: fac,
      fractions: fractions,
      primitive: prim,
    );
    return _verify(res) ? res : null;
  }

  /// ∫ (Bx + C)/(x^2 + px + q)^k dx
  static void _quadTerms(List<PrimTerm> out, Coef b, Coef c, CPoly quad, int k) {
    final two = Coef.integer(2);
    final p = quad[1];
    final m = c - b * p / two; // parte del arcotangente
    if (!b.isZero) {
      out.add(k == 1
          ? LnQuad(b / two, quad)
          : QuadFrac(b / (two * Coef.integer(1 - k)), CPoly.constant(Coef.one), quad, k - 1));
    }
    if (m.isZero) return;
    final h2 = quad[0] - p * p / Coef.integer(4);
    final t = CPoly([p / two, Coef.one]);
    void addJ(Coef coef, int kk) {
      if (kk == 1) {
        out.add(AtanQuad(coef, quad));
        return;
      }
      final den = two * h2 * Coef.integer(kk - 1);
      out.add(QuadFrac(coef / den, t, quad, kk - 1));
      addJ(coef * Coef.integer(2 * kk - 3) / den, kk - 1);
    }

    addJ(m, k);
  }

  /// F'(x) ≈ f(x) por diferencias centradas en varios puntos.
  static bool _verify(RationalIntegration r) {
    var good = 0;
    for (final x in const [-3.3, -1.7, -0.6, -0.25, 0.31, 0.77, 1.3, 2.1, 3.4]) {
      final qv = RationalIntegration._ev(r.q, x);
      if (qv.abs() < 1e-3) continue;
      final fv = r.f(x);
      const h = 1e-5;
      final d = (r.primitive.eval(x + h) - r.primitive.eval(x - h)) / (2 * h);
      if (!d.isFinite) continue;
      if ((d - fv).abs() > 1e-4 * (1 + fv.abs())) return false;
      good++;
    }
    return good >= 3;
  }

  // ------------------------------------------------------------ pasos

  /// P/Q con el signo fuera (`-\frac{1}{Q}` en vez de `\frac{-1}{Q}`).
  static String _frac(Poly p, Poly q) {
    final neg = p.isNotEmpty && PolyOps.coeff(p, PolyOps.degree(p)).isNegative;
    final body = '\\frac{${PolyOps.latex(neg ? PolyOps.neg(p) : p)}}{${PolyOps.latex(q)}}';
    return neg ? '-$body' : body;
  }

  static List<MathStep> _steps(RationalIntegration r, String integrand) {
    final steps = <MathStep>[];
    void add(String t, String l, String n, [String? w]) => steps.add(
          MathStep(index: steps.length + 1, shortTitle: t, latexExpression: l, pedagogicalNote: n, warningTrick: w),
        );
    final degP = PolyOps.degree(r.p);
    final degQ = PolyOps.degree(r.q);
    if (r.simplified) {
      add('Simplificar la fracción', '$integrand = ${_frac(r.p, r.q)}',
          'Numerador y denominador tienen un factor común: lo cancelamos antes de integrar.');
    }
    if (r.quotient.isNotEmpty) {
      final rf = r.remainder.isEmpty ? '' : _frac(r.remainder, r.q);
      final rest = rf.isEmpty ? '' : (rf.startsWith('-') ? ' - ${rf.substring(1)}' : ' + $rf');
      add('1. División polinómica', '${_frac(r.p, r.q)} = ${PolyOps.latex(r.quotient)}$rest',
          'El grado del numerador ($degP) no es menor que el del denominador ($degQ): dividimos '
              'P(x) = C(x)·Q(x) + R(x) y el cociente C(x) se integra término a término.');
    }
    final fac = r.factorization;
    add(
      '2. Factorización real de Q(x)',
      'Q(x) = ${PolyOps.latex(r.q)} = ${fac.latex()}',
      fac.methodNote.isEmpty ? 'Descomponemos Q(x) en factores lineales y cuadráticos irreducibles.' : fac.methodNote,
      fac.level == FactorLevel.numeric
          ? 'Los decimales se muestran con 4 cifras significativas; los cálculos internos usan precisión completa.'
          : null,
    );
    if (r.fractions.isNotEmpty) {
      final lhs = _frac(r.remainder, r.q);
      add(
        '3. Descomposición en fracciones simples',
        '$lhs = ${_template(fac)}',
        'Cada factor lineal (x − r)ᵐ aporta A₁/(x − r) + … + Aₘ/(x − r)ᵐ y cada cuadrático irreducible '
            'aporta (Bx + C)/(x² + px + q). Multiplicamos por Q(x), igualamos los coeficientes de cada '
            'potencia de x y resolvemos el sistema $degQ×$degQ por eliminación de Gauss con pivoteo parcial.',
      );
      final pf = StringBuffer();
      for (var i = 0; i < r.fractions.length; i++) {
        pf.write(r.fractions[i].latex(first: i == 0));
      }
      add('3. Coeficientes de las fracciones simples', '$lhs = $pf',
          'Sustituimos los valores obtenidos al resolver el sistema lineal.');
    }
    add(
      '4. Integración término a término',
      '\\int $integrand\\,dx = ${r.primitive.latex()}',
      '∫A/(x − r)dx = A·ln|x − r|;  ∫A/(x − r)ᵐdx = −A/((m − 1)(x − r)ᵐ⁻¹);  en (Bx + C)/(x² + px + q) '
          'separamos (B/2)·ln(x² + px + q) y completamos el cuadrado (x + p/2)² + (4q − p²)/4, que da un arcotangente.',
    );
    return steps;
  }

  static String _template(RealFactorization fac) {
    final buf = StringBuffer();
    var a = 0;
    var b = 0;
    for (final f in fac.factors) {
      for (var j = 1; j <= f.multiplicity; j++) {
        final den = j == 1 ? f.poly.latex() : RealFactor(f.poly, j).latex();
        final numer = f.isLinear ? 'A_{${++a}}' : 'B_{${++b}}x + C_{$b}';
        buf.write('${buf.isEmpty ? '' : ' + '}\\frac{$numer}{$den}');
      }
    }
    return buf.toString();
  }

  static ({Poly p, Poly q})? _pq(XNode f) {
    final pq = PolyOps.rationalOf(f);
    if (pq == null || PolyOps.degree(pq.$2) < 1) return null;
    return (p: pq.$1, q: pq.$2);
  }

  /// ∫ f(x) dx si f es racional; `null` si no lo es o no se puede integrar.
  static StepByStepResolution? indefinite(XNode f) {
    final pq = _pq(f);
    if (pq == null) return null;
    final r = integrate(pq.p, pq.q);
    if (r == null) return null;
    final integrand = SymLatex.tex(f);
    final res ='${r.primitive.latex()} + C';
    final steps = _steps(r, integrand)
      ..add(MathStep(
        index: 0,
        shortTitle: '5. Resultado final + C',
        latexExpression: '\\int $integrand\\,dx = $res',
        pedagogicalNote: 'Sumamos todas las primitivas parciales y añadimos la constante de integración C.',
        warningTrick: 'Una integral indefinida sin + C es una respuesta incompleta.',
      ));
    return StepByStepResolution(
      originalInputLatex: '\\int $integrand\\,dx',
      steps: _reindex(steps),
      exactResultLatex: res,
      decimalApproxLatex: res,
    );
  }

  /// ∫_a^b f(x) dx racional, comprobando antes los polos en [a, b].
  static StepByStepResolution? definite(XNode f, Rational a, Rational b) {
    final pq = _pq(f);
    if (pq == null) return null;
    final r = integrate(pq.p, pq.q);
    if (r == null) return null;
    final lo = math.min(a.toDouble(), b.toDouble());
    final hi = math.max(a.toDouble(), b.toDouble());
    for (final fct in r.factorization.factors) {
      if (!fct.isLinear) continue;
      final x0 = fct.root.v;
      if (x0 >= lo - 1e-12 && x0 <= hi + 1e-12) {
        throw const ExMathError('Integral impropia: el denominador se anula dentro de [a, b]');
      }
    }
    final integrand = SymLatex.tex(f);
    final fb = r.primitive.eval(b.toDouble());
    final fa = r.primitive.eval(a.toDouble());
    final total = fb - fa;
    String d(double v) => NumberFormatter.decimal(v);
    final aL = a.toLatex();
    final bL = b.toLatex();
    final steps = _steps(r, integrand)
      ..add(MathStep(
        index: 0,
        shortTitle: '5. Polos en [a, b]',
        latexExpression: 'Q(x) = ${r.factorization.latex()} \\neq 0 \\quad \\forall x \\in \\left[$aL, $bL\\right]',
        pedagogicalNote: 'Ninguna raíz real del denominador cae en el intervalo: f(x) es continua en [a, b] '
            'y podemos aplicar la regla de Barrow.',
      ))
      ..add(MathStep(
        index: 0,
        shortTitle: '6. Regla de Barrow F(b) − F(a)',
        latexExpression: 'F($bL) - F($aL) \\approx ${d(fb)} - \\left(${d(fa)}\\right) \\approx ${d(total)}',
        pedagogicalNote: 'Evaluamos la primitiva en los extremos y restamos: ∫ₐᵇ f(x)dx = F(b) − F(a).',
        warningTrick: 'Pon F(a) entre paréntesis para no equivocarte con los signos.',
      ));
    return StepByStepResolution(
      originalInputLatex: '\\int_{$aL}^{$bL} $integrand\\,dx',
      steps: _reindex(steps),
      exactResultLatex: d(total),
      decimalApproxLatex: d(total),
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
