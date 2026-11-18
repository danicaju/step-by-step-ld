import 'dart:math' as math;

import '../core/rational.dart';
import 'function_family.dart';

/// Formato de angulos / abscisas trigonometricas para el estudio y el visor.
class AngleFormat {
  const AngleFormat._();

  /// Vuelta completa en la unidad activa (`2*pi` en RAD, `360` en DEG).
  static double turn(bool deg) => deg ? 360 : 2 * math.pi;

  /// Racional pequeno (den <= 36) que aproxima [v], o `null`.
  static Rational? smallRational(double v) {
    for (var d = 1; d <= 36; d++) {
      final n = (v * d).roundToDouble();
      if ((v - n / d).abs() < 1e-9) return Rational(n.toInt(), d);
    }
    return null;
  }

  /// LaTeX de [x]: `\frac{3\pi}{2}`, `-\pi`, `90^\circ` o decimal aproximado.
  static String latex(double x, bool deg) {
    if (deg) {
      final r = smallRational(x);
      return r == null ? '${fdec(x)}^\\circ' : '${_frac(r)}^\\circ';
    }
    final r = smallRational(x / math.pi);
    if (r == null) return fdec(x);
    if (r.isZero) return '0';
    final n = r.numerator, d = r.denominator;
    final sign = n < 0 ? '-' : '';
    final an = n.abs();
    final top = an == 1 ? '\\pi' : '$an\\pi';
    return d == 1 ? '$sign$top' : '$sign\\frac{$top}{$d}';
  }

  static String _frac(Rational r) => domainFrac(r);

  /// Etiqueta de texto plano para el eje (`π/2`, `-π`, `90°`).
  static String plain(double x, bool deg) {
    if (deg) {
      final r = smallRational(x);
      return r == null ? '${x.toStringAsFixed(1)}°' : '${_p(r)}°';
    }
    final r = smallRational(x / math.pi);
    if (r == null) return x.toStringAsFixed(2);
    if (r.isZero) return '0';
    final n = r.numerator, d = r.denominator;
    final an = n.abs();
    final top = an == 1 ? 'π' : '$anπ';
    return '${n < 0 ? '-' : ''}$top${d == 1 ? '' : '/$d'}';
  }

  static String _p(Rational r) => r.isInteger ? '${r.numerator}' : '${r.numerator}/${r.denominator}';
}

/// Fraccion LaTeX de un racional.
String domainFrac(Rational r) =>
    r.isInteger ? '${r.numerator}' : '${r.isNegative ? '-' : ''}\\frac{${r.numerator.abs()}}{${r.denominator}}';
