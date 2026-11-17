import 'dart:math' as math;

import '../../core/rational.dart';
import '../exact/exact_number.dart';
import '../exact/ext_expr.dart';
import '../exact/ext_math.dart';

/// Polinomio en una variable: exponente -> coeficiente racional.
typedef Poly = Map<int, Rational>;

/// Aritmetica de polinomios racionales y extraccion desde el AST.
class PolyOps {
  const PolyOps._();

  static Poly clean(Poly p) {
    final out = <int, Rational>{};
    p.forEach((k, v) {
      if (!v.isZero) out[k] = v.simplify();
    });
    return out;
  }

  static Poly constant(Rational r) => clean({0: r});
  static Poly x([int power = 1]) => {power: Rational(1)};

  static int degree(Poly p) {
    final c = clean(p);
    return c.isEmpty ? -1 : c.keys.reduce(math.max);
  }

  static Rational coeff(Poly p, int k) => p[k] ?? Rational(0);

  static Poly add(Poly a, Poly b) {
    final m = Poly.of(a);
    b.forEach((k, v) => m[k] = (m[k] ?? Rational(0)) + v);
    return clean(m);
  }

  static Poly neg(Poly a) => {for (final e in a.entries) e.key: -e.value};
  static Poly sub(Poly a, Poly b) => add(a, neg(b));

  static Poly scale(Poly a, Rational r) =>
      clean({for (final e in a.entries) e.key: e.value * r});

  static Poly mul(Poly a, Poly b) {
    final m = <int, Rational>{};
    for (final x in a.entries) {
      for (final y in b.entries) {
        m[x.key + y.key] = (m[x.key + y.key] ?? Rational(0)) + x.value * y.value;
      }
    }
    return clean(m);
  }

  static Poly pow(Poly a, int n) {
    var acc = constant(Rational(1));
    for (var i = 0; i < n; i++) {
      acc = mul(acc, a);
    }
    return acc;
  }

  static Rational eval(Poly p, Rational v) {
    var acc = Rational(0);
    p.forEach((k, c) => acc = acc + c * v.pow(k));
    return acc;
  }

  /// Division sintetica entre (x - root): devuelve el cociente.
  static Poly deflate(Poly p, Rational root) {
    final d = degree(p);
    final q = <int, Rational>{};
    var carry = Rational(0);
    for (var k = d; k >= 1; k--) {
      carry = coeff(p, k) + carry * root;
      q[k - 1] = carry;
    }
    return clean(q);
  }

  /// Polinomio de enteros: multiplica por el m.c.m. de los denominadores.
  static Poly toIntegers(Poly p) {
    var l = 1;
    for (final c in p.values) {
      l = Rational.lcm(l, c.denominator);
    }
    return scale(p, Rational(l));
  }

  static String latex(Poly p, {String v = 'x'}) {
    final c = clean(p);
    if (c.isEmpty) return '0';
    final keys = c.keys.toList()..sort((a, b) => b.compareTo(a));
    final buf = StringBuffer();
    var first = true;
    for (final k in keys) {
      final co = c[k]!;
      final abs = co.abs();
      final one = abs == Rational(1);
      final coefStr = (k > 0 && one) ? '' : _coefLatex(abs);
      final body = k == 0 ? coefStr : (k == 1 ? '$coefStr$v' : '$coefStr$v^{$k}');
      if (first) {
        buf.write(co.isNegative ? '-$body' : body);
        first = false;
      } else {
        buf.write(co.isNegative ? ' - $body' : ' + $body');
      }
    }
    return buf.toString();
  }

  static String _coefLatex(Rational r) =>
      r.isInteger ? '${r.numerator}' : '\\frac{${r.numerator}}{${r.denominator}}';

  // ---- Extraccion desde el AST -------------------------------------------

  static bool isX(XNode n) => n is XVar && n.name == 'X';

