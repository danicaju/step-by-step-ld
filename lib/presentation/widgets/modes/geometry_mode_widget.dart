import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/math_engine/geometry/geometry_triangle_solver.dart';

/// Croquis del triangulo resuelto: vertices A, B, C, lados a, b, c y angulos.
class TriangleSketchPainter extends CustomPainter {
  static const Color ink = Color(0xFF1A2530);
  static const Color fill = Color(0xFFE5A93C); // SHIFT

  final TriangleSolution solution;
  const TriangleSketchPainter(this.solution);

  /// Vertices A, B, C en coordenadas del plano (A en el origen, B sobre el eje x).
  static List<Offset> vertices(TriangleSolution s) {
    final b = s.sides[1], c = s.sides[2];
    final angA = s.angles[0] * math.pi / 180;
    return [Offset.zero, Offset(c, 0), Offset(b * math.cos(angA), b * math.sin(angA))];
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final v = vertices(solution);
    final minX = v.map((p) => p.dx).reduce(math.min), maxX = v.map((p) => p.dx).reduce(math.max);
    final minY = v.map((p) => p.dy).reduce(math.min), maxY = v.map((p) => p.dy).reduce(math.max);
    const pad = 26.0;
    final w = math.max(1e-9, maxX - minX), h = math.max(1e-9, maxY - minY);
    final k = math.min((size.width - 2 * pad) / w, (size.height - 2 * pad) / h);
    final ox = (size.width - w * k) / 2, oy = (size.height - h * k) / 2;
    // y del plano crece hacia arriba; en pantalla hacia abajo.
    final pts = [for (final p in v) Offset(ox + (p.dx - minX) * k, size.height - oy - (p.dy - minY) * k)];

    final path = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..close();
    canvas.drawPath(path, Paint()..color = fill.withValues(alpha: 0.28));
    canvas.drawPath(
      path,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );
    final cen = Offset((pts[0].dx + pts[1].dx + pts[2].dx) / 3, (pts[0].dy + pts[1].dy + pts[2].dy) / 3);
    const names = ['A', 'B', 'C'];
    for (var i = 0; i < 3; i++) {
      final out = (pts[i] - cen) / math.max(1.0, (pts[i] - cen).distance);
      _text(canvas, '${names[i]} ${solution.angles[i].toStringAsFixed(1)}°', pts[i] + out * 16, bold: true);
      // Lado opuesto al vertice i: entre los otros dos vertices.
      final p1 = pts[(i + 1) % 3], p2 = pts[(i + 2) % 3];
      final mid = (p1 + p2) / 2;
      final away = (mid - cen) / math.max(1.0, (mid - cen).distance);
      _text(canvas, '${'abc'[i]}=${solution.sides[i].toStringAsFixed(2)}', mid + away * 12);
    }
  }

  void _text(Canvas canvas, String text, Offset center, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: ink, fontSize: 10, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant TriangleSketchPainter old) => old.solution != solution;
}

/// Croquis dentro de un `ClipRRect` estricto con el fondo LCD.
class TriangleSketchView extends StatelessWidget {
  final TriangleSolution solution;
  const TriangleSketchView({super.key, required this.solution});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: const Key('triangle_sketch_clip'),
      borderRadius: BorderRadius.circular(8.5),
      child: Container(
        color: const Color(0xFFC8D6CD),
        child: LayoutBuilder(
          builder: (context, c) => RepaintBoundary(child: CustomPaint(
            key: const Key('triangle_sketch_paint'),
            size: Size(c.maxWidth.isFinite ? c.maxWidth : 260, c.maxHeight.isFinite ? c.maxHeight : 150),
            painter: TriangleSketchPainter(solution),
          )),
        ),
      ),
    );
  }
}
