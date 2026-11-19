import 'dart:math' as math;

import '../../domain/math_engine/calculus/limits_asymptotes_solver.dart';
import '../../domain/math_engine/functions/angle_format.dart';
import '../../domain/math_engine/functions/function_family.dart';
import 'graph_smart_viewport.dart';

/// Ventana matematica visible del visor.
class GraphWindow {
  final double xMin, xMax, yMin, yMax;
  const GraphWindow(this.xMin, this.xMax, this.yMin, this.yMax);

  double get width => xMax - xMin;
  double get height => yMax - yMin;

  /// Misma ventana desplazada [fx] anchos en x y [fy] altos en y (D-Pad).
  GraphWindow panned(double fx, double fy) =>
      GraphWindow(xMin + fx * width, xMax + fx * width, yMin + fy * height, yMax + fy * height);

  @override
  bool operator ==(Object other) =>
      other is GraphWindow && other.xMin == xMin && other.xMax == xMax && other.yMin == yMin && other.yMax == yMax;

  @override
  int get hashCode => Object.hash(xMin, xMax, yMin, yMax);
}

/// Auto-encuadre inteligente por familia de funcion.
class GraphViewportCalculator {
  const GraphViewportCalculator._();

  /// Ventana para [f] segun su [info] (familia y coeficientes).
  static GraphWindow window(FunctionModel f, AsymptoteSet asym,
      {FamilyInfo? info, bool deg = false, double aspect = 0.6}) {
    final fam = info?.family ?? FunctionFamily.unknown;
    if (fam == FunctionFamily.constant) {
      final k = f.at(0) ?? 0;
      return GraphWindow(-6, 6, k - 4, k + 4);
    }
    return computeSmartViewport(f, asym, info: info, deg: deg, aspect: aspect);
  }

  /// Ventana generica: x en [-halfX, halfX]; y por percentiles de los valores finitos.
  static GraphWindow generic(FunctionModel f, AsymptoteSet a, {double halfX = 10}) {
    if (a.vertical.length == 1 && a.horizontal.length == 1 && a.oblique.isEmpty) {
      return _hyperbola(f, a.vertical.first.x, a.horizontal.first.n);
    }
    return _fit(f, -halfX, halfX, extra: a);
  }

  /// Ventana con x fija y y por percentiles (incluye siempre las asintotas horizontales).
  static GraphWindow _fit(FunctionModel f, double x0, double x1, {AsymptoteSet? extra, List<double> mustY = const []}) {
    final ys = <double>[];
    for (var i = 0; i <= 400; i++) {
      final y = f.at(x0 + (x1 - x0) * i / 400);
      if (y != null) ys.add(y);
    }
    for (final h in extra?.horizontal ?? const <Asymptote>[]) {
      ys.add(h.n);
    }
    ys.addAll(mustY);
    if (ys.isEmpty) return GraphWindow(x0, x1, -5, 5);
    ys.sort();
    var lo = ys[(ys.length * 0.04).floor()];
    var hi = ys[math.min(ys.length - 1, (ys.length * 0.96).ceil())];
    for (final m in mustY) {
      lo = math.min(lo, m);
      hi = math.max(hi, m);
    }
    if (hi - lo < 4) {
      final mid = (hi + lo) / 2;
      lo = mid - 2;
      hi = mid + 2;
    }
    final pad = (hi - lo) * 0.15;
    return GraphWindow(x0, x1, lo - pad, hi + pad);
  }

  /// Cortes con OX numericos (cambios de signo) en [-60, 60].
  static List<double> _zeros(FunctionModel f) {
    final out = <double>[];
    double? px, py;
    for (var i = 0; i <= 1200; i++) {
      final x = -60 + 120 * i / 1200;
      final y = f.at(x);
      if (y != null && py != null && px != null && py != 0 && py.sign != y.sign) {
        var lo = px, hi = x, flo = py;
        for (var k = 0; k < 40; k++) {
          final mid = (lo + hi) / 2;
          final fm = f.at(mid);
          if (fm == null) break;
          if (fm.sign == flo.sign) {
            lo = mid;
            flo = fm;
          } else {
            hi = mid;
          }
        }
        final r = (lo + hi) / 2;
        final fr = f.at(r);
        if (fr != null && fr.abs() < 1e-6) out.add(r);
      }
      px = x;
      py = y;
    }
    return out.where((z) => z.abs() <= 60).take(6).toList();
  }

  /// Hiperbola: ventana centrada en (AV, AH) que deja ver ambos cortes con los ejes.
  static GraphWindow _hyperbola(FunctionModel f, double cx, double cy) {
    var hx = math.max(5.0, cx.abs() + 2);
    for (final r in _zeros(f)) {
      hx = math.max(hx, (r - cx).abs() * 1.3 + 1);
    }
    var hy = math.max(3.0, cy.abs() * 1.2 + 1);
    final y0 = f.at(0);
    if (y0 != null) hy = math.max(hy, (y0 - cy).abs() * 1.3 + 1);
    return GraphWindow(cx - hx, cx + hx, cy - hy, cy + hy);
  }

  /// Trigonometricas: al menos [-2pi, 2pi] (o [-360, 360] en DEG) y dos periodos.
  static GraphWindow trigWindow(FamilyInfo i, bool deg, {required bool tan}) {
    final turn = AngleFormat.turn(deg);
    final period = (tan ? turn / 2 : turn) / i.b.toDouble().abs();
    final half = math.max(turn, period);
    final a = i.a.abs().toDouble(), d = i.d.toDouble();
    final yh = tan ? math.max(4.0, 3 * a) : a * 1.3 + 0.2;
    return GraphWindow(-half, half, d - yh, d + yh);
  }

  /// Marcas del eje OX: multiplos de pi/2 (o 90 grados) en trigonometria, `null` si no aplica.
  static List<(double, String)>? angleTicks(GraphWindow w, bool deg) {
    final q = AngleFormat.turn(deg) / 4;
    final n = (w.width / q).ceil();
    if (n > 40) return null;
    return [
      for (var k = (w.xMin / q).ceil(); k * q <= w.xMax + 1e-9; k++) (k * q, AngleFormat.plain(k * q, deg)),
    ];
  }
}
