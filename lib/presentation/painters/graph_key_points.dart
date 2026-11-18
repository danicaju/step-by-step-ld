import 'dart:math' as math;

import '../../domain/math_engine/calculus/function_numeric.dart';
import '../../domain/math_engine/functions/angle_format.dart';
import '../../domain/math_engine/functions/function_family.dart';
import 'graph_viewport_calculator.dart';

/// Punto destacado del visor (corte, vertice, extremo, punto clave).
class KeyPoint {
  final double x, y;
  final String label;

  /// `false` = solo el punto, sin rotulo (evita amontonar etiquetas en trigonometria).
  final bool labeled;
  const KeyPoint(this.x, this.y, this.label, {this.labeled = true});
}

/// Calcula los puntos que el visor marca y rotula para cada familia.
class GraphKeyPoints {
  const GraphKeyPoints._();

  /// Ceros de f (cambios de signo refinados por biseccion) en `[a, b]`.
  static List<double> roots(FunctionModel f, double a, double b, {int n = 800}) {
    final out = <double>[];
    double? px, py;
    for (var i = 0; i <= n; i++) {
      final x = a + (b - a) * i / n;
      final y = f.at(x);
      if (y != null && py != null && px != null && py.sign != y.sign && py != 0) {
        var lo = px, hi = x, flo = py;
        for (var k = 0; k < 50; k++) {
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
      } else if (y != null && y == 0) {
        out.add(x);
      }
      px = x;
      py = y;
    }
    return out;
  }

  static String _num(double v) =>
      (v - v.roundToDouble()).abs() < 1e-9 ? v.round().toString() : v.toStringAsFixed(2).replaceAll('.', ',');

  /// Puntos a marcar dentro de [w].
  static List<KeyPoint> of(FunctionModel f, GraphWindow w, {FamilyInfo? info, bool deg = false}) {
    final trig = info?.family.isTrig ?? false;
    final period = trig ? AngleFormat.turn(deg) / info!.b.toDouble().abs() : 0.0;
    String fx(double x) => trig ? AngleFormat.plain(x, deg) : _num(x);
    final pts = <KeyPoint>[];
    void add(double x, double y) {
      if (x < w.xMin || x > w.xMax || y < w.yMin || y > w.yMax) return;
      if (pts.any((p) => (p.x - x).abs() < w.width * 0.01 && (p.y - y).abs() < w.height * 0.01)) return;
      pts.add(KeyPoint(x, y, '(${fx(x)}, ${_num(y)})', labeled: !trig || (x > -1e-9 && x <= period + 1e-9)));
    }

    if (info != null) _special(f, info, deg, add);
    for (final r in roots(f, w.xMin, w.xMax)) {
      add(r, 0);
    }
    final y0 = f.at(0);
    if (y0 != null) add(0, y0);
    return pts;
  }

  static void _special(FunctionModel f, FamilyInfo i, bool deg, void Function(double, double) add) {
    double co(int k) => i.poly[k]?.toDouble() ?? 0;
    final b = i.b.toDouble(), c = i.c.toDouble();
    switch (i.family) {
      case FunctionFamily.quadratic:
        final xv = -co(1) / (2 * co(2));
        add(xv, f.at(xv) ?? 0);
      case FunctionFamily.cubic:
        final a3 = 3 * co(3), b2 = 2 * co(2), c1 = co(1);
        final disc = b2 * b2 - 4 * a3 * c1;
        if (disc >= 0) {
          for (final s in const [-1, 1]) {
            final x = (-b2 + s * math.sqrt(disc)) / (2 * a3);
            add(x, f.at(x) ?? 0);
          }
        }
        final xi = -co(2) / (3 * co(3));
        add(xi, f.at(xi) ?? 0);
      case FunctionFamily.radicalEven || FunctionFamily.radicalOdd || FunctionFamily.logarithmic:
        final x0 = i.family == FunctionFamily.logarithmic ? (1 - c) / b : -c / b;
        add(x0, i.d.toDouble());
      case FunctionFamily.exponential:
        add(-c / b, (i.a + i.d).toDouble());
      case FunctionFamily.sine || FunctionFamily.cosine:
        final half = AngleFormat.turn(deg) / 2;
        final sin = i.family == FunctionFamily.sine;
        final step = sin ? half : half;
        final off = sin ? half / 2 : 0.0;
        for (var m = -8; m <= 8; m++) {
          final x = (off + m * step - c) / b;
          add(x, f.at(x) ?? 0);
        }
      default:
        break;
    }
  }
}
