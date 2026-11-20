import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/math_engine/geometry/geometry_triangle_solver.dart';
import '../../../domain/math_engine/geometry/triangle_exact.dart';
import '../../../domain/math_engine/geometry/triangle_summary.dart';
import '../lcd/lcd_palette.dart';
import '../m10/triangle_marks.dart';

/// Croquis del triangulo resuelto a escala real: vertices A, B, C, lados a, b, c, angulos
/// (arco o escuadra en 90°) y, debajo, clasificacion, perimetro y area.
class TriangleSketchPainter extends CustomPainter {
  final TriangleSolution solution;
  final LcdPalette palette;
  final bool night;
  final String? title;

  const TriangleSketchPainter(this.solution, {this.palette = LcdPalette.classic, this.night = false, this.title});

  /// Numero con coma decimal para texto plano del lienzo (sin el `{,}` de LaTeX).
  static String _plain(double v) => Val(v).dec(2).replaceAll('{,}', ',');

  /// Vertices A, B, C en coordenadas del plano (A en el origen, B sobre el eje x).
  static List<Offset> vertices(TriangleSolution s) {
    final b = s.sides[1], c = s.sides[2];
    final angA = s.angles[0] * math.pi / 180;
    return [Offset.zero, Offset(c, 0), Offset(b * math.cos(angA), b * math.sin(angA))];
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final summary = TriangleSummary.of(solution);
    final showCaption = size.height >= 110;
    final capH = showCaption ? 16.0 : 0.0;
    final titleH = title == null ? 0.0 : 13.0;
    final v = vertices(solution);
    final minX = v.map((p) => p.dx).reduce(math.min), maxX = v.map((p) => p.dx).reduce(math.max);
    final minY = v.map((p) => p.dy).reduce(math.min), maxY = v.map((p) => p.dy).reduce(math.max);
    const pad = 28.0;
    final padY = size.height >= 110 ? 24.0 : 10.0;
    final avW = math.max(20.0, size.width - 2 * pad), avH = math.max(20.0, size.height - 2 * padY - capH - titleH);
    final w = math.max(1e-9, maxX - minX), h = math.max(1e-9, maxY - minY);
    final scale = math.max(0.0001, math.min(avW / w, avH / h));
    final ox = (size.width - w * scale) / 2, oy = titleH + (size.height - titleH - capH - h * scale) / 2;
    // y del plano crece hacia arriba; en pantalla hacia abajo.
    final pts = [for (final p in v) Offset(ox + (p.dx - minX) * scale, oy + (maxY - p.dy) * scale)];

    final path = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFE5A93C).withValues(alpha: night ? 0.20 : 0.30));
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.formula
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );
    final cen = Offset((pts[0].dx + pts[1].dx + pts[2].dx) / 3, (pts[0].dy + pts[1].dy + pts[2].dy) / 3);
    const names = ['A', 'B', 'C'];
    final mark = Paint()
      ..color = palette.formula
      ..strokeWidth = 1.5;
    for (var i = 0; i < 3; i++) {
      final right = (solution.angles[i] - 90).abs() < 1e-6;
      TriangleMarks.angle(canvas, pts[i], pts[(i + 1) % 3], pts[(i + 2) % 3], mark, radius: 13, right: right);
      TriangleMarks.label(
        canvas,
        '${names[i]} ${_plain(solution.angles[i])}°',
        TriangleMarks.outward(pts[i], cen, 19),
        palette.formula,
        size: 10,
      );
      // Lado opuesto al vertice i: entre los otros dos vertices.
      final mid = (pts[(i + 1) % 3] + pts[(i + 2) % 3]) / 2;
      TriangleMarks.label(
        canvas,
        '${'abc'[i]} = ${_plain(solution.sides[i])}',
        TriangleMarks.outward(mid, cen, 13),
        palette.original,
        size: 10,
        weight: FontWeight.w600,
      );
    }
    if (title != null) {
      TriangleMarks.label(canvas, title!, Offset(size.width / 2, 7), palette.formula, size: 10, weight: FontWeight.w800);
    }
    if (showCaption) {
      TriangleMarks.label(canvas, summary.caption, Offset(size.width / 2, size.height - 9), palette.formula,
          size: 9.5, weight: FontWeight.w700, maxWidth: size.width - 8);
    }
  }

  @override
  bool shouldRepaint(covariant TriangleSketchPainter old) =>
      old.solution != solution || old.palette != palette || old.night != night || old.title != title;
}

/// Croquis dentro de un `ClipRRect` estricto con el fondo LCD (dos croquis si el caso es ambiguo).
class TriangleSketchView extends StatelessWidget {
  final TriangleSolution solution;
  final List<TriangleSolution> others;
  final LcdTheme theme;

  const TriangleSketchView({super.key, required this.solution, this.others = const [], this.theme = LcdTheme.classic});

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(theme);
    final all = [solution, ...others];
    return ClipRRect(
      key: const Key('triangle_sketch_clip'),
      borderRadius: BorderRadius.circular(8.5),
      child: Container(
        color: pal.background,
        child: LayoutBuilder(
          builder: (context, c) => Row(children: [
            for (var i = 0; i < all.length; i++)
              Expanded(
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: Key(i == 0 ? 'triangle_sketch_paint' : 'triangle_sketch_paint_$i'),
                    size: Size(
                      (c.maxWidth.isFinite ? c.maxWidth : 260) / all.length,
                      c.maxHeight.isFinite ? c.maxHeight : 150,
                    ),
                    painter: TriangleSketchPainter(
                      all[i],
                      palette: pal,
                      night: theme == LcdTheme.night,
                      title: all.length > 1 ? 'Solución ${i + 1}' : null,
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
