import 'dart:math' as math;

import '../core/rational.dart';
import '../solvers/equations/eq_poly.dart';
import 'real_coef.dart';

/// Nivel de exactitud alcanzado al factorizar.
enum FactorLevel { exactRational, exactRadical, numeric }

/// Factor real monico de grado 1 o 2 elevado a [multiplicity].
class RealFactor {
  final CPoly poly;
  final int multiplicity;
  const RealFactor(this.poly, this.multiplicity);

  bool get isLinear => poly.degree == 1;

  /// Raiz r del factor lineal x - r.
  Coef get root => -poly[0];

  String latex() {
    final body = poly.latex();
    final base = body == 'x' ? 'x' : '\\left($body\\right)';
    return multiplicity > 1 ? '$base^{$multiplicity}' : base;
  }
}

/// Q(x) = leading · prod(factores).
class RealFactorization {
  final Coef leading;
  final List<RealFactor> factors;
  final FactorLevel level;
  final String methodNote;
  const RealFactorization(this.leading, this.factors, this.level, this.methodNote);

  int get degree => factors.fold(0, (s, f) => s + f.poly.degree * f.multiplicity);

  String latex() {
    final lead = leading.asRational == Rational(1)
        ? ''
        : (leading.asRational == Rational(-1) ? '-' : '${leading.latex()} \\cdot ');
    return '$lead${factors.map((f) => f.latex()).join()}';
  }
}

/// Factorizacion real de polinomios racionales: familias con radicales (Nivel 1),
/// raices racionales (Ruffini) y raices complejas por Aberth-Ehrlich (Nivel 2).
class PolynomialRealFactorizer {
  const PolynomialRealFactorizer._();

  static Coef _r(Rational r) => Coef.rat(r);
  static final Coef _phi = SurdCoef(Rational(1, 2), Rational(1, 2), 5);
  static final Coef _psi = SurdCoef(Rational(1, 2), Rational(-1, 2), 5);
  static final Coef _sqrt2 = SurdCoef(Rational(0), Rational(1), 2);
  static final Coef _sqrt3 = SurdCoef(Rational(0), Rational(1), 3);

  static RealFactorization factor(Poly q) {
    final p = PolyOps.clean(q);
    final n = PolyOps.degree(p);
    if (n < 1) throw ArgumentError('Polinomio constante');
    final lc = PolyOps.coeff(p, n);
    var rest = PolyOps.scale(p, Rational(1) / lc);
    final out = <RealFactor>[];
    final notes = <String>[];
    var level = FactorLevel.exactRational;
    void bump(FactorLevel l) {
      if (l.index > level.index) level = l;
    }

    final low = rest.keys.reduce(math.min);
    if (low > 0) {
      out.add(RealFactor(CPoly.linear(Coef.zero), low));
      rest = {for (final e in rest.entries) e.key - low: e.value};
      notes.add('Sacamos x factor común (raíz x = 0).');
    }
    var fam = _family(rest);
    if (fam == null) {
      final roots = <Rational, int>{};
      var guard = 0;
      while (PolyOps.degree(rest) >= 1 && guard++ < 24) {
        final r = PolyRoots.rationalRoot(PolyOps.toIntegers(rest));
        if (r == null) break;
        roots[r] = (roots[r] ?? 0) + 1;
        rest = PolyOps.deflate(rest, r);
      }
      roots.forEach((r, m) => out.add(RealFactor(CPoly.linear(_r(r)), m)));
      if (roots.isNotEmpty) {
        notes.add('Raíces racionales por Ruffini (divisores del término independiente): '
            '${roots.keys.map((r) => r.isInteger ? '${r.numerator}' : '${r.numerator}/${r.denominator}').join(', ')}.');
      }
      fam = _family(rest);
    }
    if (fam != null) {
      out.addAll(fam.factors);
      notes.add(fam.note);
      bump(FactorLevel.exactRadical);
    } else if (PolyOps.degree(rest) >= 1) {
      for (final part in _squareFree(rest)) {
        final d = PolyOps.degree(part.$1);
        if (d <= 2) {
          final fs = _lowDegree(part.$1, part.$2);
          if (fs.any((f) => f.poly.c.any((c) => c is SurdCoef && c.d != 1))) {
            bump(FactorLevel.exactRadical);
          }
          out.addAll(fs);
        } else {
          out.addAll(_numeric(part.$1, part.$2));
          bump(FactorLevel.numeric);
        }
      }
      if (level == FactorLevel.numeric) {
        notes.add('Nivel 2: no hay más raíces racionales ni identidad notable, así que calculamos '
            'todas las raíces complejas con el método de Aberth-Ehrlich (tolerancia 10⁻¹²). '
            'Cada pareja de raíces conjugadas a ± bi da un factor real x² − 2a·x + (a² + b²).');
      } else if (PolyOps.degree(rest) == 2) {
        notes.add('El factor de grado 2 restante se estudia con su discriminante Δ = p² − 4q: '
            'si Δ < 0 es irreducible en los reales.');
      }
    }
    return RealFactorization(_r(lc), _merge(out), level, notes.join(' '));
  }

