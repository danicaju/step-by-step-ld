import '../../core/rational.dart';
import '../equations/eq_poly.dart';
import '../exact/exact_number.dart';
import '../exact/ext_evaluator.dart';
import '../exact/ext_expr.dart';
import '../trig_and_angles_solver.dart';

/// Constructores con simplificacion basica sobre [XNode] para el calculo simbolico.
class Sx {
  const Sx._();

  static final XNode zero = XNum(Rational(0));
  static final XNode one = XNum(Rational(1));
  static const XNode x = XVar('X');

  static XNode num(int n, [int d = 1]) => XNum(Rational(n, d));
  static XNode rat(Rational r) => XNum(r);

  static Rational? numVal(XNode n) => switch (n) {
        XNum(:final value) => value,
        XNeg(:final a) => numVal(a) == null ? null : -numVal(a)!,
        _ => null,
      };

  static bool isNum(XNode n, int v) => numVal(n) == Rational(v);
  static bool hasX(XNode n) => PolyOps.containsX(n);

  static XNode neg(XNode a) {
    final v = numVal(a);
    if (v != null) return XNum(-v);
    if (a is XNeg) return a.a;
    if (a is XBin && a.op == '*') {
      final c = numVal(a.l);
      if (c != null) return mul(XNum(-c), a.r);
    }
    return XNeg(a);
  }

  static XNode add(XNode a, XNode b) {
    if (isNum(a, 0)) return b;
    if (isNum(b, 0)) return a;
    final va = numVal(a);
    final vb = numVal(b);
    if (va != null && vb != null) return XNum(va + vb);
    return XBin(a, '+', b);
  }

  static XNode sub(XNode a, XNode b) {
    if (isNum(b, 0)) return a;
    if (isNum(a, 0)) return neg(b);
    final va = numVal(a);
    final vb = numVal(b);
    if (va != null && vb != null) return XNum(va - vb);
    if (b is XBin && b.op == '+') return sub(sub(a, b.l), b.r);
    if (b is XBin && b.op == '-') return add(sub(a, b.l), b.r);
    return XBin(a, '-', b);
  }

  static XNode mul(XNode a, XNode b) {
    if (isNum(a, 0) || isNum(b, 0)) return zero;
    if (isNum(a, 1)) return b;
    if (isNum(b, 1)) return a;
    if (a is XNeg) return neg(mul(a.a, b));
    if (b is XNeg) return neg(mul(a, b.a));
    final va = numVal(a);
    final vb = numVal(b);
    if (va != null && vb != null) return XNum(va * vb);
    final aFrac = a is XBin && a.op == '/';
    final bFrac = b is XBin && b.op == '/';
    if (aFrac && !bFrac) return div(mul(a.l, b), a.r);
    if (bFrac && !aFrac) return div(mul(a, b.l), b.r);
    if (vb != null) return mul(b, a);
    if (_alg(b) && !_alg(a) && va == null) return XBin(b, '*', a);
    if (va != null && b is XBin && b.op == '*') {
      final inner = numVal(b.l);
      if (inner != null) return mul(XNum(va * inner), b.r);
    }
    return XBin(a, '*', b);
  }

  static bool _alg(XNode n) =>
      n is XVar ||
      (n is XPow && n.base is XVar && numVal(n.exp) != null) ||
      (n is XBin && n.op == '*' && numVal(n.l) != null && _alg(n.r));

  static XNode div(XNode a, XNode b) {
    if (isNum(a, 0)) return zero;
    if (isNum(b, 1)) return a;
    if (hasX(a) && a.latex() == b.latex()) return one;
    // x^k / x  y  x / x^k
    if (b is XVar && a is XPow && a.base is XVar && numVal(a.exp) != null) {
      return powR(x, numVal(a.exp)! - Rational(1));
    }
    if (a is XVar && b is XPow && b.base is XVar && numVal(b.exp) != null) {
      return powR(x, Rational(1) - numVal(b.exp)!);
    }
    final vb = numVal(b);
    if (vb != null && !vb.isZero) return mul(XNum(vb.pow(-1)), a);
    if (a is XNeg) return neg(div(a.a, b));
    if (a is XBin && a.op == '*' && numVal(a.l) != null) {
      final inner = div(a.r, b);
      if (!(inner is XBin && inner.op == '/')) return mul(a.l, inner);
    }
    return XBin(a, '/', b);
  }

  static XNode pow(XNode a, XNode e) {
    final ve = numVal(e);
    if (ve != null) {
      if (ve.isZero) return one;
      if (ve == Rational(1)) return a;
      final va = numVal(a);
      if (va != null && ve.isInteger && ve.numerator.abs() <= 12 && !(va.isZero && ve.isNegative)) {
        return XNum(va.pow(ve.numerator));
      }
    }
    return XPow(a, e);
  }

  static XNode powR(XNode a, Rational r) => pow(a, XNum(r));

