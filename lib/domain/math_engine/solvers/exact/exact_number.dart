import 'dart:math' as math;

import '../../core/number_formatter.dart';
import '../../core/rational.dart';

/// Clave de un termino: (radicando libre de cuadrados, potencia de pi, potencia de e).
typedef ExKey = (int, int, int);

/// Error matematico (division por cero, raiz de negativo, log de no positivo...).
class ExMathError extends FormatException {
  static const String evenRootNegative = 'Raíz de índice par de un número negativo (no existe en ℝ).';
  static const String divByZero = 'No se puede dividir entre cero.';
  const ExMathError([super.message = 'Math ERROR']);
}

/// Numero exacto `sum(q_i * sqrt(r_i) * pi^p * e^k)` o, si no es representable,
/// un valor "opaco" con LaTeX propio y aproximacion decimal.
class ExNum {
  final Map<ExKey, Rational> terms;
  final double approx;
  final String? opaqueLatex;

  const ExNum._(this.terms, this.approx, this.opaqueLatex);

  static const ExKey _one = (1, 0, 0);

  factory ExNum.fromTerms(Map<ExKey, Rational> raw) {
    final clean = <ExKey, Rational>{};
    raw.forEach((k, v) {
      if (!v.isZero) clean[k] = v.simplify();
    });
    var a = 0.0;
    clean.forEach((k, v) {
      a += v.toDouble() *
          math.sqrt(k.$1) *
          math.pow(math.pi, k.$2) *
          math.pow(math.e, k.$3);
    });
    return ExNum._(Map.unmodifiable(clean), a, null);
  }

  factory ExNum.rational(Rational r) => ExNum.fromTerms({_one: r});
  factory ExNum.integer(int n) => ExNum.rational(Rational(n));
  factory ExNum.pi() => ExNum.fromTerms({(1, 1, 0): Rational(1)});
  factory ExNum.euler() => ExNum.fromTerms({(1, 0, 1): Rational(1)});
  factory ExNum.opaque(String latex, double approx) =>
      ExNum._(const {}, approx, latex);

  bool get isExact => opaqueLatex == null;
  bool get isZero => isExact && terms.isEmpty;

  /// Valor racional puro si no hay radicales, pi ni e.
  Rational? get asRational {
    if (!isExact) return null;
    if (terms.isEmpty) return Rational(0);
    if (terms.length == 1 && terms.containsKey(_one)) return terms[_one];
    return null;
  }

  int? get asInt {
    final r = asRational;
    return (r != null && r.isInteger) ? r.numerator : null;
  }

  bool get isRational => asRational != null;

  /// Solo radicales (sin pi ni e).
  bool get isAlgebraic => isExact && terms.keys.every((k) => k.$2 == 0 && k.$3 == 0);

  static String _wrap(ExNum n) => (n.isExact && n.terms.length > 1)
      ? '\\left(${n.toLatex()}\\right)'
      : n.toLatex();

  static String _join(ExNum a, ExNum b, bool plus) {
    var bl = b.toLatex();
    final neg = bl.startsWith('-');
    if (neg) bl = bl.substring(1);
    final minus = plus == neg; // + con negativo, o - con positivo
    final compound = bl.contains(' + ') || bl.contains(' - ');
    final shown = minus && compound ? '\\left($bl\\right)' : bl;
    return '${a.toLatex()} ${minus ? '-' : '+'} $shown';
  }

  ExNum operator +(ExNum o) {
    if (isExact && isZero) return o;
    if (o.isExact && o.isZero) return this;
    if (!isExact || !o.isExact) return ExNum.opaque(_join(this, o, true), approx + o.approx);
    final m = Map<ExKey, Rational>.of(terms);
    o.terms.forEach((k, v) => m[k] = (m[k] ?? Rational(0)) + v);
    return ExNum.fromTerms(m);
  }

  ExNum operator -() => isExact
      ? ExNum.fromTerms({for (final e in terms.entries) e.key: -e.value})
      : ExNum.opaque(
          opaqueLatex!.startsWith('-') ? opaqueLatex!.substring(1) : '-${_wrap(this)}',
          -approx,
        );

  ExNum operator -(ExNum o) {
    if (o.isExact && o.isZero) return this;
    if (isExact && isZero) return -o;
    if (!isExact || !o.isExact) return ExNum.opaque(_join(this, o, false), approx - o.approx);
    return this + (-o);
  }

  static (int, int) _squareFree(int n) {
    var s = 1;
    var t = 1;
    Rational.primeFactorsMap(n).forEach((p, k) {
      for (var i = 0; i < k ~/ 2; i++) {
        s *= p;
      }
      if (k.isOdd) t *= p;
    });
    return (s, t);
  }