  static List<RealFactor> _merge(List<RealFactor> fs) {
    final byKey = <String, RealFactor>{};
    for (final f in fs) {
      final k = f.poly.latex();
      final prev = byKey[k];
      byKey[k] = RealFactor(f.poly, f.multiplicity + (prev?.multiplicity ?? 0));
    }
    final list = byKey.values.toList()
      ..sort((a, b) {
        if (a.poly.degree != b.poly.degree) return a.poly.degree - b.poly.degree;
        return a.poly[0].v.compareTo(b.poly[0].v);
      });
    return list;
  }

  // ------------------------------------------------------------ Nivel 1

  static Rational? _ratRoot(Rational r, int n) {
    int? iroot(int v) {
      final k = math.pow(v, 1 / n).round();
      for (final c in [k - 1, k, k + 1]) {
        if (c >= 0 && math.pow(c, n) == v) return c;
      }
      return null;
    }

    final a = iroot(r.numerator.abs());
    final b = iroot(r.denominator);
    return a == null || b == null ? null : Rational(a, b);
  }

  static CPoly _quad(Coef p, Coef q) => CPoly([q, p, Coef.one]);

  /// x^n ± a^n con n = 4, 5, 6 (monico, solo dos terminos).
  static ({List<RealFactor> factors, String note})? _family(Poly m) {
    final n = PolyOps.degree(m);
    if (n < 4 || n > 6 || m.length != 2 || !m.containsKey(0)) return null;
    final c0 = PolyOps.coeff(m, 0);
    final a = _ratRoot(c0.abs(), n);
    if (a == null) return null;
    final ac = _r(a);
    final a2 = _r(a * a);
    RealFactor f(CPoly p) => RealFactor(p, 1);
    if (n == 4 && c0.isPositive) {
      return (
        factors: [f(_quad(-_sqrt2 * ac, a2)), f(_quad(_sqrt2 * ac, a2))],
        note: 'Nivel 1 (Sophie Germain): x⁴ + a⁴ = (x² + a²)² − 2a²x² es una diferencia de '
            'cuadrados, así que se factoriza con √2 sin aproximar.',
      );
    }
    if (n == 5) {
      final s = c0.isPositive ? Coef.one : -Coef.one;
      return (
        factors: [
          f(CPoly.linear(-s * ac)),
          f(_quad(-s * _phi * ac, a2)),
          f(_quad(-s * _psi * ac, a2)),
        ],
        note: 'Nivel 1 (raíces quintas): x⁵ ${c0.isPositive ? '+' : '−'} a⁵ tiene una raíz real '
            'y cuatro complejas conjugadas. Al emparejarlas aparecen 2·cos(36°) = (1 + √5)/2 '
            '(el número áureo) y 2·cos(108°) = (1 − √5)/2.',
      );
    }
    if (n == 6) {
      if (c0.isPositive) {
        return (
          factors: [
            f(_quad(Coef.zero, a2)),
            f(_quad(-_sqrt3 * ac, a2)),
            f(_quad(_sqrt3 * ac, a2)),
          ],
          note: 'Nivel 1: x⁶ + a⁶ = (x²)³ + (a²)³ es una suma de cubos, y el factor de grado 4 '
              'se parte como diferencia de cuadrados con √3.',
        );
      }
      return (
        factors: [
          f(CPoly.linear(ac)),
          f(CPoly.linear(-ac)),
          f(_quad(ac, a2)),
          f(_quad(-ac, a2)),
        ],
        note: 'Nivel 1: x⁶ − a⁶ = (x³ − a³)(x³ + a³), diferencia y suma de cubos.',
      );
    }
    return null;
  }

  /// Factor monico de grado 1 o 2 con coeficientes racionales.
  static List<RealFactor> _lowDegree(Poly p, int mult) {
    if (PolyOps.degree(p) == 1) {
      return [RealFactor(CPoly.linear(_r(-PolyOps.coeff(p, 0))), mult)];
    }
    final b = PolyOps.coeff(p, 1);
    final c = PolyOps.coeff(p, 0);
    final disc = b * b - Rational(4) * c;
    if (disc.isNegative) return [RealFactor(_quad(_r(b), _r(c)), mult)];
    final half = _r(Rational(-1, 2) * b);
    if (disc.isZero) return [RealFactor(CPoly.linear(half), 2 * mult)];
    final s = _r(disc).exactSqrt()! * _r(Rational(1, 2));
    return [
      RealFactor(CPoly.linear(half - s), mult),
      RealFactor(CPoly.linear(half + s), mult),
    ];
  }

  // ------------------------------------------------- utilidades racionales

  static Poly _deriv(Poly p) =>
      PolyOps.clean({for (final e in p.entries) if (e.key > 0) e.key - 1: e.value * Rational(e.key)});

  static Poly _monic(Poly p) => PolyOps.scale(p, Rational(1) / PolyOps.coeff(p, PolyOps.degree(p)));

