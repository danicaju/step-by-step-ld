import 'dart:math' as math;

import 'package:flutter/painting.dart' show Offset;

import '../../domain/math_engine/calculus/limits_asymptotes_solver.dart';
import '../../domain/math_engine/functions/function_family.dart';
import 'graph_key_points.dart';
import 'graph_viewport_calculator.dart';

/// Puntos notables finitos de f: vertice / extremos, cortes con OX y OY, inicio de dominio
/// y cruce de asintotas. Son la base del encuadre inicial.
List<Offset> notablePoints(FunctionModel f, AsymptoteSet asym, {FamilyInfo? info}) {
  final pts = <Offset>[];
  bool ok(double v) => v.isFinite && v.abs() < 1e4;
  void add(double x, double? y) {
    if (y != null && ok(x) && ok(y)) pts.add(Offset(x, y));
  }

  final fam = info?.family ?? FunctionFamily.unknown;
  double co(int k) => info?.poly[k]?.toDouble() ?? 0;
  switch (fam) {
    case FunctionFamily.quadratic:
      final xv = -co(1) / (2 * co(2));
      add(xv, f.at(xv));
    case FunctionFamily.cubic:
      final a3 = 3 * co(3), b2 = 2 * co(2), c1 = co(1);
      final disc = b2 * b2 - 4 * a3 * c1;
      if (disc >= 0) {
        for (final s in const [-1, 1]) {
          final x = (-b2 + s * math.sqrt(disc)) / (2 * a3);
          add(x, f.at(x));
        }
      }
      final xi = -co(2) / (3 * co(3));
      add(xi, f.at(xi));
    case FunctionFamily.radicalEven || FunctionFamily.radicalOdd || FunctionFamily.logarithmic:
      final x0 = (fam == FunctionFamily.logarithmic ? (1 - info!.c.toDouble()) : -info!.c.toDouble()) / info.b.toDouble();
      add(x0, info.d.toDouble());
    case FunctionFamily.exponential:
      add(-info!.c.toDouble() / info.b.toDouble(), (info.a + info.d).toDouble());
    case FunctionFamily.unknown:
      pts.addAll(_localExtrema(f));
    default:
      break;
  }
  // Cortes con OX: los 4 mas cercanos al origen.
  final roots = GraphKeyPoints.roots(f, -60, 60, n: 1200).where(ok).toList()
    ..sort((a, b) => a.abs().compareTo(b.abs()));
  for (final r in roots.take(4)) {
    add(r, 0);
  }
  add(0, f.at(0));
  for (final v in asym.vertical) {
    final h = asym.horizontal.isEmpty ? 0.0 : asym.horizontal.first.n;
    add(v.x, h);
  }
  for (final h in asym.horizontal) {
    final x = asym.vertical.isEmpty ? 0.0 : asym.vertical.first.x;
    add(x, h.n);
  }
  return pts;
}

/// Extremos locales por muestreo (cambios de signo de la pendiente) en [-20, 20]; max. 4 cercanos.
List<Offset> _localExtrema(FunctionModel f) {
  final out = <Offset>[];
  const n = 800;
  double? py, pdy;
  for (var i = 0; i <= n; i++) {
    final x = -20 + 40 * i / n;
    final y = f.at(x);
    if (y != null && py != null) {
      final dy = y - py;
      if (pdy != null && pdy.sign != dy.sign && pdy != 0 && dy != 0) out.add(Offset(x - 40 / n, py));
      pdy = dy;
    } else {
      pdy = null;
    }
    py = y;
  }
  out.sort((a, b) => a.dx.abs().compareTo(b.dx.abs()));
  return out.take(4).toList();
}

/// Encuadre inicial inteligente: se centra en los puntos notables con ~30 % de margen por
/// lado y una escala casi isometrica (`aspect` = alto / ancho del lienzo), de modo que los
/// extremos lejanos de la curva no estiran el eje Y. Sin puntos utiles: `[-6, 6]`.
GraphWindow computeSmartViewport(
  FunctionModel f,
  AsymptoteSet asym, {
  FamilyInfo? info,
  bool deg = false,
  double aspect = 0.6,
}) {
  final fam = info?.family ?? FunctionFamily.unknown;
  if (fam.isTrig) return GraphViewportCalculator.trigWindow(info!, deg, tan: fam == FunctionFamily.tangent);
  final asp = aspect.isFinite && aspect > 0.15 && aspect < 3 ? aspect : 0.6;
  final pts = notablePoints(f, asym, info: info);
  final fallbackW = GraphWindow(-6, 6, -6 * asp, 6 * asp);
  if (pts.isEmpty) return fallbackW;
  var minX = pts.first.dx, maxX = minX, minY = pts.first.dy, maxY = minY;
  for (final p in pts) {
    minX = math.min(minX, p.dx);
    maxX = math.max(maxX, p.dx);
    minY = math.min(minY, p.dy);
    maxY = math.max(maxY, p.dy);
  }
  final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
  if (maxX - minX < 1e-9 && maxY - minY < 1e-9 && cx.abs() < 1e-9 && cy.abs() < 1e-9) return fallbackW;
  var xs = math.max((maxX - minX) * 1.6, 8.0);
  var ys = math.max((maxY - minY) * 1.6, xs * asp);
  if (ys > xs * asp * 2) xs = ys / (asp * 2); // evita ventanas muy altas y estrechas
  ys = math.max(ys, xs * asp);
  return GraphWindow(cx - xs / 2, cx + xs / 2, cy - ys / 2, cy + ys / 2);
}
