import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../domain/math_engine/models/inequality_models.dart';
import '../../domain/math_engine/solvers/inequalities/sutherland_hodgman_2d.dart';
import '../painters/graph_axis_ticks.dart';
import '../painters/graph_label_layout.dart';
import '../painters/graph_viewport_calculator.dart';
import '../painters/graph_viewport_controller.dart';
import '../painters/region_viewport.dart';
import '../theme/theme_controller.dart';
import '../utils/latex_plain_text.dart';
import 'interactive_graph_frame.dart';

/// Region factible 2D interactiva: arrastre, pellizco, rueda, doble toque y botones de zoom
/// ([InteractiveGraphFrame]); encuadre inicial inteligente ([computeRegionViewport]).
class FeasibleRegionCanvas extends StatefulWidget {
  final FeasibleRegion2DVisualData visualData;
  final bool isOledDark;
  final double height;
  final GraphViewportController? controller;

  const FeasibleRegionCanvas({
    super.key,
    required this.visualData,
    this.isOledDark = false,
    this.height = 220,
    this.controller,
  });

  @override
  State<FeasibleRegionCanvas> createState() => _FeasibleRegionCanvasState();
}

class _FeasibleRegionCanvasState extends State<FeasibleRegionCanvas> {
  late final GraphViewportController _own = GraphViewportController();

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isOledDark;
    final bg = dark ? const Color(0xFF111615) : ThemeController.current.lcdBackground;
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: dark ? const Color(0xFF263238) : const Color(0xFF4F6B5C).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: InteractiveGraphFrame(
        controller: widget.controller ?? _own,
        fitKey: widget.visualData,
        initialWindow: (aspect) => computeRegionViewport(widget.visualData, aspect: aspect),
        background: bg,
        clipKey: const Key('region_clip'),
        gesturesKey: const Key('region_gestures'),
        borderRadius: 7,
        builder: (context, w, size) => CustomPaint(
          key: const Key('region_paint'),
          size: size,
          painter: _FeasibleRegionPainter(data: widget.visualData, isOledDark: dark, window: w, background: bg),
        ),
      ),
    );
  }
}

class _FeasibleRegionPainter extends CustomPainter {
  final FeasibleRegion2DVisualData data;
  final bool isOledDark;
  final GraphWindow window;
  final Color background;

  _FeasibleRegionPainter({
    required this.data,
    required this.isOledDark,
    required this.window,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Ventana visible (controlada por el marco interactivo)
    final double minX = window.xMin, maxX = window.xMax, minY = window.yMin, maxY = window.yMax;
    final double spanX = maxX - minX;
    final double spanY = maxY - minY;

    double toScreenX(double x) => ((x - minX) / spanX) * size.width;
    double toScreenY(double y) =>
        size.height - ((y - minY) / spanY) * size.height;

    final gridColor = isOledDark
        ? const Color(0xFF1E2A26)
        : const Color(0xFFC8D6CD).withValues(alpha: 0.7);
    final axisColor =
        isOledDark ? const Color(0xFF9DB0A4) : const Color(0xFF2F3E38);
    final labelColor =
        isOledDark ? const Color(0xFFDDE6DF) : const Color(0xFF1A2530);

    // 2. Rejilla con pasos limpios (1, 2, 5 x 10^k) y numeros de ejes
    final tickRects = GraphAxisTicks.paint(canvas, size, window,
        trig: false, degrees: false, ink: axisColor, grid: isOledDark ? gridColor : const Color(0xFF9DB0A3));
    final layout = GraphLabelLayout(size, occupied: tickRects);

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
    final box = [
      Point2D(minX, minY),
      Point2D(maxX, minY),
      Point2D(maxX, maxY),
      Point2D(minX, maxY),
    ];
    final polygon = SutherlandHodgman2D.clipPolygonWithInequalities(
      box,
      data.inequalities,
    );
    final area = SutherlandHodgman2D.computePolygonArea(polygon);

    if (polygon.length >= 3 && area > 1e-4 && !data.isEmpty) {
      final polyPath = Path();
      polyPath.moveTo(toScreenX(polygon[0].x), toScreenY(polygon[0].y));
      for (int i = 1; i < polygon.length; i++) {
        polyPath.lineTo(toScreenX(polygon[i].x), toScreenY(polygon[i].y));
      }
      polyPath.close();

      // Relleno semitransparente de la región factible (oliva con alfa)
      final fillPaint = Paint()
        ..color = const Color(0x66708A78)
        ..style = PaintingStyle.fill;
      canvas.drawPath(polyPath, fillPaint);

      // Perímetro morado (#E5A93C): SÓLO sobre rectas frontera reales, NUNCA sobre bordes de pantalla
      final borderPaint = Paint()
        ..color = const Color(0xFFE5A93C)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < polygon.length; i++) {
        final pA = polygon[i];
        final pB = polygon[(i + 1) % polygon.length];
        final mx = (pA.x + pB.x) / 2.0;
        final my = (pA.y + pB.y) / 2.0;

        LinearInequality2D? matchedIneq;
        for (final ineq in data.inequalities) {
          final dist = (ineq.normA * mx + ineq.normB * my - ineq.normC).abs();
          if (dist < 1e-4) {
            matchedIneq = ineq;
            break;
          }
        }

        if (matchedIneq != null) {
          final off1 = Offset(toScreenX(pA.x), toScreenY(pA.y));
          final off2 = Offset(toScreenX(pB.x), toScreenY(pB.y));
          if (matchedIneq.isBoundarySolid) {
            canvas.drawLine(off1, off2, borderPaint);
          } else {
            _drawDashedLine(canvas, off1, off2, borderPaint);
          }
        }
      }

      // Etiqueta de Región Solución
      _drawText(
        canvas,
        data.isBounded ? 'REGIÓN SOLUCIÓN (Sf)' : 'REGIÓN NO ACOTADA (Sf)',
        const Offset(10, 8),
        TextStyle(
          color: const Color(0xFFE5A93C),
          fontSize: 10.0,
          fontWeight: FontWeight.w900,
          backgroundColor: isOledDark ? Colors.black87 : Colors.white70,
        ),
      );
    } else {
      // Incompatible / Conjunto solución vacío
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

    // 5. Dibujar cada recta frontera de borde a borde del plano
    final lineColors = [
      const Color(0xFF1A2530), // Texto Casio
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

        // Rotular la recta r1, r2... (sin colisionar con ejes, numeros ni otras etiquetas)
        final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        _pillLabel(canvas, layout, 'r${idx + 1}', mid, TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold));
      }
    }

