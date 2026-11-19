import 'dart:math' as math;

import '../core/number_formatter.dart';
import '../core/rational.dart';

/// Partes de un coeficiente para escribirlo en LaTeX: signo, valor absoluto
/// y si es "atomico" (se puede yuxtaponer delante de x sin parentesis).
typedef CoefParts = ({bool neg, String abs, bool atomic});

/// Signo, numerador (LaTeX) y denominador entero, para fusionar fracciones.
typedef FracParts = ({bool neg, String num, int den});

/// Coeficiente real: exacto en Q(sqrt d) ([SurdCoef]) o decimal ([DecCoef]).
sealed class Coef {
  const Coef();

  static Coef rat(Rational r) => SurdCoef(r, Rational(0), 1);
  static Coef integer(int n) => rat(Rational(n));
  static final Coef zero = integer(0);
  static final Coef one = integer(1);

  double get v;
  bool get isZero;
  CoefParts parts();
  FracParts fracParts();

  /// `± \frac{k}{den}` en una sola fraccion ([denProd]: den listo para multiplicar).
  String overTerm(String den, String denProd, {required bool first}) {
    final f = fracParts();
    final body = f.den == 1 ? '\\frac{${f.num}}{$den}' : '\\frac{${f.num}}{${f.den}$denProd}';
    if (first) return f.neg ? '-$body' : body;
    return f.neg ? ' - $body' : ' + $body';
  }

  /// Valor racional exacto, o `null`.
  Rational? get asRational;

  Coef operator +(Coef o);
  Coef operator *(Coef o);
  Coef operator /(Coef o);
  Coef operator -();
  Coef operator -(Coef o) => this + (-o);

  /// Copia decimal (pierde la exactitud).
  Coef get asDec => DecCoef(v);

  String latex() {
    final p = parts();
    if (!p.neg) return p.abs;
    return p.atomic ? '-${p.abs}' : '-\\left(${p.abs}\\right)';
  }

  /// Racional cercano (denominador <= 24) o decimal.
  static Coef snap(double v) {
    for (var q = 1; q <= 24; q++) {
      final p = (v * q).round();
      if ((v - p / q).abs() < 1e-9 * math.max(1, v.abs())) return rat(Rational(p, q));
    }
    return DecCoef(v);
  }

  /// Raiz cuadrada exacta si el coeficiente es racional positivo (k/d sqrt m).
  Coef? exactSqrt() {
    final r = asRational;
    if (r == null) return this is DecCoef && v > 0 ? DecCoef(math.sqrt(v)) : null;
    if (!r.isPositive) return null;
    // sqrt(n/d) = sqrt(n d) / d
    var m = r.numerator * r.denominator;
    var k = 1;
    for (var f = 2; f * f <= m; f++) {
      while (m % (f * f) == 0) {
        m ~/= f * f;
        k *= f;
      }
    }
    return SurdCoef(Rational(0), Rational(k, r.denominator), m);
  }

  /// `+ c·factor` / `- c·factor` (o sin signo inicial si [first]).
  String signedTerm(String factor, {required bool first}) {
    final p = parts();
    final String body;
    if (factor.isEmpty) {
      body = p.abs;
    } else if (p.abs == '1') {
      body = factor;
    } else {
      final c = p.atomic ? p.abs : '\\left(${p.abs}\\right)';
      body = this is DecCoef ? '$c \\cdot $factor' : '$c$factor';
    }
    if (first) return p.neg ? '-$body' : body;
    return p.neg ? ' - $body' : ' + $body';
  }
}

/// a + b sqrt(d) con a, b racionales y d libre de cuadrados.
class SurdCoef extends Coef {
  final Rational a;
  final Rational b;
  final int d;

  SurdCoef._(this.a, this.b, this.d);

  factory SurdCoef(Rational a, Rational b, int d) {
    if (d == 1) return SurdCoef._(a + b, Rational(0), 1);
    if (d == 0) return SurdCoef._(a, Rational(0), 1);
    return SurdCoef._(a, b, b.isZero ? 1 : d);
  }

  @override
  double get v => a.toDouble() + b.toDouble() * math.sqrt(d);
  @override
  bool get isZero => a.isZero && b.isZero;
  @override
  Rational? get asRational => b.isZero ? a : null;

  bool _compat(SurdCoef o) => d == 1 || o.d == 1 || d == o.d;

  static bool _big(Rational r) => r.numerator.abs() > (1 << 40) || r.denominator > (1 << 40);

  /// Evita desbordar los enteros de 64 bits: si crece demasiado pasa a decimal.
  static Coef _safe(Rational a, Rational b, int d) {
    if (_big(a) || _big(b)) return DecCoef(a.toDouble() + b.toDouble() * math.sqrt(d));
    return SurdCoef(a, b, d);
  }

  @override
  Coef operator +(Coef o) {
    if (o is SurdCoef && _compat(o)) {
      return _safe(a + o.a, b + o.b, math.max(d, o.d));
    }
    return DecCoef(v + o.v);
  }

  @override
  Coef operator *(Coef o) {
    if (o is SurdCoef && _compat(o)) {
      final dd = math.max(d, o.d);
      return _safe(a * o.a + b * o.b * Rational(dd), a * o.b + o.a * b, dd);
    }
    return DecCoef(v * o.v);
  }

  @override
  Coef operator /(Coef o) {
    if (o is SurdCoef && _compat(o)) {
      final norm = o.a * o.a - o.b * o.b * Rational(o.d);
      if (norm.isZero) throw const FormatException('Division por cero');
      final conj = SurdCoef(o.a / norm, -o.b / norm, o.d);
      return this * conj;
    }
    return DecCoef(v / o.v);
  }