  ExNum operator *(ExNum o) {
    if (isExact && (isZero || (o.isExact && o.isZero))) return ExNum.integer(0);
    if (o.asRational == Rational(1)) return this;
    if (asRational == Rational(1)) return o;
    if (!isExact || !o.isExact) {
      return ExNum.opaque('${_wrap(this)} \\cdot ${_wrap(o)}', approx * o.approx);
    }
    final m = <ExKey, Rational>{};
    for (final a in terms.entries) {
      for (final b in o.terms.entries) {
        final (s, t) = _squareFree(a.key.$1 * b.key.$1);
        final key = (t, a.key.$2 + b.key.$2, a.key.$3 + b.key.$3);
        final c = a.value * b.value * Rational(s);
        m[key] = (m[key] ?? Rational(0)) + c;
      }
    }
    return ExNum.fromTerms(m);
  }

  /// Factor que, multiplicado por este denominador, lo vuelve racional.
  ExNum? rationalizingFactor() {
    if (!isExact || terms.isEmpty || isRational) return null;
    if (terms.length == 1) {
      final k = terms.keys.first;
      if (k.$2 != 0 || k.$3 != 0) return null;
      return ExNum.fromTerms({(k.$1, 0, 0): Rational(1)});
    }
    if (terms.length == 2 && isAlgebraic) {
      final e = terms.entries.toList();
      return ExNum.fromTerms({e[0].key: e[0].value}) -
          ExNum.fromTerms({e[1].key: e[1].value});
    }
    return null;
  }

  ExNum inverse() {
    if (!isExact) return ExNum.opaque('\\frac{1}{${toLatex()}}', 1 / approx);
    if (terms.isEmpty) throw const ExMathError();
    if (terms.length == 1) {
      final e = terms.entries.first;
      final (r, p, k) = e.key;
      return ExNum.fromTerms({
        (r, -p, -k): e.value.pow(-1) / Rational(r),
      });
    }
    final f = rationalizingFactor();
    if (f != null) {
      final den = (this * f).asRational;
      if (den != null && !den.isZero) {
        return f * ExNum.rational(den.pow(-1));
      }
    }
    return ExNum.opaque('\\frac{1}{${toLatex()}}', 1 / approx);
  }

  ExNum operator /(ExNum o) {
    if (o.isExact && o.terms.isEmpty) throw const ExMathError();
    if (!o.isExact) {
      return ExNum.opaque('\\frac{${toLatex()}}{${o.toLatex()}}', approx / o.approx);
    }
    if (!isExact) {
      return ExNum.opaque('\\frac{${toLatex()}}{${o.toLatex()}}', approx / o.approx);
    }
    return this * o.inverse();
  }

  ExNum powInt(int n) {
    if (n == 0) {
      if (isZero) throw const ExMathError();
      return ExNum.integer(1);
    }
    if (n < 0) return inverse().powInt(-n);
    if (!isExact) {
      return ExNum.opaque('${_wrap(this)}^{$n}', math.pow(approx, n).toDouble());
    }
    if (n > 64 || (math.pow(approx.abs(), n) > 9e15 && isRational)) {
      return ExNum.opaque('${_wrap(this)}^{$n}', math.pow(approx, n).toDouble());
    }
    var acc = ExNum.integer(1);
    for (var i = 0; i < n; i++) {
      acc = acc * this;
    }
    return acc;
  }

  String toLatex() {
    if (!isExact) return opaqueLatex!;
    if (terms.isEmpty) return '0';
    final keys = terms.keys.toList()
      ..sort((a, b) {
        final c = a.$2.compareTo(b.$2);
        if (c != 0) return c;
        final d = a.$3.compareTo(b.$3);
        return d != 0 ? d : a.$1.compareTo(b.$1);
      });
    final buf = StringBuffer();
    var first = true;
    for (final k in keys) {
      final c = terms[k]!;
      final neg = c.isNegative;
      final body = _termBody(k, c.abs());
      if (first) {
        buf.write(neg ? '-$body' : body);
        first = false;
      } else {
        buf.write(neg ? ' - $body' : ' + $body');
      }
    }
    return buf.toString();
  }

  static String _pow(String sym, int n) => n == 1 ? sym : '$sym^{$n}';

  static String _termBody(ExKey k, Rational c) {
    final (r, p, e) = k;
    final num = StringBuffer();
    final den = StringBuffer();
    final hasSym = r > 1 || p != 0 || e != 0;
    if (c.numerator != 1 || !hasSym) num.write(c.numerator);
    if (c.denominator != 1) den.write(c.denominator);
    if (r > 1) num.write('\\sqrt{$r}');
    if (p > 0) num.write(_pow('\\pi', p));
    if (p < 0) den.write(_pow('\\pi', -p));
    if (e > 0) num.write(_pow('e', e));
    if (e < 0) den.write(_pow('e', -e));
    final n = num.isEmpty ? '1' : num.toString();
    return den.isEmpty ? n : '\\frac{$n}{$den}';
  }

  String decimalLatex() {
    final v = approx;
    if (v.isNaN || v.isInfinite) return '';
    if (v.abs() >= 1e12 || (v != 0 && v.abs() < 1e-9)) {
      final parts = v.toStringAsExponential(6).split('e');
      final exp = int.parse(parts[1].replaceFirst('+', ''));
      final mant = NumberFormatter.decimal(double.parse(parts[0]));
      return '$mant \\cdot 10^{$exp}';
    }
    return NumberFormatter.decimal(v);
  }
}
