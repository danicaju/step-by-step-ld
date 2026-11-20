import '../../core/rational.dart';
import '../equations/eq_poly.dart';
import '../exact/ext_evaluator.dart';
import '../exact/ext_expr.dart';
import '../trig_and_angles_solver.dart';
import 'integral_table_ext.dart';
import 'sym_build.dart';

/// Tabla de integrales inmediatas (con argumento lineal `ax + b`) y linealidad
/// sobre polinomios. Devuelve una primitiva sin la constante C, o `null`.
class IntegralTable {
  const IntegralTable._();

  static Rational? constValue(XNode n) {
    if (Sx.hasX(n)) return null;
    try {
      return ExtEvaluator(angle: AngleUnit.rad).eval(n).asRational;
    } on FormatException {
      return null;
    }
  }

  /// `u = a x + b` con a != 0 -> (a, b).
  static (Rational, Rational)? linear(XNode u) {
    final p = PolyOps.polyOf(u);
    if (p == null || PolyOps.degree(p) != 1) return null;
    return (PolyOps.coeff(p, 1), PolyOps.coeff(p, 0));
  }

  static XNode _byA(XNode g, Rational a) => Sx.div(g, Sx.rat(a));

  static XNode _lnAbs(XNode u) => XFn('ln', XAbs(u));

  /// Primitiva de un polinomio termino a termino.
  static XNode polyAntiderivative(Poly p) {
    final keys = p.keys.toList()..sort((a, b) => b.compareTo(a));
    XNode acc = Sx.zero;
    for (final k in keys) {
      final c = p[k]! / Rational(k + 1);
      final term = Sx.mul(Sx.rat(c), Sx.powR(Sx.x, Rational(k + 1)));
      acc = Sx.add(acc, term);
    }
    return acc;
  }

  static XNode? lookup(XNode f) {
    switch (f) {
      case XVar():
        return polyAntiderivative(PolyOps.polyOf(f)!);
      case XPow(:final base, :final exp):
        return _pow(f, base, exp);
      case XRoot(:final index, :final rad):
        final lin = linear(rad);
        final n = index == null ? Rational(2) : constValue(index);
        if (lin == null || n == null || (n - Rational(2)).isNegative) return null;
        final e = Rational(1) / n;
        return _byA(Sx.mul(Sx.rat(Rational(1) / (e + Rational(1))), Sx.powR(rad, e + Rational(1))), lin.$1);
      case XFn():
        return _fn(f);
      case XBin(:final l, :final op, :final r) when op == '/':
        return _quotient(l, r);
      default:
        return PolyOps.polyOf(f) != null ? polyAntiderivative(PolyOps.polyOf(f)!) : null;
    }
  }

  static XNode? _pow(XNode f, XNode base, XNode exp) {
    final n = constValue(exp);
    if (n != null) {
      final lin = linear(base);
      if (lin != null) {
        if (n == Rational(-1)) return _byA(_lnAbs(base), lin.$1);
        final k = n + Rational(1);
        return _byA(Sx.mul(Sx.rat(Rational(1) / k), Sx.powR(base, k)), lin.$1);
      }
      if (base is XFn && n == Rational(2)) {
        final lin2 = linear(base.arg);
        if (lin2 == null) return null;
        final u = base.arg;
        final twoU = Sx.mul(Sx.num(2), u);
        if (base.name == 'sin') {
          return _byA(
            Sx.sub(Sx.div(u, Sx.num(2)), Sx.div(XFn('sin', twoU), Sx.num(4))),
            lin2.$1,
          );
        }
        if (base.name == 'cos') {
          return _byA(
            Sx.add(Sx.div(u, Sx.num(2)), Sx.div(XFn('sin', twoU), Sx.num(4))),
            lin2.$1,
          );
        }
      }
      return PolyOps.polyOf(f) != null ? polyAntiderivative(PolyOps.polyOf(f)!) : null;
    }
    if (!Sx.hasX(base)) {
      final lin = linear(exp);
      if (lin == null) return null;
      if (base is XConst && base.kind == 'e') return _byA(f, lin.$1);
      final lnA = XFn('ln', base);
      return Sx.div(f, Sx.mul(Sx.rat(lin.$1), lnA));
    }
    return null;
  }

