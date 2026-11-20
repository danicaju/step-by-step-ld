import 'dart:math' as math;

/// Etiqueta exacta (LaTeX) de un numero real obtenido numericamente: entero, fraccion,
/// radical `p + s sqrt(n)` sobre `q`, logaritmos / potencias de e o decimal aproximado.
class ExactLabel {
  /// LaTeX de la etiqueta.
  final String latex;

  /// Valor "limpio" (el racional exacto como double si se reconocio uno).
  final double value;

  /// `true` si es una expresion exacta; `false` si es una aproximacion decimal.
  final bool exact;

  const ExactLabel(this.latex, this.value, this.exact);

  static String decimal(double v) {
    var s = v.toStringAsFixed(4);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s.replaceAll('.', '{,}');
  }

  static String _frac(int p, int q) {
    if (q == 1) return '$p';
    return p < 0 ? '-\\frac{${-p}}{$q}' : '\\frac{$p}{$q}';
  }

  static bool _close(double a, double b, [double rel = 1e-10]) =>
      (a - b).abs() <= rel * math.max(1, math.max(a.abs(), b.abs()));

  /// `(raiz cuadrada sin cuadrados, factor)` de [m]: m = s^2 * n.
  static (int, int) _squareFree(int m) {
    var s = 1, n = m;
    for (var d = 2; d * d <= n; d++) {
      while (n % (d * d) == 0) {
        n ~/= d * d;
        s *= d;
      }
    }
    return (s, n);
  }

  static int _gcd(int a, int b) => b == 0 ? a.abs() : _gcd(b, a % b);

  /// Reconoce [v]; [bases] son bases de logaritmo/potencia presentes en la expresion.
  static ExactLabel of(double v, {List<double> bases = const []}) {
    final r = v.roundToDouble();
    if (_close(v, r) && r.abs() < 1e9) return ExactLabel('${r.toInt()}', r, true);
    for (var q = 2; q <= 360; q++) {
      final p = (v * q).roundToDouble();
      if (_close(v, p / q, 1e-11) && p.abs() < 1e9 && _gcd(p.toInt(), q) == 1) {
        return ExactLabel(_frac(p.toInt(), q), p / q, true);
      }
    }
    final rad = _radical(v);
    if (rad != null) return ExactLabel(rad, v, true);
    final lg = _logForm(v, bases);
    if (lg != null) return ExactLabel(lg, v, true);
    return ExactLabel(decimal(v), v, false);
  }

  /// `(p + s sqrt(n)) / q` con q <= 12, |p| <= 60, n sin cuadrados <= 99.
  static String? _radical(double v) {
    for (var q = 1; q <= 12; q++) {
      for (var p = -60; p <= 60; p++) {
        final w = v * q - p;
        if (w.abs() < 1e-9) continue;
        final w2 = w * w;
        final m = w2.roundToDouble();
        if (m < 2 || m > 9999 || !_close(w2, m, 1e-9)) continue;
        final (s, n) = _squareFree(m.toInt());
        if (n < 2 || n > 99) continue;
        final g = _gcd(_gcd(p, s), q);
        final pp = p ~/ g, ss = s ~/ g, qq = q ~/ g;
        final coef = w < 0 ? -ss : ss;
        final root = coef.abs() == 1 ? '\\sqrt{$n}' : '${coef.abs()}\\sqrt{$n}';
        final signed = coef < 0 ? '-$root' : root;
        final head = pp == 0 ? signed : (coef < 0 ? '$pp$signed' : '$pp+$signed');
        if (qq == 1) return head;
        if (pp == 0) {
          final sign = coef < 0 ? '-' : '';
          return '$sign\\frac{$root}{$qq}';
        }
        return '\\frac{$head}{$qq}';
      }
    }
    return null;
  }

  static String? _logForm(double v, List<double> bases) {
    // e^k con k racional sencillo (v > 0).
    if (v > 0) {
      final k = math.log(v);
      for (var q = 1; q <= 4; q++) {
        final p = (k * q).roundToDouble();
        if (p != 0 && _close(k, p / q, 1e-10) && p.abs() <= 20) {
          return q == 1 ? 'e^{${p.toInt()}}' : 'e^{${_frac(p.toInt(), q)}}';
        }
      }
    }
    // base^v racional pequeno: v = log_base(t); base e -> ln(t).
    final candidates = <(double, String)>[(math.e, '\\ln'), for (final b in bases) (b, '\\log_{${_baseLatex(b)}}')];
    for (final (b, name) in candidates) {
      if (b <= 0 || b == 1) continue;
      final t = math.pow(b, v).toDouble();
      if (t <= 0 || t > 1e7) continue;
      for (var q = 1; q <= 60; q++) {
        final p = (t * q).roundToDouble();
        if (p >= 1 && _close(t, p / q, 1e-9) && _gcd(p.toInt(), q) == 1) {
          final arg = q == 1 ? '${p.toInt()}' : '\\frac{${p.toInt()}}{$q}';
          return '$name\\left($arg\\right)';
        }
      }
    }
    return null;
  }

  static String _baseLatex(double b) {
    final r = b.roundToDouble();
    return (b - r).abs() < 1e-12 ? '${r.toInt()}' : decimal(b);
  }
}