  /// Sustituye todo subarbol que cumpla [match] por [with].
  static XNode subst(XNode n, bool Function(XNode) match, XNode with_) {
    if (match(n)) return with_;
    XNode s(XNode c) => subst(c, match, with_);
    return switch (n) {
      XNeg(:final a) => XNeg(s(a)),
      XBin(:final l, :final op, :final r) => XBin(s(l), op, s(r)),
      XPow(:final base, :final exp) => XPow(s(base), s(exp)),
      XRoot(:final index, :final rad) => XRoot(index == null ? null : s(index), s(rad)),
      XAbs(:final a) => XAbs(s(a)),
      XFn(:final name, :final arg, :final base) =>
        XFn(name, s(arg), base: base == null ? null : s(base)),
      _ => n,
    };
  }

  /// Valor de [n] en x = [v] (exacto) o `null` si no esta definido.
  static ExNum? evalAt(XNode n, ExNum v, {AngleUnit angle = AngleUnit.rad}) {
    try {
      return ExtEvaluator(angle: angle, xValue: v).eval(n);
    } on FormatException {
      return null;
    }
  }

  /// Valor numerico (double) en x = v; `null` si no esta definido.
  static double? numAt(XNode n, double v, {AngleUnit angle = AngleUnit.rad}) {
    try {
      final r = ExtEvaluator(angle: angle, xValue: ExNum.opaque('x', v)).eval(n);
      final a = r.approx;
      return a.isNaN || a.isInfinite ? null : a;
    } on FormatException {
      return null;
    }
  }

  /// Reconstruye el arbol plegando constantes con los constructores.
  static XNode rebuild(XNode n) {
    switch (n) {
      case XNeg(:final a):
        return neg(rebuild(a));
      case XBin(:final l, :final op, :final r):
        final a = rebuild(l);
        final b = rebuild(r);
        return switch (op) {
          '+' => add(a, b),
          '-' => sub(a, b),
          '*' => mul(a, b),
          _ => div(a, b),
        };
      case XPow(:final base, :final exp):
        return pow(rebuild(base), rebuild(exp));
      case XAbs(:final a):
        final v = numVal(rebuild(a));
        return v == null ? XAbs(rebuild(a)) : XNum(v.abs());
      case XFn(:final name, :final arg, :final base):
        final a = rebuild(arg);
        final v = numVal(a);
        if (v != null && base == null) {
          if (name == 'ln' && v == Rational(1)) return zero;
          if (name == 'sin' && v.isZero) return zero;
          if (name == 'cos' && v.isZero) return one;
          if (name == 'tan' && v.isZero) return zero;
          if (name == 'atan' && v.isZero) return zero;
        }
        if (v != null && base == null) {
          final ev = Sx.evalAt(XFn(name, a), ExNum.integer(0));
          if (ev != null && ev.isExact) return fromExact(ev);
        }
        return XFn(name, a, base: base == null ? null : rebuild(base));
      case XRoot(:final index, :final rad):
        return XRoot(index, rebuild(rad));
      default:
        return n;
    }
  }

  /// Suma terminos semejantes (coeficiente * nucleo) de una suma/resta.
  static XNode collectSum(XNode n) {
    final order = <String>[];
    final cores = <String, XNode>{};
    final coefs = <String, Rational>{};
    var constant = Rational(0);
    void walk(XNode t, Rational sign) {
      if (t is XBin && (t.op == '+' || t.op == '-')) {
        walk(t.l, sign);
        walk(t.r, t.op == '+' ? sign : -sign);
      } else if (t is XNeg) {
        walk(t.a, -sign);
      } else if (numVal(t) != null) {
        constant = constant + sign * numVal(t)!;
      } else {
        var c = Rational(1);
        var core = t;
        if (t is XBin && t.op == '*' && numVal(t.l) != null) {
          c = numVal(t.l)!;
          core = t.r;
        }
        final key = core.latex();
        cores[key] = core;
        if (!coefs.containsKey(key)) order.add(key);
        coefs[key] = (coefs[key] ?? Rational(0)) + sign * c;
      }
    }

    walk(n, Rational(1));
    XNode acc = zero;
    for (final k in order) {
      final c = coefs[k]!;
      if (c.isZero) continue;
      final term = mul(XNum(c.abs()), cores[k]!);
      if (isNum(acc, 0)) {
        acc = c.isNegative ? neg(term) : term;
      } else {
        acc = c.isNegative ? sub(acc, term) : add(acc, term);
      }
    }
    if (!constant.isZero) {
      acc = isNum(acc, 0)
          ? XNum(constant)
          : (constant.isNegative ? sub(acc, XNum(-constant)) : add(acc, XNum(constant)));
    }
    return acc;
  }

  /// Convierte un [ExNum] exacto en un arbol simbolico.
  static XNode fromExact(ExNum v) {
    XNode acc = zero;
    for (final e in v.terms.entries) {
      final (r, p, k) = e.key;
      XNode t = XNum(e.value.abs());
      if (r > 1) t = mul(t, XRoot(null, num(r)));
      if (p != 0) t = mul(t, pow(const XConst('pi'), num(p)));
      if (k != 0) t = mul(t, pow(const XConst('e'), num(k)));
      if (isNum(acc, 0)) {
        acc = e.value.isNegative ? neg(t) : t;
      } else {
        acc = e.value.isNegative ? sub(acc, t) : add(acc, t);
      }
    }
    return acc;
  }
}
