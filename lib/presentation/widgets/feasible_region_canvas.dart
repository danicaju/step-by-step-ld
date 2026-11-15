import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../domain/math_engine/models/inequality_models.dart';

/// Widget interactivo para renderizar la región factible 2D en el plano cartesiano.
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
          color: isOledDark ? const Color(0xFF263238) : const Color(0xFF0F766E).withValues(alpha: 0.3),
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

    // Calcular límites de la vista [minX, maxX] x [minY, maxY]
    double minX = -1.0;
    double maxX = 6.0;
    double minY = -1.0;
    double maxY = 6.0;

    if (data.vertices.isNotEmpty) {
      final xs = data.vertices.map((v) => v.x).toList();
      final ys = data.vertices.map((v) => v.y).toList();
      final pMinX = xs.reduce(math.min);
      final pMaxX = xs.reduce(math.max);
      final pMinY = ys.reduce(math.min);
      final pMaxY = ys.reduce(math.max);

      minX = math.min(-1.0, (pMinX - 1.5).floorToDouble());
      maxX = math.max(4.0, (pMaxX + 2.0).ceilToDouble());
      minY = math.min(-1.0, (pMinY - 1.5).floorToDouble());
      maxY = math.max(4.0, (pMaxY + 2.0).ceilToDouble());
    }

    final double spanX = maxX - minX;
    final double spanY = maxY - minY;

    double toScreenX(double x) => ((x - minX) / spanX) * size.width;
    double toScreenY(double y) => size.height - ((y - minY) / spanY) * size.height;

    final gridColor = isOledDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1).withValues(alpha: 0.7);
    final axisColor = isOledDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);
    final labelColor = isOledDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);

    // 1. Rejilla cartesiana
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8;

    for (int x = minX.toInt(); x <= maxX.toInt(); x++) {
      final sx = toScreenX(x.toDouble());
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), gridPaint);
    }
    for (int y = minY.toInt(); y <= maxY.toInt(); y++) {
      final sy = toScreenY(y.toDouble());
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), gridPaint);
    }

    // 2. Ejes principales X e Y
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.8;

    final originX = toScreenX(0);
    final originY = toScreenY(0);

    // Eje X
    if (originY >= 0 && originY <= size.height) {
      canvas.drawLine(Offset(0, originY), Offset(size.width, originY), axisPaint);
      _drawText(canvas, 'X', Offset(size.width - 12, originY - 14), TextStyle(color: axisColor, fontSize: 10, fontWeight: FontWeight.bold));
    }
    // Eje Y
    if (originX >= 0 && originX <= size.width) {
      canvas.drawLine(Offset(originX, 0), Offset(originX, size.height), axisPaint);
      _drawText(canvas, 'Y', Offset(originX + 4, 2), TextStyle(color: axisColor, fontSize: 10, fontWeight: FontWeight.bold));
    }

    // 3. Sombrear región factible (polígono de vértices) o mensaje de conjunto vacío
    if (!data.isEmpty && data.vertices.length >= 3) {
      final polyPath = Path();
      final first = data.vertices.first;
      polyPath.moveTo(toScreenX(first.x), toScreenY(first.y));
      for (int i = 1; i < data.vertices.length; i++) {
        final pt = data.vertices[i];
        polyPath.lineTo(toScreenX(pt.x), toScreenY(pt.y));
      }
      polyPath.close();

      final regionFill = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawPath(polyPath, regionFill);

      // Rayado diagonal sobre la región factible
      canvas.save();
      canvas.clipPath(polyPath);
      final hatchPaint = Paint()
        ..color = const Color(0xFF059669).withValues(alpha: 0.45)
        ..strokeWidth = 1.2;
      for (double x = -size.height; x < size.width + size.height; x += 10.0) {
        canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), hatchPaint);
      }
      canvas.restore();

      // Etiqueta distintiva de Región Solución (Sf)
      _drawText(
        canvas,
        'REGIÓN SOLUCIÓN (Sf)',
        const Offset(10, 8),
        TextStyle(
          color: const Color(0xFF059669),
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          backgroundColor: (isOledDark ? Colors.black87 : Colors.white70),
        ),
      );
    } else if (data.isEmpty) {
      // Incompatible / Conjunto solución vacío
      _drawText(
        canvas,
        'Sin región común (S = ∅)',
        Offset(size.width / 2 - 75, size.height / 2 - 10),
        TextStyle(
          color: const Color(0xFFDC2626),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          backgroundColor: (isOledDark ? Colors.black87 : Colors.white),
        ),
      );
    }

    // 4. Dibujar rectas frontera (continuas o discontinuas)
    final lineColors = [
      const Color(0xFF2563EB), // Azul
      const Color(0xFFD97706), // Ámbar
      const Color(0xFF7C3AED), // Púrpura
      const Color(0xFFDC2626), // Rojo
    ];

    for (int idx = 0; idx < data.inequalities.length; idx++) {
      final ineq = data.inequalities[idx];
      final color = lineColors[idx % lineColors.length];
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      // Hallar 2 puntos alejados para trazar la recta a través de la pantalla
      final pts = _findLineScreenPoints(ineq, minX - 2, maxX + 2, minY - 2, maxY + 2);
      if (pts != null) {
        final p1 = Offset(toScreenX(pts.$1.x), toScreenY(pts.$1.y));
        final p2 = Offset(toScreenX(pts.$2.x), toScreenY(pts.$2.y));

        if (ineq.isBoundarySolid) {
          // Línea continua
          canvas.drawLine(p1, p2, linePaint);
        } else {
          // Línea discontinua
          _drawDashedLine(canvas, p1, p2, linePaint);
        }
      }
    }

    // 5. Dibujar vértices destacados con puntos y nombres
    final vertexDotPaint = Paint()
      ..color = isOledDark ? const Color(0xFF38BDF8) : const Color(0xFF0F766E)
      ..style = PaintingStyle.fill;
    final vertexBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final names = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    for (int i = 0; i < data.vertices.length; i++) {
      final v = data.vertices[i];
      final sx = toScreenX(v.x);
      final sy = toScreenY(v.y);
      final name = i < names.length ? names[i] : 'V${i + 1}';

      canvas.drawCircle(Offset(sx, sy), 5.0, vertexDotPaint);
      canvas.drawCircle(Offset(sx, sy), 5.0, vertexBorderPaint);

      _drawText(
        canvas,
        '$name${v.toLatex()}',
        Offset(sx + 6, sy - 14),
        TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: (isOledDark ? Colors.black54 : Colors.white70),
        ),
      );
    }
  }

  (Point2D, Point2D)? _findLineScreenPoints(
    LinearInequality2D ineq,
    double minX,
    double maxX,
    double minY,
    double maxY,
  ) {
    // ax + by = c
    final a = ineq.a;
    final b = ineq.b;
    final c = ineq.c;

    final hits = <Point2D>[];

    // Intersección con x = minX y x = maxX
    if (b.abs() > 1e-9) {
      final y1 = (c - a * minX) / b;
      hits.add(Point2D(minX, y1));
      final y2 = (c - a * maxX) / b;
      hits.add(Point2D(maxX, y2));
    }
    // Intersección con y = minY y y = maxY
    if (a.abs() > 1e-9) {
      final x1 = (c - b * minY) / a;
      hits.add(Point2D(x1, minY));
      final x2 = (c - b * maxY) / a;
      hits.add(Point2D(x2, maxY));
    }

    if (hits.length < 2) return null;
    return (hits[0], hits[1]);
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
