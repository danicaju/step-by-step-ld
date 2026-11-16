import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../domain/math_engine/models/inequality_models.dart';

/// Widget interactivo para renderizar la región factible 2D en el plano cartesiano
/// con recorte de polígono exacto (Algoritmo de Sutherland-Hodgman).
class FeasibleRegionCanvas extends StatelessWidget {
  final FeasibleRegion2DVisualData visualData;
  final bool isOledDark;
  final double height;

  const FeasibleRegionCanvas({
    super.key,
    required this.visualData,
    this.isOledDark = false,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isOledDark ? const Color(0xFF111615) : const Color(0xFFDDE6DF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOledDark
              ? const Color(0xFF263238)
              : const Color(0xFF0F766E).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: CustomPaint(
            painter: _FeasibleRegionPainter(
              data: visualData,
              isOledDark: isOledDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeasibleRegionPainter extends CustomPainter {
  final FeasibleRegion2DVisualData data;
  final bool isOledDark;

  _FeasibleRegionPainter({
    required this.data,
    required this.isOledDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Determinar los límites visuales del plano cartesiano [minX, maxX] x [minY, maxY]
    double minX = -2.0;
    double maxX = 8.0;
    double minY = -2.0;
    double maxY = 8.0;

    if (data.vertices.isNotEmpty) {
      final xs = data.vertices.map((v) => v.x).toList();
      final ys = data.vertices.map((v) => v.y).toList();
      final pMinX = xs.reduce(math.min);
      final pMaxX = xs.reduce(math.max);
      final pMinY = ys.reduce(math.min);
      final pMaxY = ys.reduce(math.max);

      minX = math.min(-1.5, (pMinX - 2.0).floorToDouble());
      maxX = math.max(5.0, (pMaxX + 2.5).ceilToDouble());
      minY = math.min(-1.5, (pMinY - 2.0).floorToDouble());
      maxY = math.max(5.0, (pMaxY + 2.5).ceilToDouble());
    } else if (data.inequalities.isNotEmpty) {
      // Buscar cortes con ejes para dimensionar la vista
      final intercepts = <double>[];
      for (final ineq in data.inequalities) {
        if (ineq.a.abs() > 1e-6) intercepts.add(ineq.c / ineq.a);
        if (ineq.b.abs() > 1e-6) intercepts.add(ineq.c / ineq.b);
      }
      if (intercepts.isNotEmpty) {
        final iMin = intercepts.reduce(math.min);
        final iMax = intercepts.reduce(math.max);
        minX = math.min(-2.0, (iMin - 2.0).floorToDouble());
        maxX = math.max(6.0, (iMax + 2.0).ceilToDouble());
        minY = minX;
        maxY = maxX;
      }
    }

    final double spanX = maxX - minX;
    final double spanY = maxY - minY;

    double toScreenX(double x) => ((x - minX) / spanX) * size.width;
    double toScreenY(double y) =>
        size.height - ((y - minY) / spanY) * size.height;

    final gridColor = isOledDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFCBD5E1).withValues(alpha: 0.7);
    final axisColor =
        isOledDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);
    final labelColor =
        isOledDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);

    // 2. Rejilla cartesiana
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8;

    final int stepX = (spanX / 10).clamp(1.0, 10.0).round();
    final int stepY = (spanY / 10).clamp(1.0, 10.0).round();

    for (int x = minX.toInt(); x <= maxX.toInt(); x += stepX) {
      final sx = toScreenX(x.toDouble());
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), gridPaint);
    }
    for (int y = minY.toInt(); y <= maxY.toInt(); y += stepY) {
      final sy = toScreenY(y.toDouble());
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), gridPaint);
    }

    // 3. Ejes principales X e Y
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.8;

    final originX = toScreenX(0);
    final originY = toScreenY(0);

    // Eje X
    if (originY >= 0 && originY <= size.height) {
      canvas.drawLine(
          Offset(0, originY), Offset(size.width, originY), axisPaint);
      _drawText(
        canvas,
        'X',
        Offset(size.width - 12, originY - 14),
        TextStyle(
            color: axisColor, fontSize: 10, fontWeight: FontWeight.bold),
      );
    }
    // Eje Y
    if (originX >= 0 && originX <= size.width) {
      canvas.drawLine(
          Offset(originX, 0), Offset(originX, size.height), axisPaint);
      _drawText(
        canvas,
        'Y',
        Offset(originX + 4, 2),
        TextStyle(
            color: axisColor, fontSize: 10, fontWeight: FontWeight.bold),
      );
    }

    // 4. Algoritmo de Sutherland-Hodgman para calcular la Región Factible exacta
    final polygon = _computeFeasiblePolygonSutherlandHodgman(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      inequalities: data.inequalities,
    );

    final area = _computePolygonArea(polygon);

    if (polygon.length >= 3 && area > 1e-4) {
      final polyPath = Path();
      polyPath.moveTo(toScreenX(polygon[0].x), toScreenY(polygon[0].y));
      for (int i = 1; i < polygon.length; i++) {
        polyPath.lineTo(toScreenX(polygon[i].x), toScreenY(polygon[i].y));
      }
      polyPath.close();

      // Paso B: Relleno de la región factible con azul acero semitransparente (0x885B84B1)
      final fillPaint = Paint()
        ..color = const Color(0x885B84B1)
        ..style = PaintingStyle.fill;
      canvas.drawPath(polyPath, fillPaint);

      // Paso C: Perímetro del polígono solución con línea gruesa morada/magenta (#9C4196, strokeWidth: 4.0)
      final borderPaint = Paint()
        ..color = const Color(0xFF9C4196)
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(polyPath, borderPaint);

      // Etiqueta destacada de Región Solución (Sf)
      _drawText(
        canvas,
        'REGIÓN SOLUCIÓN (Sf)',
        const Offset(10, 8),
        TextStyle(
          color: const Color(0xFF9C4196),
          fontSize: 10.0,
          fontWeight: FontWeight.w900,
          backgroundColor: isOledDark ? Colors.black87 : Colors.white70,
        ),
      );
    } else {
      // Incompatible / Conjunto solución vacío en el área
      _drawText(
        canvas,
        'Sin región común (S = ∅)',
        Offset(size.width / 2 - 75, size.height / 2 - 10),
        TextStyle(
          color: const Color(0xFFDC2626),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          backgroundColor: isOledDark ? Colors.black87 : Colors.white,
        ),
      );
    }

    // 5. Paso A: Dibujar cada recta frontera de borde a borde del plano
    // Recta 1: #2563EB (azul), Recta 2: #16A34A (verde), Recta 3: #DC2626 (rojo), Recta 4: #D97706 (naranja)
    final lineColors = [
      const Color(0xFF2563EB), // Azul
      const Color(0xFF16A34A), // Verde
      const Color(0xFFDC2626), // Rojo
      const Color(0xFFD97706), // Naranja
    ];

    for (int idx = 0; idx < data.inequalities.length; idx++) {
      final ineq = data.inequalities[idx];
      final color = lineColors[idx % lineColors.length];
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final pts =
          _findLineScreenPoints(ineq, minX - 2, maxX + 2, minY - 2, maxY + 2);
      if (pts != null) {
        final p1 = Offset(toScreenX(pts.$1.x), toScreenY(pts.$1.y));
        final p2 = Offset(toScreenX(pts.$2.x), toScreenY(pts.$2.y));

        if (ineq.isBoundarySolid) {
          canvas.drawLine(p1, p2, linePaint);
        } else {
          _drawDashedLine(canvas, p1, p2, linePaint);
        }

        // Rotular la recta
        final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        _drawText(
          canvas,
          'r${idx + 1}',
          Offset(mid.dx.clamp(12.0, size.width - 24.0),
              mid.dy.clamp(12.0, size.height - 18.0)),
          TextStyle(
            color: color,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            backgroundColor: isOledDark ? Colors.black54 : Colors.white70,
          ),
        );
      }
    }

    // 6. Marcar vértices de intersección válidos con puntos y coordenadas (x, y)
    final vertexDotPaint = Paint()
      ..color = const Color(0xFF9C4196)
      ..style = PaintingStyle.fill;
    final vertexBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final names = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    for (int i = 0; i < data.vertices.length; i++) {
      final v = data.vertices[i];
      final sx = toScreenX(v.x);
      final sy = toScreenY(v.y);
      final name = i < names.length ? names[i] : 'V${i + 1}';

      canvas.drawCircle(Offset(sx, sy), 5.5, vertexDotPaint);
      canvas.drawCircle(Offset(sx, sy), 5.5, vertexBorderPaint);

      _drawText(
        canvas,
        '$name${v.toLatex()}',
        Offset(sx + 7, sy - 14),
        TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: isOledDark ? Colors.black87 : Colors.white70,
        ),
      );
    }
  }

  /// Recorta el rectángulo visible usando el algoritmo de Sutherland-Hodgman
  /// para cada semiplano generado por una inecuación lineal del sistema.
  static List<Point2D> _computeFeasiblePolygonSutherlandHodgman({
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
    required List<LinearInequality2D> inequalities,
  }) {
    List<Point2D> polygon = [
      Point2D(minX, minY),
      Point2D(maxX, minY),
      Point2D(maxX, maxY),
      Point2D(minX, maxY),
    ];

    for (final ineq in inequalities) {
      if (polygon.isEmpty) break;
      polygon = _clipPolygonWithHalfPlane(polygon, ineq);
    }

    return polygon;
  }

  static List<Point2D> _clipPolygonWithHalfPlane(
    List<Point2D> poly,
    LinearInequality2D ineq,
  ) {
    final output = <Point2D>[];
    if (poly.isEmpty) return output;

    for (int i = 0; i < poly.length; i++) {
      final current = poly[i];
      final next = poly[(i + 1) % poly.length];
      final currentInside = ineq.evaluatesTrue(current.x, current.y);
      final nextInside = ineq.evaluatesTrue(next.x, next.y);

      if (currentInside && nextInside) {
        output.add(next);
      } else if (currentInside && !nextInside) {
        final intersection = _intersectSegmentWithLine(current, next, ineq);
        if (intersection != null) output.add(intersection);
      } else if (!currentInside && nextInside) {
        final intersection = _intersectSegmentWithLine(current, next, ineq);
        if (intersection != null) output.add(intersection);
        output.add(next);
      }
    }

    return output;
  }

  static Point2D? _intersectSegmentWithLine(
    Point2D p1,
    Point2D p2,
    LinearInequality2D ineq,
  ) {
    // Distancia dirigida respecto a ax + by - c = 0
    final d1 = ineq.a * p1.x + ineq.b * p1.y - ineq.c;
    final d2 = ineq.a * p2.x + ineq.b * p2.y - ineq.c;

    final denom = d1 - d2;
    if (denom.abs() < 1e-12) return null;

    final t = (d1 / denom).clamp(0.0, 1.0);
    final ix = p1.x + t * (p2.x - p1.x);
    final iy = p1.y + t * (p2.y - p1.y);
    return Point2D(ix, iy);
  }

  static double _computePolygonArea(List<Point2D> p) {
    if (p.length < 3) return 0.0;
    double area = 0.0;
    for (int i = 0; i < p.length; i++) {
      final j = (i + 1) % p.length;
      area += p[i].x * p[j].y - p[j].x * p[i].y;
    }
    return (area / 2.0).abs();
  }

  (Point2D, Point2D)? _findLineScreenPoints(
    LinearInequality2D ineq,
    double minX,
    double maxX,
    double minY,
    double maxY,
  ) {
    final a = ineq.a;
    final b = ineq.b;
    final c = ineq.c;

    final hits = <Point2D>[];

    // Intersección con x = minX y x = maxX
    if (b.abs() > 1e-9) {
      final y1 = (c - a * minX) / b;
      if (y1 >= minY - 1e-4 && y1 <= maxY + 1e-4) {
        hits.add(Point2D(minX, y1));
      }
      final y2 = (c - a * maxX) / b;
      if (y2 >= minY - 1e-4 && y2 <= maxY + 1e-4) {
        hits.add(Point2D(maxX, y2));
      }
    }
    // Intersección con y = minY y y = maxY
    if (a.abs() > 1e-9) {
      final x1 = (c - b * minY) / a;
      if (x1 >= minX - 1e-4 && x1 <= maxX + 1e-4) {
        hits.add(Point2D(x1, minY));
      }
      final x2 = (c - b * maxY) / a;
      if (x2 >= minX - 1e-4 && x2 <= maxX + 1e-4) {
        hits.add(Point2D(x2, maxY));
      }
    }

    // Deduplicar puntos muy cercanos
    final uniqueHits = <Point2D>[];
    for (final h in hits) {
      final exists = uniqueHits.any(
        (u) => (u.x - h.x).abs() < 1e-4 && (u.y - h.y).abs() < 1e-4,
      );
      if (!exists) uniqueHits.add(h);
    }

    if (uniqueHits.length < 2) return null;
    return (uniqueHits[0], uniqueHits[1]);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist <= 0) return;

    final ux = dx / dist;
    final uy = dy / dist;

    double traveled = 0;
    while (traveled < dist) {
      final next = math.min(traveled + dashWidth, dist);
      canvas.drawLine(
        Offset(p1.dx + ux * traveled, p1.dy + uy * traveled),
        Offset(p1.dx + ux * next, p1.dy + uy * next),
        paint,
      );
      traveled += dashWidth + dashSpace;
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _FeasibleRegionPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.isOledDark != isOledDark;
  }
}