  /// Polinomio de [n] respecto de la "variable" que reconoce [isVar]; `null` si no lo es.
  static Poly? polyOf(XNode n, {bool Function(XNode)? isVar}) {
    final v = isVar ?? isX;
    if (v(n)) return x();
    switch (n) {
      case XNum(:final value):
        return constant(value);
      case XNeg(:final a):
        final p = polyOf(a, isVar: v);
        return p == null ? null : neg(p);
      case XBin(:final l, :final op, :final r):
        final a = polyOf(l, isVar: v);
        final b = polyOf(r, isVar: v);
        if (a == null || b == null) return null;
        switch (op) {
          case '+':
            return add(a, b);
          case '-':
            return sub(a, b);
          case '*':
            return mul(a, b);
          default:
            if (degree(b) != 0) return null;
            return scale(a, coeff(b, 0).pow(-1));
        }
      case XPow(:final base, :final exp):
        final b = polyOf(base, isVar: v);
        final e = polyOf(exp, isVar: v);
        if (b == null || e == null || degree(e) > 0) return null;
        final k = coeff(e, 0);
        if (!k.isInteger || k.numerator < 0 || k.numerator > 12) return null;
        return pow(b, k.numerator);
      default:
        return null;
    }
  }

  /// Fraccion algebraica (numerador, denominador); `null` si el AST no es racional.
  static (Poly, Poly)? rationalOf(XNode n) {
    final one = constant(Rational(1));
    if (isX(n)) return (x(), one);
    switch (n) {
      case XNum(:final value):
        return (constant(value), one);
      case XNeg(:final a):
        final f = rationalOf(a);
        return f == null ? null : (neg(f.$1), f.$2);
      case XBin(:final l, :final op, :final r):
        final a = rationalOf(l);
        final b = rationalOf(r);
        if (a == null || b == null) return null;
        switch (op) {
          case '+':
            return (add(mul(a.$1, b.$2), mul(b.$1, a.$2)), mul(a.$2, b.$2));
          case '-':
            return (sub(mul(a.$1, b.$2), mul(b.$1, a.$2)), mul(a.$2, b.$2));
          case '*':
            return (mul(a.$1, b.$1), mul(a.$2, b.$2));
          default:
            if (b.$1.isEmpty) return null;
            return (mul(a.$1, b.$2), mul(a.$2, b.$1));
        }
      case XPow(:final base, :final exp):
        final b = rationalOf(base);
        final e = polyOf(exp);
        if (b == null || e == null || degree(e) > 0) return null;
        final k = coeff(e, 0);
        if (!k.isInteger || k.numerator.abs() > 12) return null;
        final m = k.numerator.abs();
        final (num, den) = (pow(b.$1, m), pow(b.$2, m));
        return k.numerator >= 0 ? (num, den) : (den, num);
      default:
        return null;
    }
  }

  static bool containsX(XNode n) => switch (n) {
        XVar(:final name) => name == 'X',
        XNum() || XConst() => false,
        XNeg(:final a) || XAbs(:final a) || XFact(:final a) => containsX(a),
        XBin(:final l, :final r) => containsX(l) || containsX(r),
        XPow(:final base, :final exp) => containsX(base) || containsX(exp),
        XRoot(:final index, :final rad) =>
          containsX(rad) || (index != null && containsX(index)),
        XComb(:final n, :final r) => containsX(n) || containsX(r),
        XFn(:final arg, :final base) =>
          containsX(arg) || (base != null && containsX(base)),
      };

  /// Denominadores (con x) de todas las divisiones del arbol.
  static void collectDenominators(XNode n, List<XNode> out) {
    switch (n) {
      case XBin(:final l, :final op, :final r):
        if (op == '/' && containsX(r)) out.add(r);
        collectDenominators(l, out);
        collectDenominators(r, out);
      case XNeg(:final a) || XAbs(:final a) || XFact(:final a):
        collectDenominators(a, out);
      case XPow(:final base, :final exp):
        final e = exp is XNeg ? exp.a : exp;
        if (exp is XNeg || (exp is XNum && exp.value.isNegative)) {
          if (containsX(base)) out.add(base);
        }
        collectDenominators(base, out);
        collectDenominators(e, out);
      case XRoot(:final rad):
        collectDenominators(rad, out);
      case XFn(:final arg):
        collectDenominators(arg, out);
      default:
        break;
    }
  }
}

/// Raices reales de un polinomio: exactas cuando es posible, decimales si no.
class PolyRoots {
  const PolyRoots._();

