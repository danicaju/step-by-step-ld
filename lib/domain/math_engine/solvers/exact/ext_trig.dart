import 'dart:math' as math;

import '../../core/rational.dart';
import '../trig_and_angles_solver.dart';
import 'exact_number.dart';

/// Trigonometria exacta en angulos notables (DEG / RAD / GRA) y su inversa.
class ExtTrig {
  const ExtTrig._();

  static ExNum _t(int r, int num, int den) =>
      ExNum.fromTerms({(r, 0, 0): Rational(num, den)});

  static final Map<int, ExNum> _sin = {
    0: _t(1, 0, 1),
    30: _t(1, 1, 2),
    45: _t(2, 1, 2),
    60: _t(3, 1, 2),
    90: _t(1, 1, 1),
  };
  static final Map<int, ExNum> _cos = {
    0: _t(1, 1, 1),
    30: _t(3, 1, 2),
    45: _t(2, 1, 2),
    60: _t(1, 1, 2),
    90: _t(1, 0, 1),
  };

  static Rational? _toDegrees(ExNum a, AngleUnit unit) {
    if (!a.isExact) return null;
    if (a.isZero) return Rational(0);
    switch (unit) {
      case AngleUnit.deg:
        return a.asRational;
      case AngleUnit.grad:
        final r = a.asRational;
        return r == null ? null : r * Rational(9, 10);
      case AngleUnit.rad:
        if (a.terms.length == 1 && a.terms.containsKey((1, 1, 0))) {
          return a.terms[(1, 1, 0)]! * Rational(180);
        }
        return null;
    }
  }

  static double _toRadians(double v, AngleUnit unit) => switch (unit) {
        AngleUnit.deg => v * math.pi / 180,
        AngleUnit.rad => v,
        AngleUnit.grad => v * math.pi / 200,
      };

  static double _fromDegrees(double deg, AngleUnit unit) => switch (unit) {
        AngleUnit.deg => deg,
        AngleUnit.rad => deg * math.pi / 180,
        AngleUnit.grad => deg * 10 / 9,
      };

  static ExNum _degToUnit(int deg, AngleUnit unit) => switch (unit) {
        AngleUnit.deg => ExNum.integer(deg),
        AngleUnit.rad => ExNum.fromTerms({(1, 1, 0): Rational(deg, 180)}),
        AngleUnit.grad => ExNum.rational(Rational(deg * 10, 9)),
      };

  static ExNum direct(String name, ExNum arg, AngleUnit unit) {
    final deg = _toDegrees(arg, unit);
    if (deg != null && deg.isInteger) {
      final d = ((deg.numerator % 360) + 360) % 360;
      final (ref, sinSign, cosSign) = d <= 90
          ? (d, 1, 1)
          : d <= 180
              ? (180 - d, 1, -1)
              : d <= 270
                  ? (d - 180, -1, -1)
                  : (360 - d, -1, 1);
      if (_sin.containsKey(ref)) {
        final s = sinSign == 1 ? _sin[ref]! : -_sin[ref]!;
        final c = cosSign == 1 ? _cos[ref]! : -_cos[ref]!;
        switch (name) {
          case 'sin':
            return s;
          case 'cos':
            return c;
          default:
            if (c.isZero) throw const ExMathError();
            return s / c;
        }
      }
    }
    final rad = _toRadians(arg.approx, unit);
    final v = switch (name) {
      'sin' => math.sin(rad),
      'cos' => math.cos(rad),
      _ => math.tan(rad),
    };
    if (name == 'tan' && math.cos(rad).abs() < 1e-12) {
      throw const ExMathError();
    }
    final argLatex =
        unit == AngleUnit.deg ? '${arg.toLatex()}^\\circ' : arg.toLatex();
    return ExNum.opaque('\\$name\\left($argLatex\\right)', v);
  }

  static bool _close(double a, double b) => (a - b).abs() < 1e-12;

  static ExNum inverse(String name, ExNum x, AngleUnit unit) {
    final v = x.approx;
    if (name != 'atan' && v.abs() > 1 + 1e-12) throw const ExMathError();
    if (x.isExact && x.isAlgebraic) {
      final a = v.abs();
      int? ref;
      if (name == 'atan') {
        const tan = {0: 0.0, 30: 0.5773502691896257, 45: 1.0, 60: 1.7320508075688772};
        for (final e in tan.entries) {
          if (_close(e.value, a)) ref = e.key;
        }
        if (ref != null) return _degToUnit(v < 0 ? -ref : ref, unit);
      } else {
        final table = name == 'asin' ? _sin : _cos;
        for (final e in table.entries) {
          if (_close(e.value.approx, a)) ref = e.key;
        }
        if (ref != null) {
          final deg = name == 'asin'
              ? (v < 0 ? -ref : ref)
              : (v < 0 ? 180 - ref : ref);
          return _degToUnit(deg, unit);
        }
      }
    }
    final deg = switch (name) {
      'asin' => math.asin(v) * 180 / math.pi,
      'acos' => math.acos(v) * 180 / math.pi,
      _ => math.atan(v) * 180 / math.pi,
    };
    const shown = {'asin': 'arcsin', 'acos': 'arccos', 'atan': 'arctan'};
    return ExNum.opaque(
      '\\${shown[name]}\\left(${x.toLatex()}\\right)',
      _fromDegrees(deg, unit),
    );
  }
}