  /// Division larga de polinomios racionales: (cociente, resto).
  static (Poly, Poly) divMod(Poly a, Poly b) {
    var r = PolyOps.clean(a);
    final db = PolyOps.degree(b);
    final lb = PolyOps.coeff(b, db);
    final q = <int, Rational>{};
    while (PolyOps.degree(r) >= db && r.isNotEmpty) {
      final dr = PolyOps.degree(r);
      final t = PolyOps.coeff(r, dr) / lb;
      q[dr - db] = t;
      r = PolyOps.sub(r, PolyOps.mul({dr - db: t}, b));
    }
    return (PolyOps.clean(q), r);
  }

  static bool _huge(Poly p) => p.values.any((c) => c.numerator.abs() > (1 << 40) || c.denominator > (1 << 40));

  /// m.c.d. monico (Euclides). Si los coeficientes se disparan devuelve 1.
  static Poly gcd(Poly a, Poly b) {
    var x = PolyOps.clean(a);
    var y = PolyOps.clean(b);
    while (y.isNotEmpty) {
      final r = divMod(x, y).$2;
      x = y;
      y = r;
      if (_huge(y)) return PolyOps.constant(Rational(1));
    }
    return x.isEmpty ? PolyOps.constant(Rational(1)) : _monic(x);
  }

  /// Descomposicion libre de cuadrados (Yun/Musser): [(parte, multiplicidad)].
  static List<(Poly, int)> _squareFree(Poly f) {
    final out = <(Poly, int)>[];
    var c = gcd(f, _deriv(f));
    var w = divMod(f, c).$1;
    var i = 1;
    while (PolyOps.degree(w) > 0 && i < 20) {
      final y = gcd(w, c);
      final z = divMod(w, y).$1;
      if (PolyOps.degree(z) > 0) out.add((_monic(z), i));
      i++;
      w = y;
      c = divMod(c, y).$1;
    }
    return out.isEmpty ? [(f, 1)] : out;
  }

  // ------------------------------------------------------------ Nivel 2

  static List<RealFactor> _numeric(Poly p, int mult) {
    final out = <RealFactor>[];
    for (final z in aberth(p)) {
      if (z.im.abs() < 1e-8 * (1 + z.re.abs())) {
        out.add(RealFactor(CPoly.linear(Coef.snap(z.re)), mult));
      } else if (z.im > 0) {
        final quad = CPoly([Coef.snap(z.re * z.re + z.im * z.im), Coef.snap(-2 * z.re), Coef.one]);
        out.add(RealFactor(quad, mult));
      }
    }
    return out;
  }

  /// Todas las raices complejas de un polinomio libre de cuadrados (Aberth-Ehrlich).
  static List<({double re, double im})> aberth(Poly p, {double tol = 1e-12, int maxIter = 200}) {
    final n = PolyOps.degree(p);
    final lc = PolyOps.coeff(p, n).toDouble();
    final a = [for (var k = 0; k <= n; k++) PolyOps.coeff(p, k).toDouble() / lc];
    var r = 0.0;
    for (var k = 0; k < n; k++) {
      r = math.max(r, math.pow(a[k].abs(), 1 / (n - k)).toDouble());
    }
    r = math.max(r, 0.5);
    final z = [
      for (var k = 0; k < n; k++) _Cx.polar(r, 2 * math.pi * k / n + 0.4),
    ];
    (_Cx, _Cx) eval(_Cx x) {
      var v = const _Cx(0, 0);
      var d = const _Cx(0, 0);
      for (var k = n; k >= 0; k--) {
        d = d * x + v;
        v = v * x + _Cx(a[k], 0);
      }
      return (v, d);
    }

    for (var it = 0; it < maxIter; it++) {
      var maxStep = 0.0;
      for (var k = 0; k < n; k++) {
        final (v, d) = eval(z[k]);
        if (v.abs == 0) continue;
        final ratio = v / d;
        var s = const _Cx(0, 0);
        for (var j = 0; j < n; j++) {
          if (j != k) s = s + const _Cx(1, 0) / (z[k] - z[j]);
        }
        final w = ratio / (const _Cx(1, 0) - ratio * s);
        z[k] = z[k] - w;
        maxStep = math.max(maxStep, w.abs / (1 + z[k].abs));
      }
      if (maxStep < tol) break;
    }
    for (var k = 0; k < n; k++) {
      for (var i = 0; i < 2; i++) {
        final (v, d) = eval(z[k]);
        if (d.abs > 0) z[k] = z[k] - v / d;
      }
    }
    return [for (final c in z) (re: c.re, im: c.im)];
  }
}

/// Numero complejo minimo para Aberth.
class _Cx {
  final double re;
  final double im;
  const _Cx(this.re, this.im);
  factory _Cx.polar(double r, double t) => _Cx(r * math.cos(t), r * math.sin(t));
  double get abs => math.sqrt(re * re + im * im);
  _Cx operator +(_Cx o) => _Cx(re + o.re, im + o.im);
  _Cx operator -(_Cx o) => _Cx(re - o.re, im - o.im);
  _Cx operator *(_Cx o) => _Cx(re * o.re - im * o.im, re * o.im + im * o.re);
  _Cx operator /(_Cx o) {
    final den = o.re * o.re + o.im * o.im;
    return _Cx((re * o.re + im * o.im) / den, (im * o.re - re * o.im) / den);
  }
}
