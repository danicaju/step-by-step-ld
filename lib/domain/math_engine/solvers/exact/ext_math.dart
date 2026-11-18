import 'dart:math' as math;

import '../../core/rational.dart';
import 'exact_number.dart';

/// Utilidades exactas: raices n-esimas, logaritmos, factoriales y combinatoria.
class ExtMath {
  const ExtMath._();

  static Map<int, int> _exps(Rational r) {
    final m = <int, int>{};
    Rational.primeFactorsMap(r.numerator.abs()).forEach((p, k) => m[p] = k);
    Rational.primeFactorsMap(r.denominator).forEach((p, k) => m[p] = (m[p] ?? 0) - k);
    m.removeWhere((_, v) => v == 0);
    return m;
  }

  /// Raiz n-esima exacta de un racional: `coef * raiz_n(radicando entero)`.
  static ExNum nthRoot(Rational r, int n) {
    if (r.isZero) return ExNum.integer(0);
    final neg = r.isNegative;
    if (neg && n.isEven) throw const ExMathError(ExMathError.evenRootNegative);
    var coef = Rational(1);
    var rad = 1;
    _exps(r.abs()).forEach((p, e) {
      final q = (e / n).floor();
      final m = e - q * n;
      coef = coef * Rational(p).pow(q);
      for (var i = 0; i < m; i++) {
        rad *= p;
      }
    });
    if (neg) coef = -coef;
    if (rad == 1) return ExNum.rational(coef);
    if (n == 2) return ExNum.fromTerms({(rad, 0, 0): coef});
    final c = coef == Rational(1)
        ? ''
        : (coef == Rational(-1) ? '-' : ExNum.rational(coef).toLatex());
    final approx = coef.toDouble() * math.pow(rad, 1 / n).toDouble();
    return ExNum.opaque('$c\\sqrt[$n]{$rad}', approx);
  }

  /// `log_b(x)` exacto cuando ambos son racionales con las mismas bases primas.
  static ExNum? logExact(Rational b, Rational x) {
    if (x == Rational(1)) return ExNum.integer(0);
    final mb = _exps(b);
    final mx = _exps(x);
    if (mb.isEmpty) throw const ExMathError();
    final p0 = mb.keys.first;
    final k = Rational(mx[p0] ?? 0, mb[p0]!);
    if (k.isZero) return null;
    for (final q in {...mb.keys, ...mx.keys}) {
      if (k * Rational(mb[q] ?? 0) != Rational(mx[q] ?? 0)) return null;
    }
    return ExNum.rational(k);
  }

  static BigInt factorialBig(int n) {
    var acc = BigInt.one;
    for (var i = 2; i <= n; i++) {
      acc *= BigInt.from(i);
    }
    return acc;
  }

  static ExNum fromBig(BigInt v, String latexIfHuge) {
    if (v.bitLength < 62) return ExNum.integer(v.toInt());
    return ExNum.opaque(latexIfHuge, v.toDouble());
  }

  static ExNum factorial(int n) {
    if (n < 0 || n > 170) throw const ExMathError();
    return fromBig(factorialBig(n), '$n!');
  }

  static ExNum comb(int n, int r, {required bool perm}) {
    if (n < 0 || r < 0 || r > n || n > 170) throw const ExMathError();
    final nf = factorialBig(n);
    final den = perm ? factorialBig(n - r) : factorialBig(r) * factorialBig(n - r);
    final label = perm ? '{}_{$n}P_{$r}' : '\\binom{$n}{$r}';
    return fromBig(nf ~/ den, label);
  }
}
