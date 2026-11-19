import 'dart:math' as math;

import '../core/rational.dart';
import 'real_coef.dart';

/// Sumando de la primitiva de una funcion racional: valor numerico + LaTeX.
sealed class PrimTerm {
  const PrimTerm();
  double eval(double x);

  /// LaTeX con signo (`+ ...`/`- ...`, o sin signo inicial si [first]).
  String latex({required bool first});
}

String _paren(CPoly p) {
  final s = p.latex();
  return s == 'x' ? 'x' : '\\left($s\\right)';
}

/// `± k / poly^e` como una sola fraccion.
String overFactor(Coef k, CPoly poly, int e, {required bool first}) {
  final den = e == 1 ? poly.latex() : '${_paren(poly)}^{$e}';
  return k.overTerm(den, e == 1 ? _paren(poly) : den, first: first);
}

/// Primitiva del cociente polinomico C(x).
class PolyPrim extends PrimTerm {
  final CPoly poly;
  const PolyPrim(this.poly);

  @override
  double eval(double x) => poly.evalD(x);

  @override
  String latex({required bool first}) {
    final buf = StringBuffer();
    var f = first;
    for (var k = poly.c.length - 1; k >= 0; k--) {
      if (poly.c[k].isZero) continue;
      buf.write(poly.c[k].signedTerm(k == 0 ? '' : (k == 1 ? 'x' : 'x^{$k}'), first: f));
      f = false;
    }
    return buf.toString();
  }
}

/// A · ln|x - r|
class LnLinear extends PrimTerm {
  final Coef a;
  final Coef r;
  const LnLinear(this.a, this.r);

  @override
  double eval(double x) => a.v * math.log((x - r.v).abs());

  @override
  String latex({required bool first}) =>
      a.signedTerm('\\ln\\left|${CPoly.linear(r).latex()}\\right|', first: first);
}

/// k / (x - r)^e
class PowLinear extends PrimTerm {
  final Coef k;
  final Coef r;
  final int e;
  const PowLinear(this.k, this.r, this.e);

  @override
  double eval(double x) => k.v / math.pow(x - r.v, e);

  @override
  String latex({required bool first}) => overFactor(k, CPoly.linear(r), e, first: first);
}

/// k · ln(x^2 + px + q)  (el trinomio es siempre positivo)
class LnQuad extends PrimTerm {
  final Coef k;
  final CPoly quad;
  const LnQuad(this.k, this.quad);

  @override
  double eval(double x) => k.v * math.log(quad.evalD(x));

  @override
  String latex({required bool first}) =>
      k.signedTerm('\\ln\\left(${quad.latex()}\\right)', first: first);
}

/// k · numer(x) / (x^2 + px + q)^e  (reduccion para potencias k > 1)
class QuadFrac extends PrimTerm {
  final Coef k;
  final CPoly numer;
  final CPoly quad;
  final int e;
  const QuadFrac(this.k, this.numer, this.quad, this.e);

  @override
  double eval(double x) => k.v * numer.evalD(x) / math.pow(quad.evalD(x), e);

  @override
  String latex({required bool first}) {
    if (numer.degree <= 0) return overFactor(k * numer[0], quad, e, first: first);
    final den = e == 1 ? quad.latex() : '${_paren(quad)}^{$e}';
    return k.signedTerm('\\frac{${numer.latex()}}{$den}', first: first);
  }
}

/// ∫ M / (x^2 + px + q) dx = 2M/sqrt(D) · arctan((2x + p)/sqrt(D)),  D = 4q - p^2.
class AtanQuad extends PrimTerm {
  final Coef m;
  final CPoly quad;
  AtanQuad(this.m, this.quad);

  Coef get p => quad[1];
  Coef get d => Coef.integer(4) * quad[0] - p * p;
  double get _s => math.sqrt(d.v);

  @override
  double eval(double x) => 2 * m.v / _s * math.atan((2 * x + p.v) / _s);

  static bool _ok(Coef r, List<Coef> ins) => r is SurdCoef || ins.any((i) => i is DecCoef);

  /// sqrt(D) exacta en el mismo cuerpo, o `null` (se escribe como raiz anidada).
  Coef? get exactRoot {
    final dd = d;
    if (dd is SurdCoef && dd.asRational == null) return null;
    return dd.exactSqrt();
  }

  @override
  String latex({required bool first}) {
    final two = Coef.integer(2);
    final m2 = two * m;
    final s = exactRoot;
    if (s != null) {
      final c = m2 / s;
      final arg = CPoly([p / s, two / s]);
      if (_ok(c, [m2, s]) && arg.c.every((e) => _ok(e, [p, s]))) {
        return c.signedTerm('\\arctan\\left(${arg.latex()}\\right)', first: first);
      }
    }
    final sl = s != null && s is SurdCoef ? s.latex() : '\\sqrt{${d.latex()}}';
    final fp = m2.fracParts();
    final lin = CPoly([p, two]).latex();
    final den = fp.den == 1 ? sl : '${fp.den}$sl';
    final body = '\\frac{${fp.num}}{$den}\\arctan\\left(\\frac{$lin}{$sl}\\right)';
    if (first) return fp.neg ? '-$body' : body;
    return fp.neg ? ' - $body' : ' + $body';
  }
}

/// F(x) = suma de sumandos.
class RationalPrimitive {
  final List<PrimTerm> terms;
  const RationalPrimitive(this.terms);

  double eval(double x) => terms.fold(0.0, (s, t) => s + t.eval(x));

  String latex() {
    final buf = StringBuffer();
    var first = true;
    for (final t in terms) {
      final s = t.latex(first: first);
      if (s.isEmpty) continue;
      buf.write(s);
      first = false;
    }
    return first ? '0' : buf.toString();
  }
}

/// Atajos racionales.
Coef cr(int n, [int d = 1]) => Coef.rat(Rational(n, d));