  @override
  Coef operator -() => SurdCoef(-a, -b, d);

  @override
  CoefParts parts() {
    final f = fracParts();
    if (f.den != 1) return (neg: f.neg, abs: '\\frac{${f.num}}{${f.den}}', atomic: true);
    return (neg: f.neg, abs: f.num, atomic: b.isZero || a.isZero);
  }

  @override
  FracParts fracParts() {
    if (b.isZero) {
      return (neg: a.isNegative, num: '${a.numerator.abs()}', den: a.denominator);
    }
    final l = Rational.lcm(a.denominator, b.denominator);
    final n1 = (a * Rational(l)).numerator;
    final n2 = (b * Rational(l)).numerator;
    String root(int k) => k == 1 ? '\\sqrt{$d}' : '$k\\sqrt{$d}';
    final bool neg;
    final String num;
    if (n1 == 0) {
      neg = n2 < 0;
      num = root(n2.abs());
    } else if (n1 < 0 && n2 < 0) {
      neg = true;
      num = '${-n1} + ${root(-n2)}';
    } else if (n1 < 0) {
      neg = false;
      num = '${root(n2)} - ${-n1}';
    } else {
      neg = false;
      num = n2 < 0 ? '$n1 - ${root(-n2)}' : '$n1 + ${root(n2)}';
    }
    return (neg: neg, num: num, den: l);
  }
}

/// Coeficiente decimal (Nivel 2 numerico).
class DecCoef extends Coef {
  @override
  final double v;
  const DecCoef(this.v);

  @override
  bool get isZero => v.abs() < 1e-10;
  @override
  Rational? get asRational => null;
  @override
  Coef operator +(Coef o) => DecCoef(v + o.v);
  @override
  Coef operator *(Coef o) => DecCoef(v * o.v);
  @override
  Coef operator /(Coef o) => DecCoef(v / o.v);
  @override
  Coef operator -() => DecCoef(-v);

  /// Decimal limpio con 4 cifras significativas.
  static String fmt4(double x) {
    if (x == 0) return '0';
    final rounded = double.parse(x.toStringAsPrecision(4));
    if (rounded.abs() >= 1e6 || rounded.abs() < 1e-4) {
      final parts = rounded.toStringAsExponential(3).split('e');
      final exp = int.parse(parts[1].replaceFirst('+', ''));
      return '${NumberFormatter.decimal(double.parse(parts[0]))} \\cdot 10^{$exp}';
    }
    return NumberFormatter.decimal(rounded, maxDecimals: 10);
  }

  @override
  CoefParts parts() => (neg: v < 0, abs: fmt4(v.abs()), atomic: true);

  @override
  FracParts fracParts() => (neg: v < 0, num: fmt4(v.abs()), den: 1);
}

/// Polinomio de coeficientes [Coef] en orden ascendente (indice = grado).
class CPoly {
  final List<Coef> c;
  CPoly(List<Coef> coeffs) : c = _trim(coeffs);

  static List<Coef> _trim(List<Coef> l) {
    final out = List<Coef>.of(l);
    while (out.length > 1 && out.last.isZero) {
      out.removeLast();
    }
    return out.isEmpty ? [Coef.zero] : out;
  }

  static CPoly constant(Coef k) => CPoly([k]);

  /// x - r
  static CPoly linear(Coef r) => CPoly([-r, Coef.one]);

  int get degree => c.length == 1 && c[0].isZero ? -1 : c.length - 1;
  Coef operator [](int k) => k < c.length ? c[k] : Coef.zero;

  CPoly operator *(CPoly o) {
    final out = List<Coef>.filled(c.length + o.c.length - 1, Coef.zero);
    for (var i = 0; i < c.length; i++) {
      for (var j = 0; j < o.c.length; j++) {
        out[i + j] = out[i + j] + c[i] * o.c[j];
      }
    }
    return CPoly(out);
  }

  CPoly scale(Coef k) => CPoly([for (final e in c) e * k]);

  CPoly get asDec => CPoly([for (final e in c) e.asDec]);

  double evalD(double x) {
    var acc = 0.0;
    for (var k = c.length - 1; k >= 0; k--) {
      acc = acc * x + c[k].v;
    }
    return acc;
  }

  String latex({String v = 'x'}) {
    final buf = StringBuffer();
    var first = true;
    for (var k = c.length - 1; k >= 0; k--) {
      if (c[k].isZero) continue;
      final f = k == 0 ? '' : (k == 1 ? v : '$v^{$k}');
      buf.write(c[k].signedTerm(f, first: first));
      first = false;
    }
    return first ? '0' : buf.toString();
  }
}

/// Eliminacion de Gauss con pivoteo parcial sobre [Coef] (exacta o decimal).
class CoefLinearSolver {
  const CoefLinearSolver._();

  static List<Coef>? solve(List<List<Coef>> a, List<Coef> b) {
    final n = b.length;
    final m = [for (var i = 0; i < n; i++) [...a[i], b[i]]];
    for (var col = 0; col < n; col++) {
      var piv = col;
      for (var r = col + 1; r < n; r++) {
        if (m[r][col].v.abs() > m[piv][col].v.abs()) piv = r;
      }
      if (m[piv][col].isZero) return null;
      final tmp = m[col];
      m[col] = m[piv];
      m[piv] = tmp;
      for (var r = 0; r < n; r++) {
        if (r == col || m[r][col].isZero) continue;
        final f = m[r][col] / m[col][col];
        for (var k = col; k <= n; k++) {
          m[r][k] = m[r][k] - f * m[col][k];
        }
      }
    }
    return [for (var i = 0; i < n; i++) m[i][n] / m[i][i]];
  }
}
