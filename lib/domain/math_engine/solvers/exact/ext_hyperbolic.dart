import 'dart:math' as math;

import '../../core/rational.dart';
import 'exact_number.dart';

/// Funciones hiperbolicas y sus inversas. No dependen de DEG/RAD: el argumento
/// es siempre un real puro. Con argumento entero se obtiene valor exacto en `e`.
class ExtHyperbolic {
  const ExtHyperbolic._();

  static const Set<String> names = {'sinh', 'cosh', 'tanh', 'asinh', 'acosh', 'atanh'};

  static const Map<String, String> _shown = {
    'sinh': r'\sinh',
    'cosh': r'\cosh',
    'tanh': r'\tanh',
    'asinh': r'\sinh^{-1}',
    'acosh': r'\cosh^{-1}',
    'atanh': r'\tanh^{-1}',
  };

  static ExNum _ePow(int k) => ExNum.fromTerms({(1, 0, k): Rational(1)});

  static ExNum eval(String name, ExNum x) {
    final v = x.approx;
    switch (name) {
      case 'asinh':
        if (x.isZero) return ExNum.integer(0);
        return _opaque(name, x, _asinh(v));
      case 'acosh':
        if (v < 1 - 1e-12) throw const ExMathError(ExMathError.acoshDomain);
        if (x.asRational == Rational(1)) return ExNum.integer(0);
        return _opaque(name, x, math.log(v + math.sqrt(math.max(0, v * v - 1))));
      case 'atanh':
        if (v.abs() >= 1 - 1e-12) throw const ExMathError(ExMathError.atanhDomain);
        if (x.isZero) return ExNum.integer(0);
        return _opaque(name, x, 0.5 * math.log((1 + v) / (1 - v)));
      default:
        return _direct(name, x);
    }
  }

  static ExNum _direct(String name, ExNum x) {
    if (x.isZero) return ExNum.integer(name == 'cosh' ? 1 : 0);
    final k = x.asInt;
    if (k != null && k.abs() <= 12 && name != 'tanh') {
      final pos = _ePow(k);
      final neg = _ePow(-k);
      final half = ExNum.rational(Rational(1, 2));
      return (name == 'sinh' ? pos - neg : pos + neg) * half;
    }
    final value = switch (name) {
      'sinh' => (math.exp(x.approx) - math.exp(-x.approx)) / 2,
      'cosh' => (math.exp(x.approx) + math.exp(-x.approx)) / 2,
      _ => _tanh(x.approx),
    };
    return _opaque(name, x, value);
  }

  static double _tanh(double v) {
    if (v > 20) return 1;
    if (v < -20) return -1;
    final a = math.exp(2 * v);
    return (a - 1) / (a + 1);
  }

  static double _asinh(double v) {
    final s = v < 0 ? -1 : 1;
    final a = v.abs();
    return s * math.log(a + math.sqrt(a * a + 1));
  }

  static ExNum _opaque(String name, ExNum x, double value) =>
      ExNum.opaque('${_shown[name]}\\left(${x.toLatex()}\\right)', value);
}
