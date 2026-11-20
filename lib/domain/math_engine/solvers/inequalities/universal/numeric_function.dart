import 'dart:math' as math;

import '../../exact/ext_expr.dart';
import '../../trig_and_angles_solver.dart' show AngleUnit;

/// Evaluador numerico (double) rapido del AST extendido en `x`. Devuelve `null` fuera del
/// dominio real (raiz par de negativo, logaritmo de no positivo, division por 0, etc.).
abstract final class NumFn {
  static double? eval(XNode n, double x) => evalEnv(n, {'X': x});

  /// Igual que [eval] con varias variables (`X`, `Y`, `Z`, `W`) en [env]. [unit] es la unidad
  /// angular de sin/cos/tan y de sus inversas (radianes por defecto).
  static double? evalEnv(XNode n, Map<String, double> env, {AngleUnit unit = AngleUnit.rad}) {
    final v = _ev(n, env, unit);
    // Un desbordamiento (2^2000) es +-infinito y sigue "definido"; solo NaN queda fuera del dominio.
    return (v == null || v.isNaN) ? null : v;
  }

  static double? _ev(XNode n, Map<String, double> env, AngleUnit unit) {
    switch (n) {
      case XNum(:final value):
        return value.toDouble();
      case XConst(:final kind):
        return kind == 'pi' ? math.pi : math.e;
      case XVar(:final name):
        return env[name];
      case XNeg(:final a):
        final v = evalEnv(a, env, unit: unit);
        return v == null ? null : -v;
      case XBin(:final l, :final op, :final r):
        final a = evalEnv(l, env, unit: unit), b = evalEnv(r, env, unit: unit);
        if (a == null || b == null) return null;
        return switch (op) {
          '+' => a + b,
          '-' => a - b,
          '*' => a * b,
          _ => b == 0 ? null : a / b,
        };
      case XPow(:final base, :final exp):
        final b = evalEnv(base, env, unit: unit), e = evalEnv(exp, env, unit: unit);
        if (b == null || e == null) return null;
        return _pow(b, e, exp);
      case XRoot(:final index, :final rad):
        final r = evalEnv(rad, env, unit: unit);
        final idx = index == null ? 2.0 : evalEnv(index, env, unit: unit);
        if (r == null || idx == null || idx < 1 || idx != idx.roundToDouble()) return null;
        final k = idx.round();
        if (k.isEven) return r < 0 ? null : math.pow(r, 1 / k).toDouble();
        return r < 0 ? -math.pow(-r, 1 / k).toDouble() : math.pow(r, 1 / k).toDouble();
      case XAbs(:final a):
        final v = evalEnv(a, env, unit: unit);
        return v?.abs();
      case XFn(:final name, :final arg, :final base):
        return _fn(name, evalEnv(arg, env, unit: unit), base == null ? null : evalEnv(base, env, unit: unit), base != null, unit);
      default:
        return null;
    }
  }

  static double? _pow(double b, double e, XNode expNode) {
    if (b == 0) return e > 0 ? 0 : null;
    if (b > 0) return math.pow(b, e).toDouble();
    if (e == e.roundToDouble()) return math.pow(b, e).toDouble();
    // Exponente racional p/q con q impar: raiz real de un negativo.
    if (expNode is XNum && expNode.value.denominator.isOdd) {
      final r = math.pow(-b, e).toDouble();
      return expNode.value.numerator.isOdd ? -r : r;
    }
    return null;
  }

  static double _toRad(double a, AngleUnit u) => switch (u) {
        AngleUnit.deg => a * math.pi / 180,
        AngleUnit.grad => a * math.pi / 200,
        _ => a,
      };

  static double _fromRad(double a, AngleUnit u) => switch (u) {
        AngleUnit.deg => a * 180 / math.pi,
        AngleUnit.grad => a * 200 / math.pi,
        _ => a,
      };