  static XNode? _fn(XFn f) {
    final lin = linear(f.arg);
    if (lin == null) return null;
    final u = f.arg;
    final a = lin.$1;
    switch (f.name) {
      case 'sin':
        return _byA(Sx.neg(XFn('cos', u)), a);
      case 'cos':
        return _byA(XFn('sin', u), a);
      case 'tan':
        return _byA(Sx.neg(_lnAbs(XFn('cos', u))), a);
      case 'ln':
        return _byA(Sx.sub(Sx.mul(u, XFn('ln', u)), u), a);
      default:
        return IntegralTableExt.fn(f, a);
    }
  }

  static XNode? _quotient(XNode num, XNode den) {
    final c = constValue(num);
    if (c == null) {
      // (a + b + ...) / monomio: se reparte el denominador.
      return null;
    }
    if (c.isZero) return Sx.zero;
    final lin = linear(den);
    if (lin != null) return Sx.mul(Sx.rat(c), _byA(_lnAbs(den), lin.$1));
    if (den is XPow) {
      final k = constValue(den.exp);
      final l2 = linear(den.base);
      if (k != null && l2 != null) {
        if (k == Rational(1)) return Sx.mul(Sx.rat(c), _byA(_lnAbs(den.base), l2.$1));
        final e = Rational(1) - k;
        return Sx.mul(
          Sx.rat(c),
          _byA(Sx.mul(Sx.rat(Rational(1) / e), Sx.powR(den.base, e)), l2.$1),
        );
      }
      if (k == Rational(2) && den.base is XFn) {
        final fn = den.base as XFn;
        final l3 = linear(fn.arg);
        if (fn.name == 'cos' && l3 != null) {
          return Sx.mul(Sx.rat(c), _byA(XFn('tan', fn.arg), l3.$1));
        }
        if (l3 != null) return IntegralTableExt.coshSquared(c, fn, l3.$1);
      }
    }
    if (den is XRoot) {
      final l2 = linear(den.rad);
      final nIdx = den.index == null ? Rational(2) : constValue(den.index!);
      final isSqrt = nIdx == Rational(2);
      if (l2 != null && isSqrt) {
        return Sx.mul(Sx.rat(c * Rational(2)), _byA(den, l2.$1));
      }
      if (l2 != null && nIdx != null) {
        final r = IntegralTableExt.inverseRoot(c, nIdx, den.rad, l2.$1);
        if (r != null) return r;
      }
      final p = PolyOps.polyOf(den.rad);
      // 1 / sqrt(a0 - a2 x^2) = (1/sqrt(a2)) arcsin(sqrt(a2/a0) x)
      if (p != null && isSqrt) return IntegralTableExt.arcsinForm(c, p);
    }
    // c / (p2 x^2 + p0) = c / (p2 k) arctan(x / k)
    final p = PolyOps.polyOf(den);
    if (p != null && PolyOps.degree(p) == 2 && PolyOps.coeff(p, 1).isZero) {
      final p2 = PolyOps.coeff(p, 2);
      final p0 = PolyOps.coeff(p, 0);
      final q = p0 / p2;
      if (q.isPositive) {
        final k = _ratSqrt(q);
        if (k != null) {
          final coef = c / (p2 * k);
          final arg = k == Rational(1) ? Sx.x : Sx.div(Sx.x, Sx.rat(k));
          return Sx.mul(Sx.rat(coef), XFn('atan', arg));
        }
        return IntegralTableExt.arctanIrrational(c, p);
      }
    }
    return null;
  }

  static Rational? _ratSqrt(Rational r) {
    int? root(int n) {
      var k = 0;
      while (k * k < n) {
        k++;
      }
      return k * k == n ? k : null;
    }

    final a = root(r.numerator.abs());
    final b = root(r.denominator);
    return (a == null || b == null) ? null : Rational(a, b);
  }
}
