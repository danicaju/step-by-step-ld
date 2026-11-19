import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'graph_viewport_calculator.dart';

/// Cuadricula y graduacion de los ejes del visor.
///
/// En trigonometria el eje OX se gradua con multiplos de pi/2 (`-π`, `-π/2`, `π/2`, `π`,
/// `2π`) o de 90 grados; en el resto, con marcas "bonitas" (1, 2, 5 x 10^n).
class GraphAxisTicks {
  const GraphAxisTicks._();

  static const Color ink = Color(0xFF1A2530);
  static const Color gridColor = Color(0xFF9DB0A3);

  static double niceStep(double span) {
    final raw = span / 8;
    final p = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final f = raw / p;
    return (f < 1.5 ? 1 : (f < 3.5 ? 2 : (f < 7.5 ? 5 : 10))) * p;
  }

  static String _fmt(double v) =>
      (v - v.roundToDouble()).abs() < 1e-9 ? v.round().toString() : v.toStringAsFixed(1).replaceAll('.', ',');

  /// Pinta la rejilla y devuelve los rectangulos ocupados por los numeros de los ejes.
  static List<Rect> paint(Canvas canvas, Size size, GraphWindow w,
      {required bool trig, required bool degrees}) {
    final used = <Rect>[];
    Offset px(double x, double y) =>
        Offset((x - w.xMin) / w.width * size.width, size.height - (y - w.yMin) / w.height * size.height);
    final grid = Paint()
      ..color = gridColor.withValues(alpha: 0.45)
      ..strokeWidth = 0.6;
    final axis = Paint()
      ..color = ink
      ..strokeWidth = 1.3;
    final xTicks = trig ? GraphViewportCalculator.angleTicks(w, degrees) : null;
    final sx = niceStep(w.width), sy = niceStep(w.height);
    final xs = xTicks ?? [for (var x = (w.xMin / sx).ceil() * sx; x <= w.xMax; x += sx) (x, _fmt(x))];
    final labelY = (w.yMin < 0 && w.yMax > 0) ? 0.0 : w.yMin;
    for (final (x, text) in xs) {
      canvas.drawLine(px(x, w.yMin), px(x, w.yMax), x.abs() < 1e-9 ? axis : grid);
      if (x.abs() > 1e-9) used.add(_text(canvas, size, text, px(x, labelY) + const Offset(-6, 2)));
    }
    for (var y = (w.yMin / sy).ceil() * sy; y <= w.yMax; y += sy) {
      canvas.drawLine(px(w.xMin, y), px(w.xMax, y), y.abs() < 1e-9 ? axis : grid);
      if (y.abs() > 1e-9) used.add(_text(canvas, size, _fmt(y), px((w.xMin < 0 && w.xMax > 0) ? 0 : w.xMin, y) + const Offset(2, -11)));
    }
    return used;
  }

  static Rect _text(Canvas canvas, Size size, String text, Offset at) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Color(0xFF3F4F48), fontSize: 8.5, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 60);
    final x = at.dx.clamp(1.0, math.max(1.0, size.width - tp.width - 1)).toDouble();
    final y = at.dy.clamp(1.0, math.max(1.0, size.height - tp.height - 1)).toDouble();
    tp.paint(canvas, Offset(x, y));
    return Rect.fromLTWH(x, y, tp.width, tp.height);
  }
}