    // 6. Marcar vértices de corte reales con círculos ● (cerrado) u ○ (abierto)
    for (final v in data.vertices) {
      layout.reserve(Rect.fromCircle(center: Offset(toScreenX(v.x), toScreenY(v.y)), radius: 6));
    }
    for (int i = 0; i < data.vertices.length; i++) {
      final v = data.vertices[i];
      final sx = toScreenX(v.x);
      final sy = toScreenY(v.y);
      final name = v.label ?? 'V${i + 1}';

      if (v.isOpen) {
        // Vértice abierto ○
        final openBg = Paint()
          ..color = isOledDark ? const Color(0xFF111615) : Colors.white
          ..style = PaintingStyle.fill;
        final openBorder = Paint()
          ..color = const Color(0xFFE5A93C)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset(sx, sy), 5.5, openBg);
        canvas.drawCircle(Offset(sx, sy), 5.5, openBorder);
      } else {
        // Vértice cerrado ●
        final solidDot = Paint()
          ..color = const Color(0xFFE5A93C)
          ..style = PaintingStyle.fill;
        final solidBorder = Paint()
          ..color = Colors.white
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset(sx, sy), 5.5, solidDot);
        canvas.drawCircle(Offset(sx, sy), 5.5, solidBorder);
      }

      _pillLabel(canvas, layout, '$name${LatexPlainText.toPlain(v.toLatex())}', Offset(sx, sy),
          TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.bold));
    }
  }

  /// Etiqueta con pastilla del color de la LCD (alpha .88) colocada por [GraphLabelLayout].
  void _pillLabel(Canvas canvas, GraphLabelLayout layout, String text, Offset anchor, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)
      ..layout(maxWidth: 160);
    final box = layout.place(anchor, Size(tp.width + 6, tp.height + 3));
    final rr = RRect.fromRectAndRadius(box, const Radius.circular(3));
    canvas.drawRRect(rr, Paint()..color = background.withValues(alpha: 0.88));
    canvas.drawRRect(
        rr,
        Paint()
          ..color = const Color(0xFF1A2530).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);
    tp.paint(canvas, box.topLeft + const Offset(3, 1.5));
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
    return oldDelegate.data != data ||
        oldDelegate.isOledDark != isOledDark ||
        oldDelegate.window != window ||
        oldDelegate.background != background;
  }
}
