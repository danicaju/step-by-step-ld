import '../../core/rational.dart';
import '../equations/eq_poly.dart';
import '../exact/ext_expr.dart';
import 'sym_build.dart';

/// Ampliacion de la tabla de integrales inmediatas: hiperbolicas, logaritmo en base `b`,
/// raices n-esimas en el denominador y formas que dan arcsen / arctg con `a` general.
class IntegralTableExt {
  const IntegralTableExt._();

  static XNode _byA(XNode g, Rational a) => Sx.div(g, Sx.rat(a));

  /// Primitiva de `sinh`, `cosh`, `tanh` y `log_b` con argumento lineal `ax + b` (a = [a]).
  static XNode? fn(XFn f, Rational a) {
    final u = f.arg;
    switch (f.name) {
      case 'sinh':
        return _byA(XFn('cosh', u), a);
      case 'cosh':
        return _byA(XFn('sinh', u), a);
      case 'tanh':
        return _byA(XFn('ln', XFn('cosh', u)), a);
      case 'log':
        final lnB = XFn('ln', f.base ?? Sx.num(10));
        return _byA(Sx.div(Sx.sub(Sx.mul(u, XFn('ln', u)), u), lnB), a);
      default:
        return null;
    }
  }

  /// `c / cosh^2(ax+b)` -> `c · tanh(ax+b) / a`.
  static XNode? coshSquared(Rational c, XFn fn, Rational a) {
    if (fn.name != 'cosh') return null;
    return Sx.mul(Sx.rat(c), _byA(XFn('tanh', fn.arg), a));
  }

  /// `c / ⁿ√(ax+b)` con n >= 3: `c · n/(n-1) · (ax+b)^((n-1)/n) / a`.
  static XNode? inverseRoot(Rational c, Rational n, XNode rad, Rational a) {
    if (!n.isInteger || n.numerator < 3) return null;
    final e = Rational(n.numerator - 1, n.numerator);
    return Sx.mul(Sx.rat(c), _byA(Sx.mul(Sx.rat(e.pow(-1)), Sx.powR(rad, e)), a));
  }

  static Rational? _ratSqrt(Rational r) {
    if (r.isNegative) return null;
    int? root(int n) {
      var k = 0;
      while (k * k < n) {
        k++;
      }
      return k * k == n ? k : null;
    }

    final p = root(r.numerator.abs());
    final q = root(r.denominator);
    return (p == null || q == null) ? null : Rational(p, q);
  }

  /// `c / √(a0 + a2 x²)` con a2 < 0 < a0: `c/√(-a2) · arcsin(√(-a2/a0)·x)`.
  static XNode? arcsinForm(Rational c, Poly p) {
    if (PolyOps.degree(p) != 2 || !PolyOps.coeff(p, 1).isZero) return null;
    final a2 = PolyOps.coeff(p, 2);
    final a0 = PolyOps.coeff(p, 0);
    if (!a2.isNegative || !a0.isPositive) return null;
    final root = _ratSqrt(-a2);
    final s = _ratSqrt(-a2 / a0);
    if (root == null || s == null) return null;
    final arg = s == Rational(1) ? Sx.x : Sx.mul(Sx.rat(s), Sx.x);
    return Sx.mul(Sx.rat(c / root), XFn('asin', arg));
  }

  /// `c / (p2 x² + p0)` con p0/p2 > 0 no cuadrado perfecto: `c/(p2 √q) · arctan(x/√q)`.
  static XNode? arctanIrrational(Rational c, Poly p) {
    if (PolyOps.degree(p) != 2 || !PolyOps.coeff(p, 1).isZero) return null;
    final p2 = PolyOps.coeff(p, 2);
    final p0 = PolyOps.coeff(p, 0);
    final q = p0 / p2;
    if (!q.isPositive) return null;
    final root = XRoot(null, Sx.rat(q));
    return Sx.mul(
      Sx.div(Sx.rat(c / p2), root),
      XFn('atan', Sx.div(Sx.x, root)),
    );
  }
}
