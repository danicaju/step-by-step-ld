import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Marcas compartidas por los dibujos de triangulos: arco de angulo, escuadra y rotulos.
abstract final class TriangleMarks {
  /// Arco interior en el vertice [p] entre las direcciones a [q] y a [r]; escuadra si [right].
  static void angle(Canvas canvas, Offset p, Offset q, Offset r, Paint paint, {double radius = 15, bool right = false}) {
    final d1 = q - p, d2 = r - p;
    if (d1.distance < 1 || d2.distance < 1) return;
    final u1 = d1 / d1.distance, u2 = d2 / d2.distance;
    if (right) {
      final s = radius * 0.8;
      final path = Path()
        ..moveTo(p.dx + u1.dx * s, p.dy + u1.dy * s)
        ..lineTo(p.dx + (u1.dx + u2.dx) * s, p.dy + (u1.dy + u2.dy) * s)
        ..lineTo(p.dx + u2.dx * s, p.dy + u2.dy * s);
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
      return;
    }
    final a1 = math.atan2(d1.dy, d1.dx), a2 = math.atan2(d2.dy, d2.dx);
    var delta = a2 - a1;
    while (delta > math.pi) {
      delta -= 2 * math.pi;
    }
    while (delta <= -math.pi) {
      delta += 2 * math.pi;
    }
    canvas.drawArc(Rect.fromCircle(center: p, radius: radius), a1, delta, false, paint..style = PaintingStyle.stroke);
  }

  /// Punto desplazado [dist] px desde [p] alejandose del baricentro [c].
  static Offset outward(Offset p, Offset c, double dist) {
    final d = p - c;
    return p + (d.distance < 1 ? Offset.zero : d / d.distance * dist);
  }

  static void label(Canvas canvas, String text, Offset center, Color color,
      {double size = 11, FontWeight weight = FontWeight.w700, double? maxWidth}) {
    var tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    if (maxWidth != null && tp.width > maxWidth) {
      tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size * maxWidth / tp.width, fontWeight: weight)),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }
}
