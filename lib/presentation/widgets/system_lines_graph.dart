import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../painters/graph_axis_ticks.dart';
import '../painters/graph_key_points.dart';
import '../painters/graph_label_layout.dart';
import '../painters/graph_viewport_calculator.dart';
import '../painters/graph_viewport_controller.dart';
import '../painters/system_lines_data.dart';
import '../theme/theme_controller.dart';
import 'interactive_graph_frame.dart';

/// Grafica interactiva de un sistema 2x2 (M3): las dos rectas y su punto de corte, con arrastre,
/// pellizco, rueda, doble toque y botones de zoom ([InteractiveGraphFrame]).
class SystemLinesGraph extends StatefulWidget {
  final SystemLines2x2 system;
  final GraphViewportController? controller;

  const SystemLinesGraph({super.key, required this.system, this.controller});

  @override
  State<SystemLinesGraph> createState() => _SystemLinesGraphState();
}

class _SystemLinesGraphState extends State<SystemLinesGraph> {
  late final GraphViewportController _own = GraphViewportController();

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = ThemeController.current.lcdBackground;
    return InteractiveGraphFrame(
      controller: widget.controller ?? _own,
      fitKey: widget.system,
      initialWindow: (aspect) => computeSystemViewport(widget.system, aspect: aspect),
      background: bg,
      clipKey: const Key('system_graph_clip'),
      gesturesKey: const Key('system_graph_gestures'),
      builder: (context, w, size) => CustomPaint(
        key: const Key('system_graph_paint'),
        size: size,
        painter: SystemLinesPainter(system: widget.system, window: w, background: bg),
      ),
    );
  }
}

class SystemLinesPainter extends CustomPainter {
  static const Color ink = Color(0xFF1A2530);
  static const Color line2 = Color(0xFFD97706);

  final SystemLines2x2 system;
  final GraphWindow window;
  final Color background;

  const SystemLinesPainter({required this.system, required this.window, required this.background});

  Offset _px(Size s, double x, double y) => Offset(
        (x - window.xMin) / window.width * s.width,
        s.height - (y - window.yMin) / window.height * s.height,
      );

  /// Extremos de `a x + b y = c` en la ventana ampliada (se recortan al lienzo al pintar).
  (Offset, Offset)? _ends(Size s, double a, double b, double c) {
    final w = window;
    if (b.abs() > 1e-9) {
      final x0 = w.xMin - w.width, x1 = w.xMax + w.width;
      return (_px(s, x0, (c - a * x0) / b), _px(s, x1, (c - a * x1) / b));
    }
    if (a.abs() > 1e-9) {
      final x = c / a;
      return (_px(s, x, w.yMin - w.height), _px(s, x, w.yMax + w.height));
    }
    return null;
  }

  void _pill(Canvas canvas, GraphLabelLayout layout, String text, Offset anchor, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 180);
    final box = layout.place(anchor, Size(tp.width + 6, tp.height + 3));
    final rr = RRect.fromRectAndRadius(box, const Radius.circular(3));
    canvas.drawRRect(rr, Paint()..color = background.withValues(alpha: 0.88));
    canvas.drawRRect(
        rr,
        Paint()
          ..color = ink.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);
    tp.paint(canvas, box.topLeft + const Offset(3, 1.5));
  }

  /// Un punto del tramo visible de la recta (al 75 %) para colocar su etiqueta.
  Offset _visiblePoint(Size size, Offset a, Offset b) {
    final pts = <Offset>[];
    for (var i = 0; i <= 80; i++) {
      final p = Offset.lerp(a, b, i / 80)!;
      if (p.dx >= 0 && p.dx <= size.width && p.dy >= 0 && p.dy <= size.height) pts.add(p);
    }
    if (pts.isEmpty) return Offset(size.width / 2, size.height / 2);
    return pts[math.min(pts.length - 1, (pts.length * 0.75).floor())];
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final ticks = GraphAxisTicks.paint(canvas, size, window, trig: false, degrees: false);
    final layout = GraphLabelLayout(size, occupied: ticks);
    final s = system;
    final rows = [(s.a1, s.b1, s.c1, ink, 'r1: ${s.eq1}'), (s.a2, s.b2, s.c2, line2, 'r2: ${s.eq2}')];
    final inter = s.intersection;
    if (inter != null) layout.reserve(Rect.fromCircle(center: _px(size, inter.dx, inter.dy), radius: 6));
    for (final (a, b, c, color, text) in rows) {
      final e = _ends(size, a, b, c);
      if (e == null) continue;
      canvas.drawLine(
        e.$1,
        e.$2,
        Paint()
          ..color = color
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke,
      );
      _pill(canvas, layout, text, _visiblePoint(size, e.$1, e.$2), color);
    }
    if (inter != null) {
      final c = _px(size, inter.dx, inter.dy);
      canvas.drawCircle(c, 5, Paint()..color = const Color(0xFFE5A93C));
      canvas.drawCircle(
        c,
        5,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      final label = GraphKeyPoints.coordLabel(GraphKeyPoints.formatCoord(inter.dx), GraphKeyPoints.formatCoord(inter.dy));
      _pill(canvas, layout, label, c, ink);
    } else {
      final msg = s.kind == SystemLinesKind.parallel
          ? 'Rectas paralelas: sin solucion'
          : 'Rectas coincidentes: infinitas soluciones';
      _pill(canvas, layout, msg, const Offset(8, 8), ink);
    }
  }

  @override
  bool shouldRepaint(covariant SystemLinesPainter old) =>
      old.system != system || old.window != window || old.background != background;
}