  static double? _fn(String name, double? a, double? base, bool hasBase, AngleUnit unit) {
    if (a == null) return null;
    switch (name) {
      case 'ln':
        return a > 0 ? math.log(a) : null;
      case 'log':
        if (a <= 0) return null;
        if (!hasBase) return math.log(a) / math.ln10;
        if (base == null || base <= 0 || base == 1) return null;
        return math.log(a) / math.log(base);
      case 'sin':
        return math.sin(_toRad(a, unit));
      case 'cos':
        return math.cos(_toRad(a, unit));
      case 'tan':
        final r = _toRad(a, unit);
        return math.cos(r).abs() < 1e-12 ? null : math.tan(r);
      case 'asin':
        return a.abs() <= 1 ? _fromRad(math.asin(a), unit) : null;
      case 'acos':
        return a.abs() <= 1 ? _fromRad(math.acos(a), unit) : null;
      case 'atan':
        return _fromRad(math.atan(a), unit);
    }
    return null;
  }

  /// `true` si el arbol contiene la variable `x`.
  static bool hasX(XNode n) => switch (n) {
        XVar(:final name) => name == 'X',
        XNum() || XConst() => false,
        XNeg(:final a) || XAbs(:final a) || XFact(:final a) => hasX(a),
        XBin(:final l, :final r) => hasX(l) || hasX(r),
        XPow(:final base, :final exp) => hasX(base) || hasX(exp),
        XRoot(:final index, :final rad) => hasX(rad) || (index != null && hasX(index)),
        XFn(:final arg, :final base) => hasX(arg) || (base != null && hasX(base)),
        XComb(n: final cn, r: final cr) => hasX(cn) || hasX(cr),
      };

  /// `true` si el arbol contiene alguna funcion trigonometrica.
  static bool hasTrig(XNode n) => switch (n) {
        XFn(:final name, :final arg) =>
          const {'sin', 'cos', 'tan', 'asin', 'acos', 'atan'}.contains(name) || hasTrig(arg),
        XNeg(:final a) || XAbs(:final a) || XFact(:final a) => hasTrig(a),
        XBin(:final l, :final r) => hasTrig(l) || hasTrig(r),
        XPow(:final base, :final exp) => hasTrig(base) || hasTrig(exp),
        XRoot(:final rad) => hasTrig(rad),
        _ => false,
      };
}

/// Biseccion publica reutilizable para localizar ceros y fronteras del dominio.
abstract final class NumericRootFinder {
  /// Cero de [f] en `[a, b]` si f(a) y f(b) tienen signos opuestos; `null` si no.
  static double? bisect(double? Function(double) f, double a, double b, {int iterations = 100}) {
    var fa = f(a);
    final fb = f(b);
    if (fa == null || fb == null || fa == 0 || fb == 0 || (fa < 0) == (fb < 0)) return null;
    var lo = a, hi = b;
    for (var i = 0; i < iterations; i++) {
      final mid = (lo + hi) / 2;
      final fm = f(mid);
      if (fm == null) return mid;
      if (fm == 0) return mid;
      if ((fm < 0) == (fa! < 0)) {
        lo = mid;
        fa = fm;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  /// Frontera entre un punto donde f esta definida ([inside]) y otro donde no ([outside]).
  static double boundary(double? Function(double) f, double inside, double outside, {int iterations = 100}) {
    var inn = inside, out = outside;
    for (var i = 0; i < iterations; i++) {
      final mid = (inn + out) / 2;
      if (f(mid) != null) {
        inn = mid;
      } else {
        out = mid;
      }
    }
    return inn;
  }

  /// Minimo de |f| en `[a, b]` por busqueda ternaria (para ceros de multiplicidad par).
  static double argMinAbs(double? Function(double) f, double a, double b, {int iterations = 80}) {
    var lo = a, hi = b;
    double g(double x) => f(x)?.abs() ?? double.infinity;
    for (var i = 0; i < iterations; i++) {
      final m1 = lo + (hi - lo) / 3, m2 = hi - (hi - lo) / 3;
      if (g(m1) < g(m2)) {
        hi = m2;
      } else {
        lo = m1;
      }
    }
    return (lo + hi) / 2;
  }
}