  static List<ExNum> real(Poly input) {
    var p = PolyOps.toIntegers(PolyOps.clean(input));
    if (p.isEmpty) return const [];
    final roots = <ExNum>[];
    final lowest = p.keys.reduce(math.min);
    if (lowest > 0) {
      roots.add(ExNum.integer(0));
      p = {for (final e in p.entries) e.key - lowest: e.value};
    }
    // Raices racionales (teorema de la raiz racional).
    var guard = 0;
    while (PolyOps.degree(p) >= 1 && guard++ < 12) {
      final r = rationalRoot(p);
      if (r == null) break;
      if (!roots.any((e) => e.asRational == r)) roots.add(ExNum.rational(r));
      p = PolyOps.toIntegers(PolyOps.deflate(p, r));
    }
    final d = PolyOps.degree(p);
    if (d == 1) {
      roots.add(ExNum.rational(-PolyOps.coeff(p, 0) / PolyOps.coeff(p, 1)));
    } else if (d == 2) {
      roots.addAll(quadratic(PolyOps.coeff(p, 2), PolyOps.coeff(p, 1), PolyOps.coeff(p, 0)));
    } else if (d >= 3) {
      roots.addAll(_numeric(p).map((v) => ExNum.opaque(
            NumLatex.decimal(v),
            v,
          )));
    }
    roots.sort((a, b) => a.approx.compareTo(b.approx));
    final uniq = <ExNum>[];
    for (final r in roots) {
      if (!uniq.any((u) => (u.approx - r.approx).abs() < 1e-9)) uniq.add(r);
    }
    return uniq;
  }

  /// Soluciones reales de ax^2 + bx + c = 0 en forma exacta.
  static List<ExNum> quadratic(Rational a, Rational b, Rational c) {
    final disc = b * b - Rational(4) * a * c;
    if (disc.isNegative) return const [];
    final sq = ExtMath.nthRoot(disc, 2);
    final inv = ExNum.rational(Rational(1) / (Rational(2) * a));
    final minusB = ExNum.rational(-b);
    final r1 = (minusB - sq) * inv;
    final r2 = (minusB + sq) * inv;
    return disc.isZero ? [r1] : [r1, r2];
  }

  /// Primera raiz racional (teorema de la raiz racional) o `null`.
  static Rational? rationalRoot(Poly p) {
    final a0 = PolyOps.coeff(p, 0).numerator.abs();
    final an = PolyOps.coeff(p, PolyOps.degree(p)).numerator.abs();
    if (a0 == 0) return Rational(0);
    for (final num in _divisors(a0)) {
      for (final den in _divisors(an)) {
        for (final s in const [1, -1]) {
          final cand = Rational(s * num, den);
          if (PolyOps.eval(p, cand).isZero) return cand;
        }
      }
    }
    return null;
  }

  static List<int> _divisors(int n) {
    final out = <int>[];
    for (var i = 1; i * i <= n; i++) {
      if (n % i == 0) {
        out.add(i);
        if (i * i != n) out.add(n ~/ i);
      }
    }
    return out..sort();
  }

  static List<double> _numeric(Poly p) {
    double f(double v) {
      var acc = 0.0;
      p.forEach((k, c) => acc += c.toDouble() * math.pow(v, k));
      return acc;
    }

    final lead = PolyOps.coeff(p, PolyOps.degree(p)).toDouble().abs();
    var bound = 1.0;
    p.forEach((k, c) {
      if (k != PolyOps.degree(p)) bound = math.max(bound, 1 + c.toDouble().abs() / lead);
    });
    final out = <double>[];
    const n = 40000;
    var prevX = -bound;
    var prevY = f(prevX);
    for (var i = 1; i <= n; i++) {
      final cx = -bound + 2 * bound * i / n;
      final cy = f(cx);
      if (prevY == 0) {
        out.add(prevX);
      } else if (prevY * cy < 0) {
        var lo = prevX, hi = cx;
        for (var j = 0; j < 80; j++) {
          final mid = (lo + hi) / 2;
          if (f(lo) * f(mid) <= 0) {
            hi = mid;
          } else {
            lo = mid;
          }
        }
        out.add((lo + hi) / 2);
      }
      prevX = cx;
      prevY = cy;
    }
    return out;
  }
}

/// Formato numerico compartido por los solvers de ecuaciones.
class NumLatex {
  const NumLatex._();
  static String decimal(double v) => ExNum.opaque('', v).decimalLatex();
}
