import 'dart:math' as math;

import 'numeric_function.dart';

/// Tipo de punto critico de una funcion continua a trozos.
enum CritKind { root, boundary, pole, touch, window }

/// Punto critico localizado numericamente.
class Crit {
  final double v;
  final CritKind kind;
  const Crit(this.v, this.kind);
}

/// Barrido numerico de `f`: ceros, fronteras del dominio, polos y ceros de multiplicidad par.
abstract final class CriticalScan {
  /// Muestras: rejilla fina en `[-50, 50]` y progresion geometrica hasta `+-1e6`; o una
  /// rejilla uniforme en `[lo, hi]` si hay ventana (funciones periodicas).
  static List<double> samples({(double, double)? window}) {
    if (window != null) {
      const n = 3000;
      return [for (var i = 0; i <= n; i++) window.$1 + (window.$2 - window.$1) * i / n];
    }
    final set = <double>{};
    for (var i = -2000; i <= 2000; i++) {
      set.add(i * 0.025);
    }
    for (var k = 0; k < 80; k++) {
      final m = 50 * math.pow(1.15, k).toDouble();
      set..add(m)..add(-m);
    }
    return set.toList()..sort();
  }

  static List<Crit> run(double? Function(double) f, {(double, double)? window}) {
    final xs = samples(window: window);
    final ys = [for (final x in xs) f(x)];
    final out = <Crit>[];
    for (var i = 0; i < xs.length; i++) {
      final fb = ys[i];
      if (fb != null && fb.abs() < 1e-12) out.add(Crit(xs[i], CritKind.root));
      if (i == 0) continue;
      final fa = ys[i - 1];
      final a = xs[i - 1], b = xs[i];
      if ((fa == null) != (fb == null)) {
        final inside = fa != null ? a : b;
        final outside = fa != null ? b : a;
        out.add(Crit(NumericRootFinder.boundary(f, inside, outside), CritKind.boundary));
        continue;
      }
      if (fa == null || fb == null) continue;
      if (fa.abs() < 1e-12 || fb.abs() < 1e-12) continue;
      if ((fa < 0) != (fb < 0)) {
        final r = NumericRootFinder.bisect(f, a, b);
        if (r == null) continue;
        final fr = f(r);
        final isPole = fr == null || fr.abs() > 0.5 * math.min(fa.abs(), fb.abs());
        out.add(Crit(r, isPole ? CritKind.pole : CritKind.root));
      } else if (i + 1 < xs.length) {
        final fc = ys[i + 1];
        if (fc != null && fc.abs() >= fb.abs() && fa.abs() > fb.abs() && (fc < 0) == (fb < 0)) {
          final m = NumericRootFinder.argMinAbs(f, a, xs[i + 1]);
          final fm = f(m);
          if (fm != null && fm.abs() < 1e-9 * (1 + fb.abs())) out.add(Crit(m, CritKind.touch));
        }
      }
    }
    if (window != null) {
      out..add(Crit(window.$1, CritKind.window))..add(Crit(window.$2, CritKind.window));
    }
    return _dedupe(out);
  }

  static int _rank(CritKind k) => switch (k) {
        CritKind.window => 5,
        CritKind.pole => 4,
        CritKind.boundary => 3,
        CritKind.root => 2,
        CritKind.touch => 1,
      };

  static List<Crit> _dedupe(List<Crit> list) {
    final items = [...list]..sort((a, b) => a.v.compareTo(b.v));
    final out = <Crit>[];
    for (final c in items) {
      if (out.isNotEmpty && (c.v - out.last.v).abs() <= 1e-7 * (1 + c.v.abs())) {
        if (_rank(c.kind) > _rank(out.last.kind)) out[out.length - 1] = Crit(out.last.v, c.kind);
        continue;
      }
      out.add(c);
    }
    return out;
  }
}
