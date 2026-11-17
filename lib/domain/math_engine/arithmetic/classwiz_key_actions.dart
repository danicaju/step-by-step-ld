import 'dart:math';

import '../core/calculator_settings.dart';
import '../core/number_formatter.dart';
import '../core/rational.dart';

/// Acciones puras de teclas ClassWiz (FACT, ° ' ", a b/c, ENG, Ran#, RanInt#).
///
/// Trabajan sobre el texto LaTeX del resultado para poder alternar la vista de
/// la linea de resultado sin recalcular la expresion.
class ClassWizKeyActions {
  const ClassWizKeyActions._();

  static final RegExp _intRe = RegExp(r'^-?\d+$');
  static final RegExp _fracRe = RegExp(r'^(-?)\\frac\{(\d+)\}\{(\d+)\}$');
  static final RegExp _mixedRe = RegExp(r'^(-?)(\d+)\\frac\{(\d+)\}\{(\d+)\}$');

  /// Racional exacto desde el LaTeX de un resultado (`7`, `\frac{7}{2}`, `3\frac{1}{2}`).
  static Rational? rationalFromLatex(String latex) {
    final s = latex.replaceAll(' ', '').replaceAll(r'\,', '');
    if (_intRe.hasMatch(s)) return Rational(int.parse(s));
    final f = _fracRe.firstMatch(s);
    if (f != null) {
      final n = int.parse(f.group(2)!);
      return Rational(f.group(1) == '-' ? -n : n, int.parse(f.group(3)!));
    }
    final m = _mixedRe.firstMatch(s);
    if (m != null) {
      final d = int.parse(m.group(4)!);
      final n = int.parse(m.group(2)!) * d + int.parse(m.group(3)!);
      return Rational(m.group(1) == '-' ? -n : n, d);
    }
    return null;
  }

  /// Valor numerico del resultado: racional exacto o decimal aproximado.
  static double? numericValue(String exactLatex, String approxLatex) {
    final r = rationalFromLatex(exactLatex);
    if (r != null) return r.toDouble();
    final cleaned = approxLatex
        .replaceAll(r'\,', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  /// FACT: `360` -> `2^{3} \cdot 3^{2} \cdot 5`. `null` si no es entero > 1.
  static String? factorLatex(Rational r) {
    if (!r.isInteger || r.numerator < 2) return null;
    return Rational.factorMapToLatex(Rational.primeFactorsMap(r.numerator));
  }

  /// `° ' "`: `2.5` -> `2^{\circ} 30' 0''`.
  static String dmsLatex(double value) {
    final totalSeconds = (value.abs() * 3600).round();
    final d = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    final sign = value < 0 && totalSeconds > 0 ? '-' : '';
    return "$sign$d^{\\circ} $m' $s''";
  }

  /// Fraccion impropia `d/c` o numero mixto `a b/c`. `null` si es entero.
  static String? fractionLatex(Rational r, {required bool mixed}) {
    if (r.isInteger) return null;
    final n = r.numerator.abs();
    final d = r.denominator;
    final sign = r.numerator < 0 ? '-' : '';
    if (mixed && n > d) {
      return '$sign${n ~/ d}\\frac{${n % d}}{$d}';
    }
    return '$sign\\frac{$n}{$d}';
  }

  /// Exponente de ingenieria natural (multiplo de 3) de [value].
  static int engBaseExponent(double value) {
    if (value == 0 || value.isNaN || value.isInfinite) return 0;
    final e = (log(value.abs()) / ln10 + 1e-12).floor();
    return (e / 3).floor() * 3;
  }

  /// Notacion de ingenieria con exponente [exp] (multiplo de 3).
  static String engLatex(double value, int exp) {
    final mant = value / pow(10, exp);
    final saved = CalculatorSettings.numberFormat;
    CalculatorSettings.numberFormat = NumberFormatMode.norm;
    final text = NumberFormatter.decimal(mant, maxDecimals: 9);
    CalculatorSettings.numberFormat = saved;
    return '$text \\times 10^{$exp}';
  }

  /// `Ran#` -> decimal en [0, 1) con 3 decimales.
  static double ranHash(Random rnd) => (rnd.nextDouble() * 1000).floor() / 1000;

  /// `RanInt#(a,b)` -> entero aleatorio en [a, b] (extremos incluidos).
  static int ranInt(int a, int b, Random rnd) {
    final lo = min(a, b);
    final hi = max(a, b);
    return lo + rnd.nextInt(hi - lo + 1);
  }

  static final RegExp _ranIntRe = RegExp(r'RanInt#\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)');

  /// Sustituye `RanInt#(a,b)` y `Ran#` por valores concretos antes de evaluar.
  static String substituteRandoms(String input, Random rnd) {
    var out = input.replaceAllMapped(
      _ranIntRe,
      (m) => '(${ranInt(int.parse(m.group(1)!), int.parse(m.group(2)!), rnd)})',
    );
    out = out.replaceAllMapped(RegExp(r'Ran#'), (_) {
      return '(${ranHash(rnd).toStringAsFixed(3)})';
    });
    return out;
  }
}
